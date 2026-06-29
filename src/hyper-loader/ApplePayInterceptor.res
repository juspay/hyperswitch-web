open Utils
open Identity

// Stores a callback that posts a message dict to the payment iframe.
// Set by Elements.res when it handles the TrustPay delayed-session message, so the
// interceptor can send "applePayConfirmRequest" back to the correct iframe during
// onvalidatemerchant.
//
// WHY a callback instead of the DOM source window:
//   The `source` field of a message event is a cross-origin WindowProxy.
//   Wrapping it in `Some(...)` compiles to `Caml_option.some(x)` which reads
//   `x.BS_PRIVATE_NESTED_SOME_NONE` — any property access on a cross-origin
//   WindowProxy throws a SecurityError in browsers.  Storing a pre-bound closure
//   that uses `mountedIframeRef->Window.iframePostMessage(...)` is the safe alternative.
let postToIframeRef: ref<option<Dict.t<JSON.t> => unit>> = ref(None)
let activeLoggerRef: ref<option<HyperLoggerTypes.loggerMake>> = ref(None)

let setPostToIframe = (fn: Dict.t<JSON.t> => unit, ~logger: HyperLoggerTypes.loggerMake) => {
  postToIframeRef := Some(fn)
  activeLoggerRef := Some(logger)
}

// Clears the stored iframe-post callback.
// MUST be called from Elements.res in all three branches (.then / .catch / catch)
// after finishApplePaymentV2 completes.  Without this, isInterceptModeActive()
// permanently returns true after the first TrustPay session, causing every
// subsequent Braintree Apple Pay session on the same page to be incorrectly
// intercepted, have the confirm request time out (8 s), and abort.
let clearPostToIframe = () => {
  postToIframeRef := None
  activeLoggerRef := None
}

let logTrustPayFetchEvent = event => {
  switch activeLoggerRef.contents {
  | Some(logger) =>
    let dict = event->getDictFromJson
    let eventStatus = dict->getString("status", "")
    let uri = dict->getString("url", "")
    let statusCode = dict->getInt("statusCode", 0)
    let latency = dict->getFloat("latency", 0.0)
    let message = dict->getString("message", "")
    let data = message === "" ? JSON.Encode.null : message->JSON.Encode.string
    let logSlowResponse = () => {
      if latency > LoggerUtils.apiSlowResponseThresholdMs {
        LogAPIResponse.logApiResponse(
          ~logger,
          ~uri,
          ~eventName=Some(APPLE_PAY_FLOW),
          ~status=Slow,
          ~statusCode,
          ~latency,
        )
      }
    }

    switch eventStatus {
    | "request" =>
      LogAPIResponse.logApiResponse(
        ~logger,
        ~uri,
        ~eventName=Some(APPLE_PAY_FLOW),
        ~status=Request,
      )
    | "success" =>
      LogAPIResponse.logApiResponse(
        ~logger,
        ~uri,
        ~eventName=Some(APPLE_PAY_FLOW),
        ~status=Success,
        ~statusCode,
        ~latency,
      )
      logSlowResponse()
    | "error" =>
      LogAPIResponse.logApiResponse(
        ~logger,
        ~uri,
        ~eventName=Some(APPLE_PAY_FLOW),
        ~status=Error,
        ~statusCode,
        ~latency,
      )
      logSlowResponse()
    | "exception" =>
      LogAPIResponse.logApiResponse(
        ~logger,
        ~uri,
        ~eventName=Some(APPLE_PAY_FLOW),
        ~status=Exception,
        ~data,
        ~latency,
      )
      logSlowResponse()
    | _ => ()
    }
  | None => ()
  }
}

let logTrustPayProxyError = message => {
  switch activeLoggerRef.contents {
  | Some(logger) =>
    logger.setLogError(
      ~value=`Apple Pay TrustPay interceptor failed: ${message}`,
      ~eventName=APPLE_PAY_FLOW,
      ~logType=ERROR,
      ~logCategory=API,
      ~paymentMethod="APPLE_PAY",
    )
  | None => ()
  }
}

// Guards against two concurrent waitForConfirmResponse() invocations.
// Fires if the user double-clicks the Apple Pay button before the first session
// settles.  Without this, two window "message" listeners and two 8-second timers
// would accumulate; both would resolve/reject on the same iframe reply, causing
// the second proxy session to run enableFetchInterception and originalHandler
// on a session that was already handled (or aborted) by the first.
let waitingForConfirmRef: ref<bool> = ref(false)

