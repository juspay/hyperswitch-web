open GpayBraintreeTypes
open GpayBraintreeHelpers

let braintreeToken = "eyJ2ZXJzaW9uIjoyLCJhdXRob3JpemF0aW9uRmluZ2VycHJpbnQiOiJleUowZVhBaU9pSktWMVFpTENKaGJHY2lPaUpGVXpJMU5pSXNJbXRwWkNJNklqSXdNVGd3TkRJMk1UWXRjMkZ1WkdKdmVDSXNJbWx6Y3lJNkltaDBkSEJ6T2k4dllYQnBMbk5oYm1SaWIzZ3VZbkpoYVc1MGNtVmxaMkYwWlhkaGVTNWpiMjBpZlEuZXlKbGVIQWlPakUzTlRNNE9UYzVOakFzSW1wMGFTSTZJamMzWlRSa04ySmhMV014TnpndE5HWmxNeTFpWXpFM0xUY3pOVEZsWVdVeE5EQTBOU0lzSW5OMVlpSTZJbWR6Wm5BMmJubG5lVE5rZW1JNGMyc2lMQ0pwYzNNaU9pSm9kSFJ3Y3pvdkwyRndhUzV6WVc1a1ltOTRMbUp5WVdsdWRISmxaV2RoZEdWM1lYa3VZMjl0SWl3aWJXVnlZMmhoYm5RaU9uc2ljSFZpYkdsalgybGtJam9pWjNObWNEWnVlV2Q1TTJSNllqaHpheUlzSW5abGNtbG1lVjlqWVhKa1gySjVYMlJsWm1GMWJIUWlPbVpoYkhObExDSjJaWEpwWm5sZmQyRnNiR1YwWDJKNVgyUmxabUYxYkhRaU9tWmhiSE5sZlN3aWNtbG5hSFJ6SWpwYkltMWhibUZuWlY5MllYVnNkQ0pkTENKelkyOXdaU0k2V3lKQ2NtRnBiblJ5WldVNlZtRjFiSFFpTENKQ2NtRnBiblJ5WldVNlFWaFBJbDBzSW05d2RHbHZibk1pT250OWZRLmoteGwtTjFEdi1sVFJQTUV3SjhpYjROdGlzcXRIeXVwMXZGTy1KNjk4RVZLcGNsTUpJYkdOaXpuMVZrNDFCa3FpRmpvczN4MGM2NV9XZHdGb2hIWXhRIiwiY29uZmlnVXJsIjoiaHR0cHM6Ly9hcGkuc2FuZGJveC5icmFpbnRyZWVnYXRld2F5LmNvbTo0NDMvbWVyY2hhbnRzL2dzZnA2bnlneTNkemI4c2svY2xpZW50X2FwaS92MS9jb25maWd1cmF0aW9uIiwiZ3JhcGhRTCI6eyJ1cmwiOiJodHRwczovL3BheW1lbnRzLnNhbmRib3guYnJhaW50cmVlLWFwaS5jb20vZ3JhcGhxbCIsImRhdGUiOiIyMDE4LTA1LTA4IiwiZmVhdHVyZXMiOlsidG9rZW5pemVfY3JlZGl0X2NhcmRzIl19LCJjbGllbnRBcGlVcmwiOiJodHRwczovL2FwaS5zYW5kYm94LmJyYWludHJlZWdhdGV3YXkuY29tOjQ0My9tZXJjaGFudHMvZ3NmcDZueWd5M2R6Yjhzay9jbGllbnRfYXBpIiwiZW52aXJvbm1lbnQiOiJzYW5kYm94IiwibWVyY2hhbnRJZCI6ImdzZnA2bnlneTNkemI4c2siLCJhc3NldHNVcmwiOiJodHRwczovL2Fzc2V0cy5icmFpbnRyZWVnYXRld2F5LmNvbSIsImF1dGhVcmwiOiJodHRwczovL2F1dGgudmVubW8uc2FuZGJveC5icmFpbnRyZWVnYXRld2F5LmNvbSIsInZlbm1vIjoib2ZmIiwiY2hhbGxlbmdlcyI6W10sInRocmVlRFNlY3VyZUVuYWJsZWQiOnRydWUsImFuYWx5dGljcyI6eyJ1cmwiOiJodHRwczovL29yaWdpbi1hbmFseXRpY3Mtc2FuZC5zYW5kYm94LmJyYWludHJlZS1hcGkuY29tL2dzZnA2bnlneTNkemI4c2sifSwiYXBwbGVQYXkiOnsiY291bnRyeUNvZGUiOiJVUyIsImN1cnJlbmN5Q29kZSI6IlVTRCIsIm1lcmNoYW50SWRlbnRpZmllciI6Im1lcmNoYW50LmNvbS5hZHllbi5zYW4iLCJzdGF0dXMiOiJtb2NrIiwic3VwcG9ydGVkTmV0d29ya3MiOlsidmlzYSIsIm1hc3RlcmNhcmQiLCJhbWV4IiwiZGlzY292ZXIiXX0sInBheXBhbEVuYWJsZWQiOnRydWUsInBheXBhbCI6eyJiaWxsaW5nQWdyZWVtZW50c0VuYWJsZWQiOnRydWUsImVudmlyb25tZW50Tm9OZXR3b3JrIjpmYWxzZSwidW52ZXR0ZWRNZXJjaGFudCI6ZmFsc2UsImFsbG93SHR0cCI6dHJ1ZSwiZGlzcGxheU5hbWUiOiJKdXNwYXkiLCJjbGllbnRJZCI6IkFTS0FHaDJXWGdxZlE1VHpqcFp6THNmaFZHbEZianE1VnJWNUlPWDhLWEREMk5fWHFrR2VZTkRrV3lyX1VYbmZoWHBFa0FCZG1QMjg0Yl8yIiwiYmFzZVVybCI6Imh0dHBzOi8vYXNzZXRzLmJyYWludHJlZWdhdGV3YXkuY29tIiwiYXNzZXRzVXJsIjoiaHR0cHM6Ly9jaGVja291dC5wYXlwYWwuY29tIiwiZGlyZWN0QmFzZVVybCI6bnVsbCwiZW52aXJvbm1lbnQiOiJvZmZsaW5lIiwiYnJhaW50cmVlQ2xpZW50SWQiOiJtYXN0ZXJjbGllbnQzIiwibWVyY2hhbnRBY2NvdW50SWQiOiJqdXNwYXkiLCJjdXJyZW5jeUlzb0NvZGUiOiJVU0QifX0"

