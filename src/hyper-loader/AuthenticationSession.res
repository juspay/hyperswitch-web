open Types
open Utils
open Identity
open Promise
open EventListenerManager

let make = (
  options,
  setIframeRef,
  ~clientSecret,
  ~publishableKey,
  ~logger: option<HyperLoggerTypes.loggerMake>,
  ~redirectionFlags: RecoilAtomTypes.redirectionFlags,
) => {
  let logger = logger->Option.getOr(LoggerUtils.defaultLoggerConfig)
  let selectorString = "authentication-id"
  let customPodUri =
    options
    ->JSON.Decode.object
    ->Option.flatMap(x => x->Dict.get("customPodUri"))
    ->Option.flatMap(JSON.Decode.string)
    ->Option.getOr("")
  let endpoint = ApiEndpoint.getApiEndPoint(~publishableKey)

  let iframeRef = []

  let setElementIframeRef = ref => {
    iframeRef->Array.push(ref)->ignore
    setIframeRef(ref)
  }

  let redirect = ref("always")

  let handlePollStatusMessage = (ev: Types.event) => {
    let eventDataObject = ev.data->anyTypeToJson
    let headers = [("Content-Type", "application/json"), ("api-key", publishableKey)]

    let handleRetrievePaymentResponse = json => {
      let dict = json->getDictFromJson
      let status = dict->getString("status", "")
      let returnUrl = dict->getString("return_url", "")
      let redirectUrl = `${returnUrl}?payment_intent_client_secret=${clientSecret}&status=${status}`
      if redirect.contents === "always" {
        Utils.replaceRootHref(redirectUrl, redirectionFlags)
        resolve(JSON.Encode.null)
      } else {
        messageCurrentWindow([
          ("submitSuccessful", true->JSON.Encode.bool),
          ("data", json),
          ("url", redirectUrl->JSON.Encode.string),
        ])
        resolve(json)
      }
    }

    let retrievePaymentIntentWrapper = redirectUrl => {
      PaymentHelpers.retrievePaymentIntent(
        clientSecret,
        headers,
        ~optLogger=Some(logger),
        ~customPodUri,
        ~isForceSync=true,
        ~isAuthenticationSession=true,
        ~isSendLogToParent=true,
      )
      ->then(json => json->handleRetrievePaymentResponse)
      ->catch(err => {
        if redirect.contents === "always" {
          Utils.replaceRootHref(redirectUrl->JSON.Decode.string->Option.getOr(""), redirectionFlags)
          resolve(JSON.Encode.null)
        } else {
          messageCurrentWindow([
            ("submitSuccessful", false->JSON.Encode.bool),
            ("error", err->anyTypeToJson),
            ("url", redirectUrl),
          ])
          resolve(err->anyTypeToJson)
        }
      })
      ->finally(_ => messageCurrentWindow([("fullscreen", false->JSON.Encode.bool)]))
    }

    switch eventDataObject->getOptionalJsonFromJson("openurl_if_required") {
    | Some(redirectUrl) =>
      messageCurrentWindow([
        ("fullscreen", true->JSON.Encode.bool),
        ("param", "paymentloader"->JSON.Encode.string),
        ("iframeId", selectorString->JSON.Encode.string),
      ])
      retrievePaymentIntentWrapper(redirectUrl)
      ->then(_ => resolve())
      ->catch(_ => resolve())
      ->ignore

    | None => ()
    }
  }

  addSmartEventListener("message", handlePollStatusMessage, "onPollStatusMsg")

  let mountPostMessage = (_, _, _) => {
    ()
  }

  let authenitcationDiv = CommonHooks.createElement("div")
  let authenticationId = "authentication-id"
  authenitcationDiv.id = authenticationId

  CommonHooks.appendChild(authenitcationDiv)

  LoaderPaymentElement.make(
    "payment",
    options,
    setElementIframeRef,
    iframeRef,
    mountPostMessage,
    ~redirectionFlags: RecoilAtomTypes.redirectionFlags,
  ).mount(`#${authenticationId}`)

  let defaultInitAuthenticationSession = {
    startAuthenticationSession: _ =>
      AuthenticationSessionMethods.startAuthenticationSession(
        ~clientSecret,
        ~publishableKey,
        ~endpoint,
        ~logger,
        ~customPodUri,
        ~redirectionFlags,
        ~iframeId=authenticationId,
      ),
  }

  defaultInitAuthenticationSession
}