// Sends "applePayConfirmRequest" to the stored iframe and returns a Promise that
// resolves with the secrets JSON once the iframe replies with "applePayConfirmSecrets".
//
// Fixes applied here:
//   H-5 — times out after 8 seconds and cleans up the listener
//
// NOTE: postToIframeRef is intentionally NOT cleared inside cleanup().
//   In the timeout / reject path, cleanup() runs first, then the proxy calls
//   onInterceptFailure() → sendShowApplePayButtonToIframe().  If postToIframeRef
//   were cleared in cleanup(), the reset message could not be delivered (H-6).
//   sendShowApplePayButtonToIframe() clears it afterwards.  clearPostToIframe()
//   in Elements.res is a safe no-op double-clear on normal completion.
// Implementation injected by AppleHacks.js
let waitForConfirmResponse = (): promise<JSON.t> => {
  open Promise
  make((resolve, reject) => {
    if waitingForConfirmRef.contents {
      reject(
        Exn.anyToExnInternal(
          "[ApplePayInterceptor] Already waiting for applePayConfirmSecrets — ignoring concurrent call",
        ),
      )
    } else {
      waitingForConfirmRef := true

      let handlerRef: ref<option<Types.event => unit>> = ref(None)
      let timerIdRef = ref(None)

      let cleanup = () => {
        waitingForConfirmRef := false
        switch handlerRef.contents {
        | Some(h) => Window.removeEventListener("message", h)
        | None => ()
        }
        switch timerIdRef.contents {
        | Some(id) => clearTimeout(id)
        | None => ()
        }
      }

      let handler = (ev: Types.event) => {
        let dict = ev.data->anyTypeToJson->getDictFromJson
        switch dict->Dict.get("applePayConfirmSecrets") {
        | Some(secrets) =>
          cleanup()
          if secrets == JSON.Encode.null {
            reject(Exn.anyToExnInternal("[ApplePayInterceptor] Confirm call returned null secrets"))
          } else {
            resolve(secrets)
          }
        | None => ()
        }
      }
      handlerRef := Some(handler)
      Window.addEventListener("message", handler)

      let timerId = setTimeout(() => {
        cleanup()
        reject(
          Exn.anyToExnInternal(
            "[ApplePayInterceptor] Timed out (8 s) waiting for applePayConfirmSecrets",
          ),
        )
      }, 8000)
      timerIdRef := Some(timerId)

      switch postToIframeRef.contents {
      | Some(postFn) => postFn([("applePayConfirmRequest", true->JSON.Encode.bool)]->Dict.fromArray)
      | None =>
        cleanup()
        reject(
          Exn.anyToExnInternal(
            "[ApplePayInterceptor] No iframe post function stored — cannot request confirm",
          ),
        )
      }
    }
  })
}

