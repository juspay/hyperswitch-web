open IndexedDB
let logApi = (
  ~eventName,
  ~statusCode=0,
  ~data: JSON.t=Dict.make()->JSON.Encode.object,
  ~apiLogType: HyperLoggerTypes.apiLogType,
  ~url="",
  ~paymentMethod="",
  ~result: JSON.t=Dict.make()->JSON.Encode.object,
  ~optLogger: option<HyperLoggerTypes.loggerMake>,
  ~logType: HyperLoggerTypes.logType=INFO,
  ~logCategory: HyperLoggerTypes.logCategory=API,
  ~isPaymentSession: bool=false,
) => {
  let (value, _) = switch apiLogType {
  | Request => ([("url", url->JSON.Encode.string)], [])
  | Response => (
      [("url", url->JSON.Encode.string), ("statusCode", statusCode->JSON.Encode.int)],
      [("response", data)],
    )
  | NoResponse => (
      [("url", url->JSON.Encode.string), ("statusCode", 504->JSON.Encode.int), ("response", data)],
      [("response", data)],
    )
  | Err => (
      [
        ("url", url->JSON.Encode.string),
        ("statusCode", statusCode->JSON.Encode.int),
        ("response", data),
      ],
      [("response", data)],
    )
  | Method => ([("method", paymentMethod->JSON.Encode.string)], [("result", result)])
  }
  switch optLogger {
  | Some(logger) =>
    logger.setLogApi(
      ~eventName,
      ~value=ArrayType(value),
      // ~internalMetadata=ArrayType(internalMetadata),
      ~logType,
      ~logCategory,
      ~apiLogType,
      ~isPaymentSession,
    )
  | None => ()
  }
}

let logInputChangeInfo = (text, logger: HyperLoggerTypes.loggerMake) => {
  logger.setLogInfo(~value=text, ~eventName=INPUT_FIELD_CHANGED)
}

let handleLogging = (
  ~optLogger: option<HyperLoggerTypes.loggerMake>,
  ~value,
  // ~internalMetadata="",
  ~eventName,
  ~paymentMethod,
  ~logType: HyperLoggerTypes.logType=INFO,
) => {
  switch optLogger {
  | Some(logger) =>
    logger.setLogInfo(
      ~value,
      // ~internalMetadata,
      ~eventName,
      ~paymentMethod,
      ~logType,
    )
  | _ => ()
  }
}

type eventListenerLogger = {
  track: string => unit,
  logOnMount: unit => unit,
}

let makeEventListenerLogger = (~logger: HyperLoggerTypes.loggerMake, ~componentType) => {
  let eventListeners = []
  let hasMounted = ref(false)

  let log = () => {
    let value =
      [
        ("componentType", componentType->JSON.Encode.string),
        ("eventListeners", eventListeners->Array.map(JSON.Encode.string)->JSON.Encode.array),
      ]
      ->Dict.fromArray
      ->JSON.Encode.object
      ->JSON.stringify
    logger.setLogInfo(~value, ~eventName=PAYMENT_ELEMENT_EVENT_LISTENERS, ~logType=INFO)
  }

  let logOnMount = () =>
    if !hasMounted.contents {
      hasMounted := true
      log()
    }

  let track = name =>
    if !(eventListeners->Array.includes(name)) {
      eventListeners->Array.push(name)->ignore
      if hasMounted.contents {
        log()
      }
    }

  {track, logOnMount}
}

let defaultEventListenerLogger = {track: _ => (), logOnMount: () => ()}

type eventListenerTracker = {
  logger: eventListenerLogger,
  register: ref<string> => unit,
  onMount: string => unit,
  destroy: unit => unit,
}

type eventListenerScope = {
  logger: eventListenerLogger,
  mutable mountedSelector: option<string>,
  mutable isDestroyed: bool,
}

type eventListenerHandle = {
  scope: ref<eventListenerScope>,
  listeners: array<string>,
  mutable selectorRef: ref<string>,
  mutable hasRegistration: bool,
  mutable mountSelector: option<string>,
  mutable isPaired: bool,
}

let ignoreErrors = (fn, arg) =>
  try fn(arg) catch {
  | _ => ()
  }

