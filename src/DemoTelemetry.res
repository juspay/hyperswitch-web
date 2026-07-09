open Utils
open PaymentHelpersTypes

let isEnabled = () => true

let nextCardFlowOverride: ref<option<string>> = ref(None)

let postMessageToDemoTargets: JSON.t => unit = %raw(`
function(message) {
  try {
    if (typeof window === "undefined") {
      return;
    }

    if (window.parent && window.parent !== window) {
      window.parent.postMessage(message, "*");
    }

    if (window.top && window.top !== window && window.top !== window.parent) {
      window.top.postMessage(message, "*");
    }
  } catch (_) {}
}
`)

let emptyPayload = () => Dict.make()->JSON.Encode.object

let paymentTypeToFlow = paymentType =>
  switch paymentType {
  | Card => Some("card")
  | Gpay => Some("google_pay")
  | Applepay => Some("apple_pay")
  | _ => None
  }

let isDemoFlow = paymentType => paymentType->paymentTypeToFlow->Option.isSome

let isKnownFlow = flow =>
  switch flow {
  | "card"
  | "saved_card"
  | "google_pay"
  | "apple_pay" => true
  | _ => false
  }

let emit = (~eventName, ~flow, ~payload=?, ()) => {
  if isEnabled() && isKnownFlow(flow) {
    let eventPayload =
      [
        ("eventName", eventName->JSON.Encode.string),
        ("flow", flow->JSON.Encode.string),
        ("timestamp", Date.now()->JSON.Encode.float),
        ("data", payload->Option.getOr(emptyPayload())),
      ]->getJsonFromArrayOfJson

    [("type", "DEMO_EVENT"->JSON.Encode.string), ("payload", eventPayload)]
    ->getJsonFromArrayOfJson
    ->postMessageToDemoTargets
  }
}

let emitForPaymentType = (~paymentType, ~eventName, ~payload=?, ~flowOverride=None, ()) => {
  if isDemoFlow(paymentType) {
    let flow = switch flowOverride {
    | Some(flow) => Some(flow)
    | None => paymentType->paymentTypeToFlow
    }
    switch flow {
    | Some(flow) => emit(~eventName, ~flow, ~payload?, ())
    | None => ()
    }
  }
}

let markNextCardFlow = flow => {
  if isKnownFlow(flow) {
    nextCardFlowOverride := Some(flow)
  }
}

let takeFlowOverride = (~paymentType) =>
  switch paymentType {
  | Card =>
    let flow = nextCardFlowOverride.contents
    nextCardFlowOverride := None
    flow
  | _ => None
  }

let payload = entries => entries->getJsonFromArrayOfJson
