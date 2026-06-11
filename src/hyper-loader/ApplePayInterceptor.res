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

let setPostToIframe = (fn: Dict.t<JSON.t> => unit) => {
  postToIframeRef := Some(fn)
}

// Clears the stored iframe-post callback.
// MUST be called from Elements.res in all three branches (.then / .catch / catch)
// after finishApplePaymentV2 completes.  Without this, isInterceptModeActive()
// permanently returns true after the first TrustPay session, causing every
// subsequent Braintree Apple Pay session on the same page to be incorrectly
// intercepted, have the confirm request time out (8 s), and abort.
let clearPostToIframe = () => {
  postToIframeRef := None
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

// Temporarily patches window.fetch to swap TrustPay's Secret.* fields in the
// merchant-validation FormData with the new secrets received from /confirm.
// Self-destructs after the first matching intercept.
//
// H-7 fix: also strips the plain "Secret" key (without a dot suffix).
// Implementation injected by AppleHacks.js
let enableFetchInterception: JSON.t => unit = %raw(`
function enableFetchInterception(newSecret) {
  var origFetch = window.fetch;
  var fetchPatched = false;

  window.fetch = function(url, options) {
    if (
      !fetchPatched &&
      newSecret &&
      options &&
      options.method === "POST" &&
      options.body instanceof FormData
    ) {
      var keys = Array.from(options.body.keys());
      var hasSecretKey = keys.some(function(k) {
        return k === "Secret" || k.startsWith("Secret.");
      });

      if (hasSecretKey && keys.includes("ValidationUrl")) {
        fetchPatched = true;
        window.fetch = origFetch; // self-destruct

        var newBody = new FormData();
        for (var _i = 0, _entries = options.body.entries(); ; ) {
          var _ref = _entries.next();
          if (_ref.done) break;
          var entry = _ref.value;
          if (entry[0] !== "Secret" && !entry[0].startsWith("Secret.")) {
            newBody.append(entry[0], entry[1]);
          }
        }

        if (typeof newSecret === "object" && newSecret !== null) {
          for (var subKey in newSecret) {
            if (Object.prototype.hasOwnProperty.call(newSecret, subKey)) {
              newBody.append("Secret." + subKey, newSecret[subKey]);
            }
          }
        } else {
          newBody.append("Secret", String(newSecret));
        }

        return origFetch.call(this, url, Object.assign({}, options, { body: newBody }));
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
  JSON.t => unit,
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
                  enableFetchInterception(secrets);
                  return originalHandler.call(obj, event);
                } catch (err) {
                  console.error("[TP-AP] proxy: intercept FAILED —", err.message);
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