let deferEventListenerPairing = fn =>
  Promise.resolve()
  ->Promise.thenResolve(() => ignoreErrors(fn, ()))
  ->Promise.catch(_ => Promise.resolve())
  ->ignore

let makeEventListenerTrackerFactory = (~logger) => {
  let handlesByType: Dict.t<array<eventListenerHandle>> = Dict.make()
  componentType => {
    let makeScope = () => {
      logger: makeEventListenerLogger(~logger, ~componentType),
      mountedSelector: None,
      isDestroyed: false,
    }
    let handle = {
      scope: ref(makeScope()),
      listeners: [],
      selectorRef: ref(""),
      hasRegistration: false,
      mountSelector: None,
      isPaired: false,
    }
    let handles = () => handlesByType->Dict.get(componentType)->Option.getOr([])
    let prune = () =>
      handlesByType->Dict.set(
        componentType,
        handles()->Array.filter(h =>
          !h.scope.contents.isDestroyed && (!h.isPaired || h.mountSelector->Option.isSome)
        ),
      )
    let enqueue = () => {
      prune()
      if !handle.isPaired || handle.mountSelector->Option.isSome {
        let handles = handles()
        if !(handles->Array.includes(handle)) {
          handles->Array.push(handle)->ignore
          handlesByType->Dict.set(componentType, handles)
        }
      }
    }
    let connect = (registration, mounting) => {
      if registration.scope.contents.mountedSelector->Option.isSome {
        mounting.listeners->Array.forEach(registration.scope.contents.logger.track)
        mounting.scope := registration.scope.contents
      } else {
        registration.listeners->Array.forEach(mounting.scope.contents.logger.track)
        registration.scope := mounting.scope.contents
      }

      registration.scope.contents.mountedSelector = mounting.mountSelector
      registration.isPaired = true
      mounting.isPaired = true
      prune()
    }
    let pairRegistration = () => {
      if !handle.scope.contents.isDestroyed && handle.mountSelector->Option.isNone {
        let sibling =
          handles()->Array.find(h =>
            !h.scope.contents.isDestroyed &&
            handle.selectorRef.contents !== "" &&
            h.mountSelector === Some(handle.selectorRef.contents)
          )
        sibling->Option.forEach(mounting => connect(handle, mounting))
      }
    }
    let pairMount = () => {
      handles()
      ->Array.filter(h =>
        !h.scope.contents.isDestroyed &&
        h.hasRegistration &&
        h.mountSelector->Option.isNone &&
        h.selectorRef.contents !== "" &&
        handle.mountSelector === Some(h.selectorRef.contents)
      )
      ->Array.forEach(registration => connect(registration, handle))
    }
    let register = selectorRef => {
      if !handle.scope.contents.isDestroyed {
        handle.selectorRef = selectorRef
        handle.hasRegistration = true
        enqueue()
        deferEventListenerPairing(pairRegistration)
      }
    }
    let track = name => {
      if !(handle.listeners->Array.includes(name)) {
        handle.listeners->Array.push(name)->ignore
      }
      if !handle.scope.contents.isDestroyed {
        handle.scope.contents.logger.track(name)
      }
    }
    let logOnMount = () => {
      if !handle.scope.contents.isDestroyed {
        pairMount()
        handle.scope.contents.mountedSelector = handle.mountSelector
        handle.scope.contents.logger.logOnMount()
      }
    }
    let onMount = selector => {
      if (
        handle.isPaired &&
        handle.mountSelector->Option.isNone &&
        (handle.scope.contents.isDestroyed ||
        handle.scope.contents.mountedSelector !== Some(selector))
      ) {
        handle.scope := makeScope()
        handle.listeners->Array.forEach(handle.scope.contents.logger.track)
        handle.isPaired = false
      }
      handle.mountSelector = Some(selector)
      handlesByType->Dict.set(
        componentType,
        handles()->Array.filter(h => h === handle || h.mountSelector !== Some(selector)),
      )
      enqueue()
    }
    let destroy = () => {
      if handle.mountSelector->Option.isSome {
        pairMount()
      } else if handle.hasRegistration {
        pairRegistration()
      }
      handle.scope.contents.isDestroyed = true
      prune()
    }
    {
      register: selectorRef => ignoreErrors(register, selectorRef),
      logger: {
        track: name => ignoreErrors(track, name),
        logOnMount: () => ignoreErrors(logOnMount, ()),
      },
      onMount: selector => ignoreErrors(onMount, selector),
      destroy: () => ignoreErrors(destroy, ()),
    }
  }
}

