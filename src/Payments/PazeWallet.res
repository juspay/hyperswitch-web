@val @scope("window")
external digitalWalletSdk: PazeTypes.digitalWalletSdk = "DIGITAL_WALLET_SDK"

@react.component
let make = () => {
  open Promise
  open Utils

  let (clientId, setClientId) = React.useState(() => "")
  let (clientName, setClientName) = React.useState(() => "")
  let (clientProfileId, setClientProfileId) = React.useState(() => "")

  React.useEffect0(() => {
    let handle = (ev: Window.event) => {
      let json = ev.data->safeParse
      let metaData = json->getDictFromJson->getDictFromDict("metadata")
      setClientId(_ => metaData->getString("clientId", ""))
      setClientName(_ => metaData->getString("clientName", ""))
      setClientProfileId(_ => metaData->getString("clientProfileId", ""))
    }
    Window.addEventListener("message", handle)
    messageParentWindow([("iframeMountedCallback", true->JSON.Encode.bool)])
    Some(() => {Window.removeEventListener("message", handle)})
  })

  Js.log2("PAZE --- clientId: ", clientId)
  Js.log2("PAZE --- clientName: ", clientName)
  Js.log2("PAZE --- clientProfileId: ", clientProfileId)

  let mountPazeSDK = () => {
    let pazeScriptURL = `https://sandbox.digitalwallet.earlywarning.com/web/resources/js/digitalwallet-sdk.js`

    let loadPazeSDK = _ => {
      digitalWalletSdk.initialize({
        client: {
          id: clientId,
          name: clientName,
          profileId: clientProfileId,
        },
      })->then(val => {
        Console.log2("PAZE --- init completed", val)
        digitalWalletSdk.canCheckout({
          emailAddress: "returninguser@paze.com",
        })->then(consumerPresent => {
          Console.log("PAZE --- canCheckout completed")
          Console.log2("PAZE --- consumerPresent: ", consumerPresent)
          let transactionValue = {
            "transactionAmount": "50.21",
            "transactionCurrencyCode": "USD",
          }->Identity.anyTypeToJson

          let transactionOptions = {
            "billingPreference": "ALL",
            "merchantCategoryCode": "US",
            "payloadTypeIndicator": "PAYMENT",
          }->Identity.anyTypeToJson

          digitalWalletSdk.checkout({
            acceptedPaymentCardNetworks: ["VISA", "MASTERCARD"],
            // emailAddress: "samraat.bansal@juspay.in",
            emailAddress: "returninguser@paze.com",
            sessionId: "m206xe0zacyslo1lsj",
            actionCode: "START_FLOW",
            transactionValue,
            shippingPreference: "ALL",
          })->then(
            checkoutResponse => {
              Console.log2("PAZE --- Checkout Response Object: ", checkoutResponse)
              digitalWalletSdk.complete({
                transactionOptions,
                transactionId: "",
                emailAddress: "returninguser@paze.com",
                sessionId: "m206xe0zacyslo1lsj",
                transactionType: "PURCHASE",
                transactionValue,
              })->then(
                completeResponse => {
                  Console.log2("PAZE --- Complete Response Object: ", completeResponse)
                  resolve()
                },
              )
            },
          )
        })
      })
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

  React.useEffect(() => {
    mountPazeSDK()
    None
  }, [])

  <div id="paze-button" className="w-full flex flex-row justify-center rounded-md h-auto" />
}
