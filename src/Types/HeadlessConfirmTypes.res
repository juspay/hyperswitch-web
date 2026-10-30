open Utils

let fullscreenType = "headlessConfirm"
let readyKey = "headlessConfirmFrameReady"
let requestKey = "headlessConfirmRequest"
let resultKey = "headlessConfirmResult"

type cvcWidget = {
  frameName: string,
  cardBrand: string,
}

type request = {
  body: array<(string, JSON.t)>,
  paymentType: string,
  returnUrl: string,
  redirect: string,
  publishableKey: string,
  clientSecret: string,
  sdkAuthorization: option<string>,
  customPodUri: string,
  endpoint: option<string>,
  manualRetry: bool,
  cvcWidget: option<cvcWidget>,
}

let toNullableString = value => value->Option.mapOr(JSON.Encode.null, JSON.Encode.string)

let requestToJson = request =>
  [
    ("body", request.body->getJsonFromArrayOfJson),
    ("paymentType", request.paymentType->JSON.Encode.string),
    ("returnUrl", request.returnUrl->JSON.Encode.string),
    ("redirect", request.redirect->JSON.Encode.string),
    ("publishableKey", request.publishableKey->JSON.Encode.string),
    ("clientSecret", request.clientSecret->JSON.Encode.string),
    ("sdkAuthorization", request.sdkAuthorization->toNullableString),
    ("customPodUri", request.customPodUri->JSON.Encode.string),
    ("endpoint", request.endpoint->toNullableString),
    ("manualRetry", request.manualRetry->JSON.Encode.bool),
    (
      "cvcWidget",
      request.cvcWidget->Option.mapOr(JSON.Encode.null, ({frameName, cardBrand}) =>
        [
          ("frameName", frameName->JSON.Encode.string),
          ("cardBrand", cardBrand->JSON.Encode.string),
        ]->getJsonFromArrayOfJson
      ),
    ),
  ]->getJsonFromArrayOfJson

let requestFromJson = json => {
  let dict = json->getDictFromJson
  {
    body: dict->getDictFromDict("body")->Dict.toArray,
    paymentType: dict->getString("paymentType", ""),
    returnUrl: dict->getString("returnUrl", ""),
    redirect: dict->getString("redirect", "if_required"),
    publishableKey: dict->getString("publishableKey", ""),
    clientSecret: dict->getString("clientSecret", ""),
    sdkAuthorization: dict->getOptionString("sdkAuthorization")->getNonEmptyOption,
    customPodUri: dict->getString("customPodUri", ""),
    endpoint: dict->getOptionString("endpoint")->getNonEmptyOption,
    manualRetry: dict->getBool("manualRetry", false),
    cvcWidget: dict
    ->Dict.get("cvcWidget")
    ->Option.flatMap(JSON.Decode.object)
    ->Option.map(widget => {
      frameName: widget->getString("frameName", ""),
      cardBrand: widget->getString("cardBrand", ""),
    }),
  }
}