let defaultEventListenerTracker = {
  logger: defaultEventListenerLogger,
  register: _ => (),
  onMount: _ => (),
  destroy: () => (),
}

let eventNameToStrMapper = (eventName: HyperLoggerTypes.eventName) => (eventName :> string)

let convertToScreamingSnakeCase = text => {
  text->String.trim->String.replaceRegExp(/ /g, "_")->String.toUpperCase
}

let toSnakeCaseWithSeparator = (str, separator) => {
  str->Stdlib.String.replaceRegExpBy0Unsafe(/[A-Z]/g, (
    ~match as letter,
    ~offset as _,
    ~input as _,
  ) => `${separator}${letter->String.toLowerCase}`)
}

let defaultLoggerConfig: HyperLoggerTypes.loggerMake = {
  sendLogs: () => (),
  setClientSecret: _x => (),
  setSdkAuthorization: _x => (),
  setPaymentId: _x => (),
  setConfirmPaymentValue: (~paymentType as _) => {Dict.make()->JSON.Encode.object},
  setLogError: (
    ~value as _,
    // ~internalMetadata as _=?,
    ~eventName as _,
    ~timestamp as _=?,
    ~latency as _=?,
    ~logType as _=?,
    ~logCategory as _=?,
    ~paymentMethod as _=?,
  ) => (),
  setLogApi: (
    ~value as _,
    // ~internalMetadata as _,
    ~eventName as _,
    ~timestamp as _=?,
    ~logType as _=?,
    ~logCategory as _=?,
    ~paymentMethod as _=?,
    ~apiLogType as _=?,
    ~isPaymentSession as _=?,
  ) => (),
  setLogInfo: (
    ~value as _,
    // ~internalMetadata as _=?,
    ~eventName as _,
    ~timestamp as _=?,
    ~latency as _=?,
    ~logType as _=?,
    ~logCategory as _=?,
    ~paymentMethod as _=?,
  ) => (),
  setLogInitiated: () => (),
  setMerchantId: _x => (),
  setSessionId: _x => (),
  setMetadata: _x => (),
  setSource: _x => (),
}

let saveLogsToIndexedDB = (logs: array<HyperLoggerTypes.logFile>) => {
  Promise.make((resolve, reject) => {
    let request = openDBAndGetRequest(~dbName="HyperLogger", ~objectStoreName="logs")

    request->OpenDBRequest.onsuccess(_ => {
      let db = OpenDBRequest.result(request)

      if logs->Array.length > 0 {
        let transaction = db->DB.transaction(["logs"], "readwrite")
        let store = transaction->Transaction.objectStore("logs")

        transaction->Transaction.oncomplete(
          _ => {
            db->DB.close
            resolve()
          },
        )

        transaction->Transaction.onerror(
          _ => {
            db->DB.close
            reject()
          },
        )

        logs->Array.forEach(
          log => {
            let _ = store->ObjectStore.put(log)
          },
        )
      } else {
        db->DB.close
        reject()
      }
    })

    request->OpenDBRequest.onerror(_ => {
      reject()
    })
  })
}

let retrieveLogsFromIndexedDB = () => {
  Promise.make((resolve, reject) => {
    let request = openDBAndGetRequest(~dbName="HyperLogger", ~objectStoreName="logs")

    request->OpenDBRequest.onsuccess(_ => {
      let db = OpenDBRequest.result(request)
      let transaction = db->DB.transaction(["logs"], "readonly")
      let store = transaction->Transaction.objectStore("logs")
      let getAllRequest = store->ObjectStore.getAll

      getAllRequest->Request.onsuccess(
        _ => {
          let result = Request.result(getAllRequest)
          db->DB.close
          resolve(result)
        },
      )

      getAllRequest->Request.onerror(
        _ => {
          db->DB.close
          reject([])
        },
      )
    })

    request->OpenDBRequest.onerror(_ => {
      reject([])
    })
  })
}