// Temporarily patches window.fetch to replace TrustPay's "Secret" field in BOTH
// FormData POSTs TrustPay makes during the Apple Pay flow:
//   1. onvalidatemerchant  → FormData { Secret, ValidationUrl, InitiativeContext }
//   2. onpaymentauthorized → FormData { Secret, ApplePaymentToken }
// In each, it strips any existing "Secret" / "Secret.*" entries and appends a
// single "Secret" field set to newSecret.payment (TrustPay does not accept the
// dot-notation Secret.display / Secret.payment form here, and reuses its original
// placeholder secret on payment submit unless we swap it too).
// Self-destructs after the payment-submit swap (the last request).
// Implementation injected by AppleHacks.js
let enableFetchInterception: (JSON.t, JSON.t => unit) => unit = %raw(`
function enableFetchInterception(newSecret, logFetchEvent) {
  var origFetch = window.fetch;
  var validateMerchantPatched = false;
  var submitPaymentPatched = false;

  function urlToString(url) {
    try {
      if (typeof url === "string") return url;
      if (url && typeof url.url === "string") return url.url;
      return String(url);
    } catch (_e) {
      return "";
    }
  }

  function emitLog(payload) {
    try {
      if (typeof logFetchEvent === "function") {
        logFetchEvent(payload);
      }
    } catch (_e) {}
  }

  function fetchWithApiLogging(ctx, url, patchedOptions) {
    var requestStartedAt = Date.now();
    emitLog({ status: "request", url: urlToString(url) });
    return origFetch.call(ctx, url, patchedOptions).then(
      function(response) {
        var latency = Date.now() - requestStartedAt;
        var statusCode = response && typeof response.status === "number" ? response.status : 0;
        emitLog({
          status: response && response.ok ? "success" : "error",
          url: urlToString(url),
          statusCode: statusCode,
          latency: latency
        });
        return response;
      },
      function(err) {
        var latency = Date.now() - requestStartedAt;
        emitLog({
          status: "exception",
          url: urlToString(url),
          latency: latency,
          message: err && err.message ? err.message : String(err)
        });
        throw err;
      }
    );
  }

  function rebuildBodyWithSecret(body) {
    var newBody = new FormData();
    for (var _i = 0, _entries = body.entries(); ; ) {
      var _ref = _entries.next();
      if (_ref.done) break;
      var entry = _ref.value;
      if (entry[0] !== "Secret" && !entry[0].startsWith("Secret.")) {
        newBody.append(entry[0], entry[1]);
      }
    }
    // TrustPay expects a single "Secret" field whose value is the payment token
    // (NOT separate Secret.display / Secret.payment fields).
    if (typeof newSecret === "object" && newSecret !== null) {
      newBody.append("Secret", newSecret.payment);
    } else {
      newBody.append("Secret", String(newSecret));
    }
    return newBody;
  }

  window.fetch = function(url, options) {
    if (
      newSecret &&
      options &&
      options.method === "POST" &&
      options.body instanceof FormData
    ) {
      var keys = Array.from(options.body.keys());
      var hasSecretKey = keys.some(function(k) {
        return k === "Secret" || k.startsWith("Secret.");
      });

      if (hasSecretKey) {
        // 1) Merchant-validation request (Secret + ValidationUrl)
        if (!validateMerchantPatched && keys.includes("ValidationUrl")) {
          validateMerchantPatched = true;
          var newValidationBody = rebuildBodyWithSecret(options.body);
          return fetchWithApiLogging(this, url, Object.assign({}, options, { body: newValidationBody }));
        }

        // 2) Payment-submit request (Secret + ApplePaymentToken)
        if (!submitPaymentPatched && keys.includes("ApplePaymentToken")) {
          submitPaymentPatched = true;
          window.fetch = origFetch; // self-destruct after the final swap
          var newSubmitBody = rebuildBodyWithSecret(options.body);
          return fetchWithApiLogging(this, url, Object.assign({}, options, { body: newSubmitBody }));
        }
      }
    }
    return origFetch.apply(this, arguments);
  };
}
`)

