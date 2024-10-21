open PazeTypes

@val @scope("window")
external digitalWalletSdk: digitalWalletSdk = "DIGITAL_WALLET_SDK"

@react.component
let make = () => {
  open Promise
  open Utils

  let (clientId, setClientId) = React.useState(() => "")
  let (clientName, setClientName) = React.useState(() => "")
  let (clientProfileId, setClientProfileId) = React.useState(() => "")
  let (sessionId, setSessionId) = React.useState(() => "")
  let (currency, setCurrency) = React.useState(() => "")
  let (publishableKey, setPublishableKey) = React.useState(() => "")

  React.useEffect0(() => {
    let handle = (ev: Window.event) => {
      let json = ev.data->safeParse
      let metaData = json->getDictFromJson->getDictFromDict("metadata")
      if metaData->getString("wallet", "") === "Paze" {
        setClientId(_ => metaData->getString("clientId", ""))
        setClientName(_ => metaData->getString("clientName", ""))
        setClientProfileId(_ => metaData->getString("clientProfileId", ""))
        setSessionId(_ => metaData->getString("sessionId", ""))
        setCurrency(_ => metaData->getString("currency", ""))
        setPublishableKey(_ => metaData->getString("publishableKey", ""))
      }
    }
    Window.addEventListener("message", handle)
    messageParentWindow([("iframeMountedCallback", true->JSON.Encode.bool)])
    Some(() => {Window.removeEventListener("message", handle)})
  })

  let mountPazeSDK = () => {
    let pazeScriptURL =
      publishableKey->String.startsWith("pk_snd")
        ? `https://sandbox.digitalwallet.earlywarning.com/web/resources/js/digitalwallet-sdk.js`
        : `https://checkout.paze.com/web/resources/js/digitalwallet-sdk.js`

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
            transactionAmount: "50.21",
            transactionCurrencyCode: currency,
          }

          let transactionOptions = {
            billingPreference: "ALL",
            merchantCategoryCode: "US",
            payloadTypeIndicator: "PAYMENT",
          }

          digitalWalletSdk.checkout({
            acceptedPaymentCardNetworks: ["VISA", "MASTERCARD"],
            emailAddress: "returninguser@paze.com",
            sessionId: "m2cxrizr6scgriug1pg",
            actionCode: "START_FLOW",
            transactionValue,
            shippingPreference: "ALL",
          })
          ->then(
            checkoutResponse => {
              Console.log2("PAZE --- Checkout Response Object: ", checkoutResponse)
              let completeObj = {
                transactionOptions,
                transactionId: "",
                sessionId: "m2cxrizr6scgriug1pg",
                transactionType: "PURCHASE",
                transactionValue,
              }
              digitalWalletSdk.complete(completeObj)->then(
                completeResponse => {
                  Console.log2("PAZE --- Complete Response Object: ", completeResponse)
                  resolve()
                },
              )
            },
          )
          ->finally(
            _ =>
              messageParentWindow([
                ("fullscreen", false->JSON.Encode.bool),
                ("isPaze", true->JSON.Encode.bool),
                ("publicToken", "shdchdbdc"->JSON.Encode.string),
              ]),
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
    if (
      clientId != "" &&
      clientName != "" &&
      clientProfileId != "" &&
      // sessionId != "" &&
      currency != ""
    ) {
      mountPazeSDK()
    }
    None
  }, [clientId, clientName, clientProfileId, sessionId, currency])

  <div id="paze-button" className="w-full flex flex-row justify-center rounded-md h-auto" />
}
