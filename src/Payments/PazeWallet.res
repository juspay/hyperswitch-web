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
  let (publishableKey, setPublishableKey) = React.useState(() => "")
  let (emailAddress, setEmailAddress) = React.useState(() => "")
  let (transactionAmount, setTransactionAmount) = React.useState(() => "")
  let (transactionCurrencyCode, setTransactionCurrencyCode) = React.useState(() => "")

  React.useEffect0(() => {
    let handle = (ev: Window.event) => {
      let json = ev.data->safeParse
      let metaData = json->getDictFromJson->getDictFromDict("metadata")
      if metaData->getString("wallet", "") === "Paze" {
        setClientId(_ => metaData->getString("clientId", ""))
        setClientName(_ => metaData->getString("clientName", ""))
        setClientProfileId(_ => metaData->getString("clientProfileId", ""))
        setSessionId(_ => metaData->getString("sessionId", ""))
        setPublishableKey(_ => metaData->getString("publishableKey", ""))
        setEmailAddress(_ => metaData->getString("emailAddress", ""))
        setTransactionAmount(_ => metaData->getString("transactionAmount", ""))
        setTransactionCurrencyCode(_ => metaData->getString("transactionCurrencyCode", ""))
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
      })
      ->then(val => {
        Console.log2("PAZE --- init completed", val)
        digitalWalletSdk.canCheckout({
          emailAddress: emailAddress,
        })->then(consumerPresent => {
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

          digitalWalletSdk.checkout({
            acceptedPaymentCardNetworks: ["VISA", "MASTERCARD"],
            emailAddress,
            sessionId,
            actionCode: "START_FLOW",
            transactionValue,
            shippingPreference: "ALL",
          })->then(
            checkoutResponse => {
              Console.log2("PAZE --- Checkout Response Object: ", checkoutResponse)
              let completeObj = {
                transactionOptions,
                transactionId: "",
                sessionId,
                transactionType: "PURCHASE",
                transactionValue,
              }
              digitalWalletSdk.complete(completeObj)->then(
                completeResponse => {
                  Console.log2("PAZE --- Complete Response Object: ", completeResponse)
                  messageParentWindow([
                    ("fullscreen", false->JSON.Encode.bool),
                    ("isPaze", true->JSON.Encode.bool),
                    (
                      "completeResponse",
                      completeResponse
                      ->getDictFromJson
                      ->getString("completeResponse", "")
                      ->JSON.Encode.string,
                    ),
                  ])
                  resolve()
                },
              )
            },
          )
        })
      })
      ->catch(_ => {
        messageParentWindow([
          ("fullscreen", false->JSON.Encode.bool),
          ("isPaze", true->JSON.Encode.bool),
          ("flowExited", "stop"->JSON.Encode.string),
        ])
        resolve()
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
      sessionId != "" &&
      transactionCurrencyCode != ""
    ) {
      mountPazeSDK()
    }
    None
  }, [clientId, clientName, clientProfileId, sessionId, transactionCurrencyCode])

  <div id="paze-button" className="w-full flex flex-row justify-center rounded-md h-auto" />
}
