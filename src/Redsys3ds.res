open Utils

@react.component
let make = () => {
  let logger = HyperLogger.make(~source=Elements(Payment))
  let isConfirmCalled = React.useRef(false)
  let eventsToSendToParent = ["confirmParams", "poll_status", "openurl_if_required"]
  let options = Recoil.useRecoilValueFromAtom(RecoilAtoms.optionAtom)
  let completeAuthorize = PaymentHelpers.useRedsysCompleteAuthorize(Some(logger))
  let handleConfirmCall = (threeDsMethodComp, paymentIntentId, publishableKey, headers) => {
    Console.log2("state", threeDsMethodComp)
    let body = [
      ("client_secret", paymentIntentId->JSON.Encode.string),
      ("threeds_method_comp_ind", threeDsMethodComp->JSON.Encode.string),
    ]
    completeAuthorize(
      ~bodyArr=body,
      ~confirmParam={
        return_url: options.wallets.walletReturnUrl,
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
        Console.log(ev.data)
        Console.log2("Redsys3ds", ev.data)
        let dict = json->getDictFromJson
        if dict->Dict.get("fullScreenIframeMounted")->Option.isSome {
          let metadata = dict->getJsonObjectFromDict("metadata")
          let metaDataDict = metadata->JSON.Decode.object->Option.getOr(Dict.make())
          let paymentIntentId = metaDataDict->getString("paymentIntentId", "")
          let publishableKey = metaDataDict->getString("publishableKey", "")
          logger.setClientSecret(paymentIntentId)
          logger.setMerchantId(publishableKey)
          let headersDict =
            metaDataDict
            ->getJsonObjectFromDict("headers")
            ->JSON.Decode.object
            ->Option.getOr(Dict.make())

          let headers =
            headersDict
            ->Dict.toArray
            ->Array.map(entries => {
              let (x, val) = entries
              (x, val->JSON.Decode.string->Option.getOr(""))
            })
          let iframeDataDict =
            metaDataDict
            ->Dict.get("iframeData")
            ->Option.flatMap(JSON.Decode.object)
            ->Option.getOr(Dict.make())
          let methodKey =
            iframeDataDict
            ->Dict.get("method_key")
            ->Option.flatMap(json => Js.Json.decodeString(json))
            ->Option.getOr("threeDSMethodData")

          let threeDsMethodUrl =
            iframeDataDict
            ->Dict.get("three_ds_method_url")
            ->Belt.Option.flatMap(json => Js.Json.decodeString(json))
            ->Option.getOr("")

          let threeDsMethodData =
            iframeDataDict
            ->Dict.get("three_ds_method_data")
            ->Belt.Option.flatMap(json => Js.Json.decodeString(json))
            ->Option.getOr("")

          let threeDsIframe = CommonHooks.querySelector("#threeDsAuthFrame")
          let threeDsDiv = Window.querySelector("#threeDsDiv")

          switch threeDsDiv->Nullable.toOption {
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
          let id = setTimeout(() => {
            isConfirmCalled.current = true
            handleConfirmCall("N", paymentIntentId, publishableKey, headers)->ignore
          }, 10000)

          switch threeDsIframe->Nullable.toOption {
          | Some(elem) =>
            elem->CommonHooks.addEventListener("load", _ => {
              clearTimeout(id)
              if !isConfirmCalled.current {
                handleConfirmCall("Y", paymentIntentId, publishableKey, headers)->ignore
              }
            })
          | None => ()
          }
        }
      } catch {
      | err => Console.log(err)
      }
    }
    Window.addEventListener("message", handle)
    Some(() => {Window.removeEventListener("message", handle)})
  })

  <div id="threeDsDiv" className="max-w-1 max-h-1 opacity-0 fixed left-[-9999px]">
    <iframe id="threeDsAuthFrame" name="threeDsAuthFrame" title="3D Secure Authentication Frame" />
  </div>
}
