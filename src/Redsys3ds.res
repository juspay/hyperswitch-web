open Utils

@react.component
let make = () => {
  let logger = HyperLogger.make(~source=Elements(Payment))
  let isCompleteAuthorizeCalledRef = React.useRef(false)
  let timeoutRef = React.useRef(None)
  let eventsToSendToParent = ["confirmParams", "poll_status", "openurl_if_required"]
  let completeAuthorize = PaymentHelpers.useRedsysCompleteAuthorize(Some(logger))

  let handleCompleteAuthorizeCall = (
    threeDsMethodComp,
    paymentIntentId,
    publishableKey,
    headers,
    returnUrl,
  ) => {
    let body = [
      ("client_secret", paymentIntentId->JSON.Encode.string),
      ("threeds_method_comp_ind", threeDsMethodComp->JSON.Encode.string),
    ]
    completeAuthorize(
      ~bodyArr=body,
      ~confirmParam={
        return_url: returnUrl,
        publishableKey,
      },
      ~headers,
      ~iframeId="redsys3ds",
      ~clientSecret=Some(paymentIntentId),
    )
  }

  eventsToSendToParent->UtilityHooks.useSendEventsToParent

  React.useEffect0(() => {
    messageParentWindow([("iframeMountedCallback", true->JSON.Encode.bool)])
    let handle = (ev: Window.event) => {
      try {
        let json = ev.data->safeParse
        let dict = json->getDictFromJson
        if dict->Dict.get("fullScreenIframeMounted")->Option.isSome {
          let metadata = dict->getJsonObjectFromDict("metadata")
          let metaDataDict = metadata->JSON.Decode.object->Option.getOr(Dict.make())
          let paymentIntentId = metaDataDict->getString("paymentIntentId", "")
          let publishableKey = metaDataDict->getString("publishableKey", "")

          logger.setClientSecret(paymentIntentId)
          logger.setMerchantId(publishableKey)

          let headersDict = metaDataDict->getDictFromDict("headers")

          let headers = headersDict->convertDictToArrayOfKeyStringTuples

          let confirmParam = metaDataDict->getDictFromObj("confirmParams")
          let returnUrl = confirmParam->getString("return_url", "")
          let iframeDataDict = metaDataDict->getDictFromObj("iframeData")
          let methodKey = iframeDataDict->getString("method_key", "threeDSMethodData")
          let threeDsMethodUrl = iframeDataDict->getString("three_ds_method_url", "")
          let threeDsMethodData = iframeDataDict->getString("three_ds_method_data", "")
          let threeDsIframe = CommonHooks.querySelector("#threeDsAuthFrame")

          switch Window.querySelector("#threeDsDiv")->Nullable.toOption {
          | Some(elem) =>
            if threeDsMethodUrl !== "" {
              let form = elem->makeForm(threeDsMethodUrl, "threeDsHiddenPostMethod")
              let input = Types.createElement("input")
              input.name = encodeURIComponent(methodKey)
              input.value = encodeURIComponent(threeDsMethodData)
              form.target = "threeDsAuthFrame"
              form.appendChild(input)
              form.submit()
            }
          | None => ()
          }

          timeoutRef.current->Option.forEach(clearTimeout)

          timeoutRef.current = Some(setTimeout(() => {
              isCompleteAuthorizeCalledRef.current = true
              handleCompleteAuthorizeCall(
                "N",
                paymentIntentId,
                publishableKey,
                headers,
                returnUrl,
              )->ignore
            }, 10000))

          switch threeDsIframe->Nullable.toOption {
          | Some(elem) =>
            elem->CommonHooks.addEventListener("load", _ => {
              timeoutRef.current->Option.forEach(clearTimeout)
              if !isCompleteAuthorizeCalledRef.current {
                handleCompleteAuthorizeCall(
                  "Y",
                  paymentIntentId,
                  publishableKey,
                  headers,
                  returnUrl,
                )->ignore
              }
            })
          | None => ()
          }
        }
      } catch {
      | _ =>
        postFailedSubmitResponse(
          ~errortype="complete_authorize_failed",
          ~message="Something went wrong.",
        )
      }
    }
    Window.addEventListener("message", handle)
    Some(
      () => {
        Window.removeEventListener("message", handle)
        timeoutRef.current->Option.forEach(clearTimeout)
      },
    )
  })

  <div id="threeDsDiv" className="max-w-1 max-h-1 opacity-0 fixed left-[-9999px]">
    <iframe id="threeDsAuthFrame" name="threeDsAuthFrame" title="3D Secure Authentication Frame" />
  </div>
}