// The raw function receives the ReScript-compiled callbacks plus two guards:
//   isInterceptModeActive — returns true only when postToIframeRef is set
//                           (i.e., a TrustPay session is in progress).
//                           Used to pass through non-TrustPay sessions (e.g. Braintree)
//                           without intercepting (B-1 fix).
//   onInterceptFailure    — called when the intercept fails so the iframe can
//                           reset its button/loader (H-6 fix).
// Implementation injected by AppleHacks.js
let initApplePaySessionProxy: (
  unit => promise<JSON.t>,
  (JSON.t, JSON.t => unit) => unit,
  unit => bool,
  unit => unit,
) => unit = %raw(`
function initApplePaySessionProxy(waitForConfirmResponse, enableFetchInterception, isInterceptModeActive, onInterceptFailure) {
  if (typeof window === "undefined" || !window.ApplePaySession) {
    console.warn("[ApplePayInterceptor] ApplePaySession not available, skipping proxy.");
    return;
  }
  if (window.__applePayProxyInstalled) {
    return;
  }

  var OrigSession = window.ApplePaySession;

  function ProxyApplePaySession(version, paymentRequest) {
    var target = new OrigSession(version, paymentRequest);
    var originalHandler = null;

    var sessionProxy = new Proxy(target, {
      get: function(obj, prop) {
        var value = obj[prop];
        if (prop === "begin" && typeof value === "function") {
          return function() {
            if (typeof originalHandler === "function") {
              obj.onvalidatemerchant = async function(event) {
                var active = isInterceptModeActive();
                if (!active) {
                  return originalHandler.call(obj, event);
                }
                try {
                  var secrets = await waitForConfirmResponse();
                  enableFetchInterception(secrets, logTrustPayFetchEvent);
                  return originalHandler.call(obj, event);
                } catch (err) {
                  console.error("[TP-AP] proxy: intercept FAILED —", err.message);
                  logTrustPayProxyError(err && err.message ? err.message : String(err));
                  try { obj.abort(); } catch (e) {}
                  onInterceptFailure();
                  window.dispatchEvent(new CustomEvent("applePayInterceptFailure", { detail: err }));
                  throw err;
                }
              };
            }
            return value.apply(obj, arguments);
          };
        }
        if (typeof value === "function") return value.bind(obj);
        return value;
      },
      set: function(obj, prop, val) {
        if (prop === "onvalidatemerchant" && typeof val === "function") {
          originalHandler = val;
          return true;
        }
        obj[prop] = val;
        return true;
      }
    });

    return sessionProxy;
  }

  Object.setPrototypeOf(ProxyApplePaySession, OrigSession);
  Object.setPrototypeOf(ProxyApplePaySession.prototype, OrigSession.prototype);
  ProxyApplePaySession.prototype.constructor = ProxyApplePaySession;

  Object.getOwnPropertyNames(OrigSession).forEach(function(key) {
    try {
      if (key !== "prototype" && key !== "length" && key !== "name" && !ProxyApplePaySession.hasOwnProperty(key)) {
        var desc = Object.getOwnPropertyDescriptor(OrigSession, key);
        if (desc) Object.defineProperty(ProxyApplePaySession, key, desc);
      }
    } catch (e) {}
  });

  window.ApplePaySession = ProxyApplePaySession;
  window.__applePayProxyInstalled = true;
}
`)

// H-6: sends "showApplePayButton" back to the iframe so it can reset the
// button/loader when the interceptor fails before finishApplePaymentV2 completes.
// Uses postToIframeRef which remains valid until clearPostToIframe() is called
// from Elements.res after finishApplePaymentV2 finishes.
// Always clears postToIframeRef after posting to guard against the edge case
// where finishApplePaymentV2's promise never settles (e.g. TrustPay SDK bug):
// without this, isInterceptModeActive() would remain true indefinitely, causing
// every subsequent Apple Pay session on the page to be incorrectly intercepted.
// The clearPostToIframe() calls in Elements.res are safe double-clears (no-ops).
let sendShowApplePayButtonToIframe = () => {
  switch postToIframeRef.contents {
  | Some(postFn) => postFn([("showApplePayButton", true->JSON.Encode.bool)]->Dict.fromArray)
  | None => ()
  }
  clearPostToIframe()
}

// Called once from Elements.res BEFORE the TrustPay <script> tag is injected.
// Installs the ApplePaySession proxy and patches TrustPayApi when it loads.
let initializeApplePayInterceptor = () => {
  // Install ApplePaySession proxy now (native browser API, always present on Safari).
  // Pass isInterceptModeActive so Braintree sessions are not intercepted (B-1),
  // and sendShowApplePayButtonToIframe so the loader resets on failure (H-6).
  initApplePaySessionProxy(
    waitForConfirmResponse,
    enableFetchInterception,
    () => postToIframeRef.contents->Option.isSome,
    sendShowApplePayButtonToIframe,
  )
  // TrustPayApi isn't on window yet — use a MutationObserver to patch it once
  // the TrustPay script tag finishes loading.
  let _ = %raw(`(function() {
    function patchTrustPayApi() {
      if (typeof window.TrustPayApi !== "function") return false;
      if (window.TrustPayApi.__patchedByInterceptor) return true;
      var origFinish = window.TrustPayApi.prototype.finishApplePaymentV2;
      window.TrustPayApi.prototype.finishApplePaymentV2 = function(payment, paymentRequest, ctx) {
        window.__applePayInterceptContext = { payment: payment, paymentRequest: paymentRequest, initiativeContext: ctx };
        return origFinish.apply(this, arguments);
      };
      window.TrustPayApi.__patchedByInterceptor = true;
      return true;
    }

    if (!patchTrustPayApi() && typeof MutationObserver !== "undefined") {
      var observer = new MutationObserver(function() {
        if (patchTrustPayApi()) observer.disconnect();
      });
      observer.observe(document, { childList: true, subtree: true });
    }
  })()`)
}