let clearLogsFromIndexedDB = () => {
  Promise.make((resolve, reject) => {
    let request = openDBAndGetRequest(~dbName="HyperLogger", ~objectStoreName="logs")

    request->OpenDBRequest.onsuccess(_ => {
      let db = OpenDBRequest.result(request)
      let transaction = db->DB.transaction(["logs"], "readwrite")
      let store = transaction->Transaction.objectStore("logs")
      let clearRequest = store->ObjectStore.clear

      clearRequest->Request.onsuccess(
        _ => {
          db->DB.close
          resolve()
        },
      )

      clearRequest->Request.onerror(
        _ => {
          db->DB.close
          reject()
        },
      )
    })

    request->OpenDBRequest.onerror(_ => {
      reject()
    })
  })
}

let apiEventInitMapper = (eventName: HyperLoggerTypes.eventName): option<
  HyperLoggerTypes.eventName,
> =>
  switch eventName {
  | CONFIRM_CALL => Some(CONFIRM_CALL_INIT)
  | CREATE_CUSTOMER_PAYMENT_METHODS_CALL => Some(CREATE_CUSTOMER_PAYMENT_METHODS_CALL_INIT)
  | POLL_STATUS_CALL => Some(POLL_STATUS_CALL_INIT)
  | COMPLETE_AUTHORIZE_CALL => Some(COMPLETE_AUTHORIZE_CALL_INIT)
  | POST_SESSION_TOKENS_CALL => Some(POST_SESSION_TOKENS_CALL_INIT)
  | PAYMENT_METHODS_AUTH_EXCHANGE_CALL => Some(PAYMENT_METHODS_AUTH_EXCHANGE_CALL_INIT)
  | PAYMENT_METHODS_AUTH_LINK_CALL => Some(PAYMENT_METHODS_AUTH_LINK_CALL_INIT)
  | SESSIONS_CALL => Some(SESSIONS_CALL_INIT)
  | RETRIEVE_CALL => Some(RETRIEVE_CALL_INIT)
  | AUTHENTICATION_CALL => Some(AUTHENTICATION_CALL_INIT)
  | CONFIRM_PAYOUT_CALL => Some(CONFIRM_PAYOUT_CALL_INIT)
  | PAYMENT_METHOD_ELIGIBILITY_CALL => Some(PAYMENT_METHOD_ELIGIBILITY_CALL_INIT)
  | SDK_CONFIGS_CALL => Some(SDK_CONFIGS_CALL_INIT)
  | CLIENT_LIST_CALL => Some(CLIENT_LIST_CALL_INIT)
  | ENABLED_AUTHN_METHODS_TOKEN_CALL => Some(ENABLED_AUTHN_METHODS_TOKEN_CALL)
  | ELIGIBILITY_CHECK_CALL => Some(ELIGIBILITY_CHECK_CALL)
  | AUTHENTICATION_SYNC_CALL => Some(AUTHENTICATION_SYNC_CALL)
  | PAYMENT_METHOD_SESSION_RETRIEVE_CALL => Some(PAYMENT_METHOD_SESSION_RETRIEVE_CALL_INIT)
  | PAYMENT_METHOD_SESSION_CONFIRM_CALL => Some(PAYMENT_METHOD_SESSION_CONFIRM_CALL_INIT)
  | PAYMENT_METHOD_SESSION_UPDATE_CALL => Some(PAYMENT_METHOD_SESSION_UPDATE_CALL_INIT)
  | APP_RENDERED
  | PAYMENT_METHOD_CHANGED
  | PAYMENT_DATA_FILLED
  | PAYMENT_ATTEMPT
  | PAYMENT_SUCCESS
  | PAYMENT_FAILED
  | INPUT_FIELD_CHANGED
  | RETRIEVE_CALL_INIT
  | AUTHENTICATION_CALL_INIT
  | CONFIRM_CALL_INIT
  | CONFIRM_PAYOUT_CALL_INIT
  | SESSIONS_CALL_INIT
  | CREATE_CUSTOMER_PAYMENT_METHODS_CALL_INIT
  | SDK_CONFIGS_CALL_INIT
  | TRUSTPAY_SCRIPT
  | PM_AUTH_CONNECTOR_SCRIPT
  | GOOGLE_PAY_SCRIPT
  | APPLE_PAY_FLOW
  | GOOGLE_PAY_FLOW
  | PAYPAL_FLOW
  | PAYPAL_SDK_FLOW
  | KLARNA_CHECKOUT_FLOW
  | KLARNA_SDK_FLOW
  | APP_INITIATED
  | APP_REINITIATED
  | LOG_INITIATED
  | LOADER_CALLED
  | ORCA_ELEMENTS_CALLED
  | PAYMENT_OPTIONS_PROVIDED
  | BLUR
  | FOCUS
  | CLEAR
  | CONFIRM_PAYMENT
  | CONFIRM_CARD_PAYMENT
  | IS_READY_STATUS_CHECK
  | SDK_CRASH
  | INVALID_PK
  | DEPRECATED_LOADSTRIPE
  | REQUIRED_PARAMETER
  | TYPE_BOOL_ERROR
  | TYPE_INT_ERROR
  | TYPE_STRING_ERROR
  | INVALID_FORMAT
  | SDK_CONNECTOR_WARNING
  | VALUE_OUT_OF_RANGE
  | HTTP_NOT_ALLOWED
  | INTERNAL_API_DOWN
  | REDIRECTING_USER
  | DISPLAY_BANK_TRANSFER_INFO_PAGE
  | DISPLAY_QR_CODE_INFO_PAGE
  | DISPLAY_VOUCHER
  | DISPLAY_THREE_DS_SDK
  | THREE_DS_METHOD
  | THREE_DS_METHOD_RESULT
  | PAYMENT_METHODS_RESPONSE
  | LOADER_CHANGED
  | PAYMENT_SESSION_INITIATED
  | PAYMENT_METHOD_SESSION_INITIATED
  | PAYMENT_METHOD_SESSION_FIELD_MOUNTED
  | PAYMENT_METHOD_SESSION_FIELD_RENDERED
  | PAYMENT_METHOD_SESSION_DATA_FILLED
  | PAYMENT_METHOD_SESSION_TOKENIZE_INIT
  | PAYMENT_METHOD_SESSION_TOKENIZE
  | PAYMENT_METHOD_SESSION_RETRIEVE_CALL_INIT
  | PAYMENT_METHOD_SESSION_CONFIRM_CALL_INIT
  | PAYMENT_METHOD_SESSION_UPDATE_CALL_INIT
  | POLL_STATUS_CALL_INIT
  | COMPLETE_AUTHORIZE_CALL_INIT
  | PLAID_SDK
  | PAYMENT_METHODS_AUTH_EXCHANGE_CALL_INIT
  | PAYMENT_METHODS_AUTH_LINK_CALL_INIT
  | PAYMENT_MANAGEMENT_ELEMENTS_CALLED
  | EXTERNAL_TAX_CALCULATION
  | POST_SESSION_TOKENS_CALL_INIT
  | PAZE_SDK_FLOW
  | SAMSUNG_PAY_SCRIPT
  | SAMSUNG_PAY
  | CLICK_TO_PAY_SCRIPT
  | CLICK_TO_PAY_FLOW
  | PAYMENT_METHOD_TYPE_DETECTION_FAILED
  | THREE_DS_POPUP_REDIRECTION
  | NETWORK_STATE
  | CARD_SCHEME_SELECTION
  | S3_API
  | PAYMENT_METHOD_ELIGIBILITY_CALL_INIT
  | PRELOAD_SDK_WITH_PARAMS
  | APPLE_PAY_BRAINTREE_SCRIPT
  | BRAINTREE_CLIENT_SCRIPT
  | AUTHENTICATED_SESSION_INITIATED
  | ONE_CLICK_HANDLER_CALLBACK
  | PAYMENT_ELEMENT_OPTIONS
  | PAYMENT_ELEMENT_EVENT_LISTENERS
  | TEST_MODE
  | DDC_FLOW
  | CARD_FORM_FLOW
  | SAVED_PAYMENT_METHODS_FLOW
  | VGS_VAULT_FLOW
  | UPDATE_INTENT
  | UPDATE_SDK
  | DYNAMIC_FIELDS_RENDERED
  | DYNAMIC_FIELDS_CONFIG
  | CLIENT_LIST_CALL_INIT =>
    None
  }
