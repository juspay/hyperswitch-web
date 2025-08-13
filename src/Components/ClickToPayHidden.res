open Utils

@react.component
let make = () => {
  let logger = HyperLogger.make(~source=Elements(Payment))

  Console.log("===> ClickToPayHidden component mounted")

  let handlePostAuthentication = async (
    clickToPayBody,
    ~publishableKey,
    ~clientSecret,
    ~customPodUri,
    ~authenticationId,
    ~profileId,
    ~endpoint,
  ) => {
    try {
      let data = await PaymentHelpersV2.fetchPostAuthentication(
        ~publishableKey,
        ~logger,
        ~customPodUri,
        ~authenticationClientSecret=clientSecret->Option.getOr(""),
        ~authenticationId,
        ~profileId,
        ~endpoint,
        ~bodyArr=clickToPayBody,
      )

      Console.log2("===> Data", data)

      messageParentWindow([("authenticationSuccessful", true->JSON.Encode.bool), ("data", data)])
    } catch {
    | err => Console.log2("===> Error in post authentication", err)
    }
  }

  React.useEffect0(() => {
    let handle = (ev: Window.event) => {
      let json = ev.data->safeParse
      let dict = json->getDictFromJson

      Console.log2("===> ClickToPayHidden received message", ev)
      Console.log2("===> ClickToPayHidden received message Ev Data", ev.data)
      Console.log2("===> ClickToPayHidden received message JSON", json)
      Console.log2("===> ClickToPayHidden received message dict", dict)
      Console.log2(
        "===> ClickToPayHidden is handleClickToPayauthenticationComplete Present",
        dict->Dict.get("handleClickToPayAuthenticationComplete")->Option.isSome,
      )

      if dict->Dict.get("fullScreenIframeMounted")->Option.isSome {
        Console.log("===> ClickToPayHidden component mounted")
      } else if dict->Dict.get("doAuthentication")->Option.isSome {
        messageParentWindow([("handleClickToPayAuthentication", true->JSON.Encode.bool)])
      } else if dict->Dict.get("handleClickToPayAuthenticationComplete")->Option.isSome {
        let payload = dict->Utils.getDictFromDict("payload")
        let email = dict->Utils.getString("email", "")
        let clickToPayProvider =
          dict->Utils.getString("clickToPayProvider", "")->ClickToPayHelpers.getCtpProvider

        let publishableKey = dict->Utils.getString("publishableKey", "")
        let customPodUri = dict->Utils.getString("customPodUri", "")
        let clientSecret = dict->Utils.getOptionString("clientSecret")

        let authenticationId = dict->Utils.getString("authenticationId", "")
        let profileId = dict->Utils.getString("profileId", "")
        let endpoint = dict->Utils.getString("endpoint", "")

        Console.log2("===> ClickToPayProvider", clickToPayProvider)

        switch clickToPayProvider {
        | MASTERCARD => {
            let headers = dict->Utils.getDictFromDict("headers")
            let merchantTransactionId = headers->Utils.getString("merchant-transaction-id", "")
            let xSrcFlowId = headers->Utils.getString("x-src-cx-flow-id", "")
            let correlationId =
              dict
              ->Utils.getDictFromDict("checkoutResponseData")
              ->Utils.getString("srcCorrelationId", "")

            let clickToPayBody = PaymentBody.mastercardClickToPayBody(
              ~merchantTransactionId,
              ~correlationId,
              ~xSrcFlowId,
            )
            // intent(
            //   ~bodyArr=clickToPayBody->mergeAndFlattenToTuples(requiredFieldsBody),
            //   ~confirmParam=confirm.confirmParams,
            //   ~handleUserError=false,
            //   ~manualRetry=isManualRetryEnabled,
            // )
          }
        | VISA => {
            let clickToPayBody = PaymentBodyV2.visaClickToPayBodyV2(
              ~encryptedPayload=payload->Utils.getString("checkoutResponse", ""),
            )

            Console.log2("===> ClickToPayBody", clickToPayBody)

            handlePostAuthentication(
              clickToPayBody,
              ~publishableKey,
              ~clientSecret,
              ~customPodUri,
              ~authenticationId,
              ~profileId,
              ~endpoint,
            )->ignore
            // intent(
            //   ~bodyArr=clickToPayBody,
            //   ~confirmParam=confirm.confirmParams,
            //   ~handleUserError=false,
            //   ~manualRetry=isManualRetryEnabled,
            // )
          }
        | NONE => ()
        }
      }
    }
    Window.addEventListener("message", handle)
    // messageParentWindow([("iframeMountedCallback", true->JSON.Encode.bool)])
    Some(() => {Window.removeEventListener("message", handle)})
  })

  <> </>
}
