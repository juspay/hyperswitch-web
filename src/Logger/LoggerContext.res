type t = {
  sessionId: string,
  merchantId: string,
  profileId: string,
  paymentId: string,
  authenticationId: string,
  paymentMethod: option<LoggerTaxonomy.paymentMethod>,
}

let empty = {
  sessionId: "",
  merchantId: "",
  profileId: "",
  paymentId: "",
  authenticationId: "",
  paymentMethod: None,
}

let context = ref(empty)

let onSessionChange = ref(_ => ())

let current = () => context.contents

let keep = (existing, incoming) =>
  switch incoming {
  | Some(value) =>
    switch value->String.trim {
    | "" => existing
    | value => value
    }
  | None => existing
  }

let setSessionData = (
  ~sessionId=?,
  ~merchantId=?,
  ~profileId=?,
  ~paymentId=?,
  ~authenticationId=?,
  (),
) => {
  let previous = context.contents

  let base = switch sessionId->Option.map(String.trim) {
  | Some(sessionId) if sessionId !== "" && sessionId !== previous.sessionId => {...empty, sessionId}
  | _ => previous
  }
  context := {
      ...base,
      sessionId: base.sessionId->keep(sessionId),
      merchantId: base.merchantId->keep(merchantId),
      profileId: base.profileId->keep(profileId),
      paymentId: base.paymentId->keep(paymentId),
      authenticationId: base.authenticationId->keep(authenticationId),
    }
  if context.contents.sessionId !== previous.sessionId {
    LoggerUtils.safeRun(() => onSessionChange.contents())
  }
}

let setPaymentMethod = paymentMethod =>
  context := {...context.contents, paymentMethod: Some(paymentMethod)}

let paymentIdOfClientSecret = clientSecret =>
  clientSecret->String.split("_secret_")->Array.get(0)->Option.getOr("")

let setPaymentIdFromClientSecret = clientSecret =>
  switch clientSecret->String.trim {
  | "" => ()
  | clientSecret => setSessionData(~paymentId=clientSecret->paymentIdOfClientSecret, ())
  }

let stringField = (source, key) =>
  source->Dict.get(key)->Option.flatMap(JSON.Decode.string)->Option.getOr("")

let nestedDict = (source, key) =>
  source->Dict.get(key)->Option.flatMap(JSON.Decode.object)->Option.getOr(Dict.make())

let readField = (message, key) =>
  [
    message,
    message->nestedDict("metadata"),
    message->nestedDict("paymentOptions"),
    message->nestedDict("options"),
  ]
  ->Array.findMap(source =>
    switch source->stringField(key)->String.trim {
    | "" => None
    | value => Some(value)
    }
  )
  ->Option.getOr("")

let startSessionFromMessage = message =>
  LoggerUtils.safeRun(() =>
    setSessionData(
      ~sessionId=message->readField("sdkSessionId"),
      ~merchantId=message->readField("publishableKey"),
      ~paymentId=message->readField("clientSecret")->paymentIdOfClientSecret,
      (),
    )
  )
