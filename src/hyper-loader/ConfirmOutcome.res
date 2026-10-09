open Promise
open Utils

type context = {
  publishableKey: string,
  clientSecret: string,
  sdkAuthorization: option<string>,
  customPodUri: string,
  logger: HyperLoggerTypes.loggerMake,
  redirectionFlags: JotaiAtomTypes.redirectionFlags,
}

@val external window: Dom.element = "window"

let getRedirectUrl = (~ctx, ~returnUrl, ~status) => {
  let url = URLModule.makeUrl(returnUrl)
  if ctx.sdkAuthorization->Option.isNone {
    url.searchParams.set("payment_intent_client_secret", ctx.clientSecret)
  }
  url.searchParams.set(
    "payment_id",
    getPaymentIdOrExtractFromSdkAuth(
      ~clientSecret=ctx.clientSecret,
      ~sdkAuthorization=ctx.sdkAuthorization,
    ),
  )
  url.searchParams.set("status", status)
  url.href
}

let serverError = message => handleFailureResponse(~message, ~errorType="server_error")

let resolveIntent = (intent, ~ctx, ~redirect, ~returnUrl) =>
  switch intent->JSON.Decode.object {
  | Some(dict) if dict->Dict.get("error")->Option.isSome => intent
  | Some(dict) =>
    if redirect === "always" {
      let status = dict->getString("status", "")
      try {
        replaceRootHref(getRedirectUrl(~ctx, ~returnUrl, ~status), ctx.redirectionFlags)
      } catch {
      | _ => ()
      }
    }
    intent
  | None => serverError("Failed to retrieve the payment status.")
  }

let retrieveForceSync = ctx =>
  PaymentHelpers.retrievePaymentIntent(
    ctx.clientSecret,
    ~publishableKey=ctx.publishableKey,
    ~logger=ctx.logger,
    ~customPodUri=ctx.customPodUri,
    ~isForceSync=true,
    ~sdkAuthorization=ctx.sdkAuthorization,
  )

let pollThenRetrieve = (pollStatus, ~ctx) => {
  let dict = pollStatus->getDictFromJson
  let listenerKey = "onHeadlessPollStatusOpenUrl"
  let handleOwnWindowOpenUrl = (ev: Types.event) =>
    if ev.source === window {
      switch ev.data->Identity.anyTypeToJson->getDictFromJson->Dict.get("openurl") {
      | Some(url) =>
        EventListenerManager.removeSmartEventListener("message", listenerKey)
        replaceRootHref(url->JSON.Decode.string->Option.getOr(""), ctx.redirectionFlags)
      | None => ()
      }
    }
  EventListenerManager.addSmartEventListener("message", handleOwnWindowOpenUrl, listenerKey)
  PaymentHelpers.pollStatus(
    ~publishableKey=ctx.publishableKey,
    ~customPodUri=ctx.customPodUri,
    ~pollId=dict->getString("poll_id", ""),
    ~interval=dict->getString("delay_in_secs", "")->Int.fromString->Option.getOr(1) * 1000,
    ~count=dict->getString("frequency", "")->Int.fromString->Option.getOr(5),
    ~returnUrl=dict->getString("return_url_with_query_params", ""),
    ~logger=ctx.logger,
    ~sdkAuthorization=ctx.sdkAuthorization,
  )
  ->then(_ => {
    EventListenerManager.removeSmartEventListener("message", listenerKey)
    retrieveForceSync(ctx)
  })
  ->catch(err => {
    EventListenerManager.removeSmartEventListener("message", listenerKey)
    reject(err)
  })
}

let finish = (~completion: FullscreenHost.completion, ~redirect, ~returnUrl, ~ctx) => {
  let resolveIntent = intent => intent->resolveIntent(~ctx, ~redirect, ~returnUrl)->resolve
  let onError = err => serverError(err->formatException->JSON.stringify)->resolve
  switch completion {
  | PollStatus(pollStatus) =>
    pollThenRetrieve(pollStatus, ~ctx)->then(resolveIntent)->catch(onError)
  | OpenUrlIfRequired(_) => retrieveForceSync(ctx)->then(resolveIntent)->catch(onError)
  | Submitted(data) => resolveIntent(data)
  | SubmitFailed(error) => error->resolve
  | OpenUrl(url) =>
    replaceRootHref(url, ctx.redirectionFlags)
    JSON.Encode.null->resolve
  }
}
