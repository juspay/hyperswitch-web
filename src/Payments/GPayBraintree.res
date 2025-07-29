open GpayBraintreeTypes
open GpayBraintreeHelpers

let braintreeToken = "eyJ2ZXJzaW9uIjoyLCJhdXRob3JpemF0aW9uRmluZ2VycHJpbnQiOiJleUowZVhBaU9pSktWMVFpTENKaGJHY2lPaUpGVXpJMU5pSXNJbXRwWkNJNklqSXdNVGd3TkRJMk1UWXRjMkZ1WkdKdmVDSXNJbWx6Y3lJNkltaDBkSEJ6T2k4dllYQnBMbk5oYm1SaWIzZ3VZbkpoYVc1MGNtVmxaMkYwWlhkaGVTNWpiMjBpZlEuZXlKbGVIQWlPakUzTlRNNE1qWTJPRGtzSW1wMGFTSTZJamc1TmpVME1qTTVMV0ZqWVRndE5HWXlNeTA1T0RBd0xXSTFZalkxT0dVek56STNaaUlzSW5OMVlpSTZJbWR6Wm5BMmJubG5lVE5rZW1JNGMyc2lMQ0pwYzNNaU9pSm9kSFJ3Y3pvdkwyRndhUzV6WVc1a1ltOTRMbUp5WVdsdWRISmxaV2RoZEdWM1lYa3VZMjl0SWl3aWJXVnlZMmhoYm5RaU9uc2ljSFZpYkdsalgybGtJam9pWjNObWNEWnVlV2Q1TTJSNllqaHpheUlzSW5abGNtbG1lVjlqWVhKa1gySjVYMlJsWm1GMWJIUWlPbVpoYkhObExDSjJaWEpwWm5sZmQyRnNiR1YwWDJKNVgyUmxabUYxYkhRaU9tWmhiSE5sZlN3aWNtbG5hSFJ6SWpwYkltMWhibUZuWlY5MllYVnNkQ0pkTENKelkyOXdaU0k2V3lKQ2NtRnBiblJ5WldVNlZtRjFiSFFpTENKQ2NtRnBiblJ5WldVNlFWaFBJbDBzSW05d2RHbHZibk1pT250OWZRLlRlaG91Vjd1MFVtQm84bzU3aVV1RHJQU3BYQ2VxNnZ3eS1hM0RrWUQyQm9oeWVSRkszQ1otdF9mdHZEbjduUWRMcnlJZzlpMVg2NUpGM3NaMWVPR0h3IiwiY29uZmlnVXJsIjoiaHR0cHM6Ly9hcGkuc2FuZGJveC5icmFpbnRyZWVnYXRld2F5LmNvbTo0NDMvbWVyY2hhbnRzL2dzZnA2bnlneTNkemI4c2svY2xpZW50X2FwaS92MS9jb25maWd1cmF0aW9uIiwiZ3JhcGhRTCI6eyJ1cmwiOiJodHRwczovL3BheW1lbnRzLnNhbmRib3guYnJhaW50cmVlLWFwaS5jb20vZ3JhcGhxbCIsImRhdGUiOiIyMDE4LTA1LTA4IiwiZmVhdHVyZXMiOlsidG9rZW5pemVfY3JlZGl0X2NhcmRzIl19LCJjbGllbnRBcGlVcmwiOiJodHRwczovL2FwaS5zYW5kYm94LmJyYWludHJlZWdhdGV3YXkuY29tOjQ0My9tZXJjaGFudHMvZ3NmcDZueWd5M2R6Yjhzay9jbGllbnRfYXBpIiwiZW52aXJvbm1lbnQiOiJzYW5kYm94IiwibWVyY2hhbnRJZCI6ImdzZnA2bnlneTNkemI4c2siLCJhc3NldHNVcmwiOiJodHRwczovL2Fzc2V0cy5icmFpbnRyZWVnYXRld2F5LmNvbSIsImF1dGhVcmwiOiJodHRwczovL2F1dGgudmVubW8uc2FuZGJveC5icmFpbnRyZWVnYXRld2F5LmNvbSIsInZlbm1vIjoib2ZmIiwiY2hhbGxlbmdlcyI6W10sInRocmVlRFNlY3VyZUVuYWJsZWQiOnRydWUsImFuYWx5dGljcyI6eyJ1cmwiOiJodHRwczovL29yaWdpbi1hbmFseXRpY3Mtc2FuZC5zYW5kYm94LmJyYWludHJlZS1hcGkuY29tL2dzZnA2bnlneTNkemI4c2sifSwiYXBwbGVQYXkiOnsiY291bnRyeUNvZGUiOiJVUyIsImN1cnJlbmN5Q29kZSI6IlVTRCIsIm1lcmNoYW50SWRlbnRpZmllciI6Im1lcmNoYW50LmNvbS5hZHllbi5zYW4iLCJzdGF0dXMiOiJtb2NrIiwic3VwcG9ydGVkTmV0d29ya3MiOlsidmlzYSIsIm1hc3RlcmNhcmQiLCJhbWV4IiwiZGlzY292ZXIiXX0sInBheXBhbEVuYWJsZWQiOnRydWUsInBheXBhbCI6eyJiaWxsaW5nQWdyZWVtZW50c0VuYWJsZWQiOnRydWUsImVudmlyb25tZW50Tm9OZXR3b3JrIjpmYWxzZSwidW52ZXR0ZWRNZXJjaGFudCI6ZmFsc2UsImFsbG93SHR0cCI6dHJ1ZSwiZGlzcGxheU5hbWUiOiJKdXNwYXkiLCJjbGllbnRJZCI6IkFTS0FHaDJXWGdxZlE1VHpqcFp6THNmaFZHbEZianE1VnJWNUlPWDhLWEREMk5fWHFrR2VZTkRrV3lyX1VYbmZoWHBFa0FCZG1QMjg0Yl8yIiwiYmFzZVVybCI6Imh0dHBzOi8vYXNzZXRzLmJyYWludHJlZWdhdGV3YXkuY29tIiwiYXNzZXRzVXJsIjoiaHR0cHM6Ly9jaGVja291dC5wYXlwYWwuY29tIiwiZGlyZWN0QmFzZVVybCI6bnVsbCwiZW52aXJvbm1lbnQiOiJvZmZsaW5lIiwiYnJhaW50cmVlQ2xpZW50SWQiOiJtYXN0ZXJjbGllbnQzIiwibWVyY2hhbnRBY2NvdW50SWQiOiJqdXNwYXkiLCJjdXJyZW5jeUlzb0NvZGUiOiJVU0QifX0"

