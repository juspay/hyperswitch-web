open PazeTypes

@val @scope("window")
external digitalWalletSdk: digitalWalletSdk = "DIGITAL_WALLET_SDK"

@react.component
let make = () => {
  open Promise
  open Utils

  React.useEffect0(() => {
    let handle = (ev: Window.event) => {
      let json = ev.data->safeParse
      let metaData = json->getDictFromJson->getDictFromDict("metadata")
      if metaData->getString("wallet", "") === "Paze" {
        let clientId = metaData->getString("clientId", "")
        let clientName = metaData->getString("clientName", "")
        let clientProfileId = metaData->getString("clientProfileId", "")
        let sessionId = metaData->getString("sessionId", "")
        let publishableKey = metaData->getString("publishableKey", "")
        let emailAddress = metaData->getString("emailAddress", "")
        let transactionAmount = metaData->getString("transactionAmount", "")
        let transactionCurrencyCode = metaData->getString("transactionCurrencyCode", "")
        let componentName = metaData->getString("componentName", "")

        let mountPazeSDK = () => {
          let pazeScriptURL =
            publishableKey->String.startsWith("pk_snd")
              ? `https://sandbox.digitalwallet.earlywarning.com/web/resources/js/digitalwallet-sdk.js`
              : `https://checkout.paze.com/web/resources/js/digitalwallet-sdk.js`

          let loadPazeSDK = async _ => {
            try {
              let val = await digitalWalletSdk.initialize({
                client: {
                  id: clientId,
                  name: clientName,
                  profileId: clientProfileId,
                },
              })

              Console.log2("PAZE --- init completed", val)

              let consumerPresent = await digitalWalletSdk.canCheckout({
                emailAddress: emailAddress,
              })

              Console.log("PAZE --- canCheckout completed")
              Console.log2("PAZE --- consumerPresent: ", consumerPresent)

              let transactionValue = {
                transactionAmount,
                transactionCurrencyCode,
              }

              let transactionOptions = {
                billingPreference: "ALL",
                merchantCategoryCode: "US",
                payloadTypeIndicator: "PAYMENT",
              }

              let checkoutResponse = await digitalWalletSdk.checkout({
                acceptedPaymentCardNetworks: ["VISA", "MASTERCARD"],
                emailAddress,
                sessionId,
                actionCode: "START_FLOW",
                transactionValue,
                shippingPreference: "ALL",
              })

              Console.log2("PAZE --- Checkout Response Object: ", checkoutResponse)

              let completeObj = {
                transactionOptions,
                transactionId: "",
                sessionId,
                transactionType: "PURCHASE",
                transactionValue,
              }

              let completeResponse = await digitalWalletSdk.complete(completeObj)

              Console.log2("PAZE --- Complete Response Object: ", completeResponse)

              messageParentWindow([
                ("fullscreen", false->JSON.Encode.bool),
                ("isPaze", true->JSON.Encode.bool),
                ("componentName", componentName->JSON.Encode.string),
                (
                  "completeResponse",
                  completeResponse
                  ->getDictFromJson
                  ->getString("completeResponse", "")
                  ->JSON.Encode.string,
                ),
              ])

              resolve()
            } catch {
            | _ =>
              messageParentWindow([
                ("fullscreen", false->JSON.Encode.bool),
                ("isPaze", true->JSON.Encode.bool),
                ("flowExited", "stop"->JSON.Encode.string),
                ("componentName", componentName->JSON.Encode.string),
              ])
              resolve()
            }
          }

          let pazeScript = Window.createElement("script")
          pazeScript->Window.elementSrc(pazeScriptURL)
          pazeScript->Window.elementOnerror(exn => {
            let err = exn->Identity.anyTypeToJson->JSON.stringify
            Console.log2("PAZE --- errrorrr", err)
          })
          pazeScript->Window.elementOnload(_ => loadPazeSDK()->ignore)
          Window.body->Window.appendChild(pazeScript)
        }

        if (
          [
            clientId,
            clientName,
            clientProfileId,
            sessionId,
            transactionCurrencyCode,
          ]->Array.every(x => x != "")
        ) {
          mountPazeSDK()
        }
      }
    }
    Window.addEventListener("message", handle)
    messageParentWindow([("iframeMountedCallback", true->JSON.Encode.bool)])
    Some(() => {Window.removeEventListener("message", handle)})
  })

  <div id="paze-button" className="w-full flex flex-row justify-center rounded-md h-auto" />
}