@react.component
let make = (~sessionObj: JSON.t) => {
  let braintreeClientLoadStatus = CommonHooks.useScript(braintreeClientUrl)
  let braintreeApplePayScriptLoadStatus = CommonHooks.useScript(braintreeApplePayUrl)

  let loggerState = Recoil.useRecoilValueFromAtom(RecoilAtoms.loggerAtom)
  let intent = PaymentHelpers.usePaymentIntent(Some(loggerState), Gpay)
  let options = Recoil.useRecoilValueFromAtom(RecoilAtoms.optionAtom)
  let {publishableKey} = Recoil.useRecoilValueFromAtom(RecoilAtoms.keys)
  let isManualRetryEnabled = Recoil.useRecoilValueFromAtom(RecoilAtoms.isManualRetryEnabled)
  let {iframeId} = Recoil.useRecoilValueFromAtom(RecoilAtoms.keys)

  let applePayInstanceRef = React.useRef(Nullable.null)

  let handleApplePayButtonClick = _ =>
    if (
      !(applePayInstanceRef.current->Nullable.isNullable) &&
      !(braintreeApplePaySession->Nullable.isNullable)
    ) {
      switch applePayInstanceRef.current->Nullable.toOption {
      | Some(applePayInstance) =>
        let paymentRequest =
          sessionObj->createApplePayTransactionInfo->applePayInstance.createPaymentRequest
        let sessions = newApplePaySession(3, paymentRequest)
        sessions.onvalidatemerchant = event => {
          applePayInstance.performValidation(
            {
              {
                "validationURL": event
                ->Utils.getDictFromJson
                ->Utils.getString("validationURL", ""),
                "displayName": "My Store",
              }->Identity.anyTypeToJson
            },
            (err, merchantSession) => {
              if !err {
                sessions.completeMerchantValidation(merchantSession)
              } else {
                Console.log("Failed to validate merchant session.")
                sessions.abort()
              }
            },
          )
        }
        sessions.onpaymentauthorized = event => {
          applePayInstance.tokenize(
            {
              "token": event
              ->Utils.getDictFromJson
              ->Utils.getDictFromDict("payment")
              ->Utils.getString("token", ""),
            }->Identity.anyTypeToJson,
            (err, payload) => {
              if !err {
                sessions.completePayment(applePaySession.\"STATUS_SUCCESS")
                let nonce = payload->Utils.getDictFromJson->Utils.getString("nonce", "")
                Console.log2("Apple Pay nonce received:", nonce)
                //
                //
                //
                // INTENT CALL
                //
                //
                //
              } else {
                sessions.completePayment(applePaySession.\"STATUS_FAILURE")
              }
            },
          )
        }
        sessions.oncancel = _ => {
          Console.log("Apple Pay payment was cancelled.")
        }
        sessions.begin()
      | None => Console.error("Apple Pay instance is not available")
      }
    } else {
      Console.log("apple pay not working")
    }

  React.useEffect(() => {
    let areRequiredScriptsLoaded =
      braintreeClientLoadStatus == "ready" && braintreeApplePayScriptLoadStatus == "ready"

    Console.log2(braintreeClientLoadStatus, braintreeApplePayScriptLoadStatus)

    if areRequiredScriptsLoaded {
      braintreeClientCreate({authorization: braintreeToken}, (err, clientInstance) => {
        if !err {
          braintreeApplePayPaymentCreate(
            clientInstance->createApplePayConfig,
            (err, applePayInstance) => {
              if !err {
                applePayInstanceRef.current = Nullable.make(applePayInstance)
                Console.log("Apple Pay instance created successfully.")
              } else {
                Console.error("Failed to create Apple Pay instance.")
              }
            },
          )
        } else {
          Console.error("Failed to create Braintree client instance.")
        }
      })
    }
    None
  }, (braintreeClientLoadStatus, braintreeApplePayScriptLoadStatus))

  <div className="w-full">
    <button
      id="apple-pay-button"
      className="w-full p-2 flex justify-center items-center border-2 border-black"
      onClick=handleApplePayButtonClick>
      {"Apple Pay"->React.string}
    </button>
  </div>
}

let default = make