@react.component
let make = (~sessionObj: option<SessionsType.token>) => {
  let sessionToken = sessionObj->Option.getOr(SessionsType.defaultToken)
  let braintreeClientLoadStatus = CommonHooks.useScript(braintreeClientUrl)
  let braintreeGPayScriptLoadStatus = CommonHooks.useScript(braintreeGPayUrl)
  let gPayScriptLoadStatus = CommonHooks.useScript(googlePayUrl)
  let isGPayReady = Recoil.useRecoilValueFromAtom(RecoilAtoms.isGooglePayReady)

  let loggerState = Recoil.useRecoilValueFromAtom(RecoilAtoms.loggerAtom)
  let intent = PaymentHelpers.usePaymentIntent(Some(loggerState), Gpay)
  let options = Recoil.useRecoilValueFromAtom(RecoilAtoms.optionAtom)
  let {publishableKey} = Recoil.useRecoilValueFromAtom(RecoilAtoms.keys)
  let isManualRetryEnabled = Recoil.useRecoilValueFromAtom(RecoilAtoms.isManualRetryEnabled)
  let {iframeId} = Recoil.useRecoilValueFromAtom(RecoilAtoms.keys)

  let gPayInstanceRef = React.useRef(Nullable.null)
  let paymentClientRef = React.useRef(Nullable.null)

  let handleGPayButtonClick = async () => {
    switch gPayInstanceRef.current->Nullable.toOption {
    | Some(gPayInstance) => {
        let request = gPayInstance.createPaymentDataRequest(createGpayTransactionInfo(sessionToken))
        switch paymentClientRef.current->Nullable.toOption {
        | Some(paymentClient) =>
          try {
            Utils.messageParentWindow([
              ("fullscreen", true->JSON.Encode.bool),
              ("param", "paymentloader"->JSON.Encode.string),
              ("iframeId", iframeId->JSON.Encode.string),
            ])
            let paymentData = await paymentClient.loadPaymentData(request)
            let payload = await gPayInstance.parseResponse(paymentData)
            let payloadDict = payload->Utils.getDictFromJson
            let payObj = createPayObj(payloadDict)
            let connectors = ["braintree"]
            let body = PaymentBody.gpayBody(~payObj, ~connectors)
            intent(
              ~bodyArr=body,
              ~confirmParam={
                return_url: options.wallets.walletReturnUrl,
                publishableKey,
              },
              ~handleUserError=true,
              ~isThirdPartyFlow=true,
              ~manualRetry=isManualRetryEnabled,
            )
          } catch {
          | _ => Utils.messageParentWindow([("fullscreen", false->JSON.Encode.bool)])
          }
        | None => Console.error("Payment client is not initialized.")
        }
      }
    | None => Console.error("Google Pay instance is not initialized.")
    }
  }

  React.useEffect(() => {
    let areRequiredScriptsLoaded =
      braintreeClientLoadStatus == "ready" &&
      braintreeGPayScriptLoadStatus == "ready" &&
      gPayScriptLoadStatus == "ready"

    Console.log3(braintreeClientLoadStatus, braintreeGPayScriptLoadStatus, gPayScriptLoadStatus)

    if areRequiredScriptsLoaded {
      braintreeClientCreate({authorization: braintreeToken}, (err, clientInstance) => {
        if !err {
          braintreeGPayPaymentCreate(
            clientInstance->createGooglePayConfig,
            (err, gPayInstance) => {
              if !err {
                gPayInstanceRef.current = Nullable.make(gPayInstance)
                paymentClientRef.current = Nullable.make(
                  newGPayPaymentClient({environment: environment}),
                )

                switch paymentClientRef.current->Nullable.toOption {
                | Some(client) => {
                    let button = client.createButton({
                      onClick: handleGPayButtonClick,
                      buttonSizeMode,
                      // buttonType,
                    })
                    let buttonMountPoint =
                      Window.window->Window.document->Window.getElementById("google-pay-button")

                    switch buttonMountPoint->Nullable.toOption {
                    | Some(mountPoint) => mountPoint->appendChildElement(button)
                    | None => Console.error("Mount point for Google Pay button not found.")
                    }
                  }
                | None => Console.error("Payment client is not initialized.")
                }
              } else {
                Console.error("Failed to create Google Pay instance.")
              }
            },
          )
        } else {
          Console.error("Failed to create Braintree client instance.")
        }
      })
    }
    None
  }, (braintreeClientLoadStatus, braintreeGPayScriptLoadStatus, gPayScriptLoadStatus, isGPayReady))

  <div className="w-full">
    <div id="google-pay-button" />
  </div>
}

let default = make
