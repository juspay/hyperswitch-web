type t = LoggerTypes.context

let empty: t = {
  sessionId: "",
  merchantId: "",
  paymentId: "",
  pmSessionId: "",
  authenticationId: "",
  scoped: false,
}

let context = ref(empty)

let onSessionChange = ref(_ => ())

let current = () => context.contents

let keep = (existing, incoming) =>
  switch incoming->Option.map(String.trim) {
  | Some("") | None => existing
  | Some(value) => value
  }

let fillFrom = (started: t, latest: t): t =>
  started.scoped || (started.sessionId !== "" && started.sessionId !== latest.sessionId)
    ? started
    : {
        sessionId: latest.sessionId->keep(Some(started.sessionId)),
        merchantId: latest.merchantId->keep(Some(started.merchantId)),
        paymentId: latest.paymentId->keep(Some(started.paymentId)),
        pmSessionId: latest.pmSessionId->keep(Some(started.pmSessionId)),
        authenticationId: latest.authenticationId->keep(Some(started.authenticationId)),
        scoped: false,
      }

let setSessionData = (
  ~sessionId=?,
  ~merchantId=?,
  ~paymentId=?,
  ~pmSessionId=?,
  ~authenticationId=?,
  (),
) => {
  let previous = context.contents
  let base = switch sessionId->Option.map(String.trim) {
  | Some(sessionId) if sessionId !== "" && sessionId !== previous.sessionId => {...empty, sessionId}
  | _ => previous
  }
  let next: t = {
    sessionId: base.sessionId->keep(sessionId),
    merchantId: base.merchantId->keep(merchantId),
    paymentId: base.paymentId->keep(paymentId),
    pmSessionId: base.pmSessionId->keep(pmSessionId),
    authenticationId: base.authenticationId->keep(authenticationId),
    scoped: false,
  }
  context := next
  if next.sessionId !== previous.sessionId {
    WebLoggerUtils.safeRun(() => onSessionChange.contents())
  }
  if (
    next.sessionId !== previous.sessionId ||
    next.merchantId !== previous.merchantId ||
    next.paymentId !== previous.paymentId ||
    next.pmSessionId !== previous.pmSessionId ||
    next.authenticationId !== previous.authenticationId
  ) {
    WebLoggerUtils.safeRun(() => LoggerQueue.backfillContext(next))
  }
}

let paymentIdOfClientSecret = clientSecret =>
  switch clientSecret->String.split("_secret_") {
  | parts if parts->Array.length >= 2 => parts->Array.getUnsafe(0)
  | _ => ""
  }

let sdkAuthorizationValue = (sdkAuthorization, key) =>
  try {
    let prefix = key ++ "="
    sdkAuthorization
    ->Window.atob
    ->String.split(",")
    ->Array.findMap(entry =>
      entry->String.startsWith(prefix)
        ? switch entry->String.sliceToEnd(~start=prefix->String.length) {
          | "" => None
          | value => Some(value)
          }
        : None
    )
  } catch {
  | _ => None
  }

let paymentIdOfSdkAuthorization = sdkAuthorization =>
  sdkAuthorization->sdkAuthorizationValue("payment_id")

let pmSessionIdOfSdkAuthorization = sdkAuthorization =>
  sdkAuthorization->sdkAuthorizationValue("payment_method_session_id")

let setPaymentId = paymentId =>
  switch paymentId->String.trim {
  | "" => ()
  | paymentId => setSessionData(~paymentId, ())
  }

let setPmSessionId = pmSessionId =>
  switch pmSessionId->String.trim {
  | "" => ()
  | pmSessionId => setSessionData(~pmSessionId, ())
  }

let setPaymentIdFromCredentials = (~clientSecret="", ~sdkAuthorization=?) => {
  let paymentId = clientSecret->paymentIdOfClientSecret
  sdkAuthorization
  ->Option.flatMap(paymentIdOfSdkAuthorization)
  ->Option.getOr(paymentId)
  ->setPaymentId
  sdkAuthorization->Option.flatMap(pmSessionIdOfSdkAuthorization)->Option.forEach(setPmSessionId)
}

let setPaymentIdFromClientSecret = clientSecret =>
  clientSecret->paymentIdOfClientSecret->setPaymentId

let setAuthenticationId = authenticationId =>
  switch authenticationId->String.trim {
  | "" => ()
  | authenticationId => setSessionData(~authenticationId, ())
  }

let mayCarryContext: 'data => bool = %raw(`
  function (d) {
    return typeof d == "string" &&
      /"(?:sdkSessionId|publishableKey|sdkAuthorization|paymentId|clientSecret|pmSessionId|authenticationId)"\s*:/.test(d);
  }
`)

let startSessionFromMessage = message =>
  WebLoggerUtils.safeRun(() => {
    let nested = key =>
      message->Dict.get(key)->Option.flatMap(JSON.Decode.object)->Option.getOr(Dict.make())
    let sources = [
      message,
      nested("loggerContext"),
      nested("metadata"),
      nested("paymentOptions"),
      nested("options"),
    ]
    let readField = key =>
      sources
      ->Array.findMap(source =>
        switch source->Dict.get(key)->Option.flatMap(JSON.Decode.string)->Option.map(String.trim) {
        | Some("") | None => None
        | value => value
        }
      )
      ->Option.getOr("")
    let sdkAuthorization = readField("sdkAuthorization")
    let paymentId = switch sdkAuthorization->paymentIdOfSdkAuthorization {
    | Some(paymentId) => paymentId
    | None =>
      switch readField("paymentId") {
      | "" => readField("clientSecret")->paymentIdOfClientSecret
      | paymentId => paymentId
      }
    }
    let pmSessionId =
      sdkAuthorization
      ->pmSessionIdOfSdkAuthorization
      ->Option.getOr(readField("pmSessionId"))
    setSessionData(
      ~sessionId=readField("sdkSessionId"),
      ~merchantId=readField("publishableKey"),
      ~paymentId,
      ~pmSessionId,
      ~authenticationId=readField("authenticationId"),
      (),
    )
  })

let sharedContext = (~context=context.contents, ()) => {
  let {sessionId, merchantId, paymentId, pmSessionId, authenticationId} = context
  (
    "loggerContext",
    [
      ("sdkSessionId", sessionId->JSON.Encode.string),
      ("publishableKey", merchantId->JSON.Encode.string),
      ("paymentId", paymentId->JSON.Encode.string),
      ("pmSessionId", pmSessionId->JSON.Encode.string),
      ("authenticationId", authenticationId->JSON.Encode.string),
    ]
    ->Dict.fromArray
    ->JSON.Encode.object,
  )
}
