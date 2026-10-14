open Utils
open HeadlessConfirmTypes

@get_index external frameByName: ({..}, string) => Nullable.t<Dom.element> = ""

let postResult = (~fallback, data) =>
  messageParentWindow([(resultKey, data), ("fallback", fallback->JSON.Encode.bool)])

let readWidgetCvc = frameName =>
  try {
    Window.parent
    ->Window.frames
    ->frameByName(frameName)
    ->Nullable.toOption
    ->Option.flatMap(frame => frame->Window.Element.document->Nullable.toOption)
    ->Option.flatMap(doc => doc->Window.getElementById("card-cvc")->Nullable.toOption)
    ->Option.map((input): string => input->Window.value)
  } catch {
  | _ => None
  }

let getCvcBody = cvcWidget =>
  switch cvcWidget {
  | None => Ok([])
  | Some({frameName, cardBrand}) =>
    switch readWidgetCvc(frameName) {
    | None =>
      Error((
        "cvc_widget_not_found",
        "No mounted CVC widget matches `cvcElementId`. Mount the CVC widget or pass `cvc`.",
      ))
    | Some("") => Error(("cvc_required", "Enter the CVC in the CVC widget."))
    | Some(cvc) if cvc->SavedPaymentMethodsUtils.isValidCvcForBrand(Some(cardBrand)) =>
      Ok([PaymentBody.cardTokenCvcTuple(~cvcNumber=cvc)])
    | Some(_) => Error(("cvc_validation", "The CVC entered in the CVC widget is invalid."))
    }
  }

let fetchApiReportingUnhandledStatus = (
  uri,
  ~bodyStr="",
  ~headers=Dict.make(),
  ~method,
  ~customPodUri=None,
  ~publishableKey=None,
  ~sdkAuthorization=None,
  ~signal=?,
) => {
  open Promise
  fetchApi(
    uri,
    ~bodyStr,
    ~headers,
    ~method,
    ~customPodUri,
    ~publishableKey,
    ~sdkAuthorization,
    ~signal?,
  )->then(res => {
    if res->Fetch.Response.ok {
      res
      ->Fetch.Response.clone
      ->Fetch.Response.json
      ->then(json => {
        let intent = PaymentConfirmTypes.itemToObjMapper(json->getDictFromJson)
        if (
          intent.status === "requires_payment_method" &&
            intent.nextAction.type_ !== "invoke_sdk_client"
        ) {
          postResult(~fallback=true, json)
        }
        resolve()
      })
      ->catch(_ => resolve())
      ->ignore
    }
    resolve(res)
  })
}

let confirm = (~logger: HyperLoggerTypes.loggerMake, ~hostId, request) => {
  open Promise
  request.endpoint->Option.forEach(ApiEndpoint.setApiEndPoint)
  logger.setMerchantId(request.publishableKey)
  logger.setClientSecret(request.clientSecret)
  logger.setSdkAuthorization(request.sdkAuthorization->Option.getOr(""))

  switch request.cvcWidget->getCvcBody {
  | Error((errorType, message)) =>
    postResult(~fallback=false, handleFailureResponse(~message, ~errorType))
  | Ok(cvcBody) =>
    let paymentIntentId = getPaymentIdOrExtractFromSdkAuth(
      ~clientSecret=request.clientSecret,
      ~sdkAuthorization=request.sdkAuthorization,
    )
    let endpoint = ApiEndpoint.getApiEndPoint(
      ~publishableKey=request.publishableKey,
      ~isConfirmCall=true,
    )
    let headers = switch request.sdkAuthorization {
    | Some(sdkAuthorization) => [("Authorization", sdkAuthorization)]
    | None => [("api-key", request.publishableKey)]
    }
    let clientSecretBody = switch request.sdkAuthorization {
    | Some(_) => []
    | None => [("client_secret", request.clientSecret->JSON.Encode.string)]
    }
    let bodyStr =
      request.body
      ->Array.concatMany([
        cvcBody,
        BrowserSpec.broswerInfo(),
        clientSecretBody,
        [("return_url", request.returnUrl->JSON.Encode.string)],
        request.manualRetry ? [("retry_action", "manual_retry"->JSON.Encode.string)] : [],
      ])
      ->getJsonFromArrayOfJson
      ->JSON.stringify

    PaymentHelpers.intentCall(
      ~fetchApi=fetchApiReportingUnhandledStatus,
      ~uri=`${endpoint}/payments/${paymentIntentId}/confirm`,
      ~headers,
      ~bodyStr,
      ~confirmParam={
        return_url: request.returnUrl,
        publishableKey: request.publishableKey,
        redirect: request.redirect,
      },
      ~clientSecret=request.clientSecret,
      ~optLogger=Some(logger),
      ~handleUserError=false,
      ~paymentType=switch request.paymentType {
      | "apple_pay" => PaymentHelpersTypes.Applepay
      | "google_pay" => Gpay
      | _ => Card
      },
      ~iframeId=hostId,
      ~fetchMethod=#POST,
      ~setIsManualRetryEnabled=_ => (),
      ~customPodUri=request.customPodUri,
      ~sdkHandleOneClickConfirmPayment=false,
      ~counter=0,
      ~redirectionFlags=JotaiAtoms.defaultRedirectionFlags,
      ~sdkAuthorization=request.sdkAuthorization,
    )
    ->then(data => {
      postResult(~fallback=true, data)
      resolve()
    })
    ->catch(err => {
      postResult(
        ~fallback=false,
        handleFailureResponse(
          ~message=err->formatException->JSON.stringify,
          ~errorType="server_error",
        ),
      )
      resolve()
    })
    ->ignore
  }
}

@react.component
let make = () => {
  let logger = React.useMemo0(() => HyperLogger.make(~source=Headless))

  React.useEffect0(() => {
    let handle = (ev: Window.event) =>
      if ev.source === iframeParent {
        let dict = ev.data->safeParse->getDictFromJson
        switch dict->Dict.get(requestKey) {
        | Some(requestJson) =>
          confirm(~logger, ~hostId=dict->getString("hostId", ""), requestJson->requestFromJson)
        | None => ()
        }
      }
    Window.addEventListener("message", handle)
    messageParentWindow([(readyKey, true->JSON.Encode.bool)])
    Some(() => Window.removeEventListener("message", handle))
  })

  React.null
}
