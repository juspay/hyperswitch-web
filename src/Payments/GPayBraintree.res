type authorization = {authorization: string}
type environment = {environment: string}
type clientInstance = {}
type gPayInstance = {
  createPaymentDataRequest: JSON.t => JSON.t,
  parseResponse: JSON.t => promise<JSON.t>,
}
type createButtonConfig = {
  onClick: unit => promise<unit>,
  buttonSizeMode?: string,
  buttonType?: string,
}
type paymentClient = {
  createButton: createButtonConfig => Dom.element,
  loadPaymentData: JSON.t => promise<JSON.t>,
}
type clientCreateCallback = (bool, clientInstance) => unit
type paymentCreateCallback = (bool, gPayInstance) => unit

@val
external braintreeClientCreate: (authorization, clientCreateCallback) => unit =
  "braintree.client.create"
@val
external braintreeGPayPaymentCreate: (JSON.t, paymentCreateCallback) => unit =
  "braintree.googlePayment.create"
@new
external newGPayPaymentClient: environment => paymentClient = "google.payments.api.PaymentsClient"

// Add appendChild for Dom.element
@send external appendChildElement: (Dom.element, Dom.element) => unit = "appendChild"

let token = "eyJ2ZXJzaW9uIjoyLCJhdXRob3JpemF0aW9uRmluZ2VycHJpbnQiOiJleUowZVhBaU9pSktWMVFpTENKaGJHY2lPaUpGVXpJMU5pSXNJbXRwWkNJNklqSXdNVGd3TkRJMk1UWXRjMkZ1WkdKdmVDSXNJbWx6Y3lJNkltaDBkSEJ6T2k4dllYQnBMbk5oYm1SaWIzZ3VZbkpoYVc1MGNtVmxaMkYwWlhkaGVTNWpiMjBpZlEuZXlKbGVIQWlPakUzTlRNME1qRTBNelVzSW1wMGFTSTZJakl6WkdNek5EZGlMVFUyTW1VdE5EVTRPQzA1WXpjMkxXRXhNell5T0RWbE1HSTBaU0lzSW5OMVlpSTZJbWR6Wm5BMmJubG5lVE5rZW1JNGMyc2lMQ0pwYzNNaU9pSm9kSFJ3Y3pvdkwyRndhUzV6WVc1a1ltOTRMbUp5WVdsdWRISmxaV2RoZEdWM1lYa3VZMjl0SWl3aWJXVnlZMmhoYm5RaU9uc2ljSFZpYkdsalgybGtJam9pWjNObWNEWnVlV2Q1TTJSNllqaHpheUlzSW5abGNtbG1lVjlqWVhKa1gySjVYMlJsWm1GMWJIUWlPbVpoYkhObGZTd2ljbWxuYUhSeklqcGJJbTFoYm1GblpWOTJZWFZzZENKZExDSnpZMjl3WlNJNld5SkNjbUZwYm5SeVpXVTZWbUYxYkhRaUxDSkNjbUZwYm5SeVpXVTZRVmhQSWwwc0ltOXdkR2x2Ym5NaU9udDlmUS5XX1A1V0FzcDF5RjBiZVVQcWFlRHVkT1VNRmRfd0owakFkTm81dW04V3kxXzVNemZqRzJQQzZPYWFPV3hpcE93dTNXeFQ2NDdwRmhPQ1FjWi1BRXFrdyIsImNvbmZpZ1VybCI6Imh0dHBzOi8vYXBpLnNhbmRib3guYnJhaW50cmVlZ2F0ZXdheS5jb206NDQzL21lcmNoYW50cy9nc2ZwNm55Z3kzZHpiOHNrL2NsaWVudF9hcGkvdjEvY29uZmlndXJhdGlvbiIsImdyYXBoUUwiOnsidXJsIjoiaHR0cHM6Ly9wYXltZW50cy5zYW5kYm94LmJyYWludHJlZS1hcGkuY29tL2dyYXBocWwiLCJkYXRlIjoiMjAxOC0wNS0wOCIsImZlYXR1cmVzIjpbInRva2VuaXplX2NyZWRpdF9jYXJkcyJdfSwiY2xpZW50QXBpVXJsIjoiaHR0cHM6Ly9hcGkuc2FuZGJveC5icmFpbnRyZWVnYXRld2F5LmNvbTo0NDMvbWVyY2hhbnRzL2dzZnA2bnlneTNkemI4c2svY2xpZW50X2FwaSIsImVudmlyb25tZW50Ijoic2FuZGJveCIsIm1lcmNoYW50SWQiOiJnc2ZwNm55Z3kzZHpiOHNrIiwiYXNzZXRzVXJsIjoiaHR0cHM6Ly9hc3NldHMuYnJhaW50cmVlZ2F0ZXdheS5jb20iLCJhdXRoVXJsIjoiaHR0cHM6Ly9hdXRoLnZlbm1vLnNhbmRib3guYnJhaW50cmVlZ2F0ZXdheS5jb20iLCJ2ZW5tbyI6Im9mZiIsImNoYWxsZW5nZXMiOltdLCJ0aHJlZURTZWN1cmVFbmFibGVkIjp0cnVlLCJhbmFseXRpY3MiOnsidXJsIjoiaHR0cHM6Ly9vcmlnaW4tYW5hbHl0aWNzLXNhbmQuc2FuZGJveC5icmFpbnRyZWUtYXBpLmNvbS9nc2ZwNm55Z3kzZHpiOHNrIn0sImFwcGxlUGF5Ijp7ImNvdW50cnlDb2RlIjoiVVMiLCJjdXJyZW5jeUNvZGUiOiJVU0QiLCJtZXJjaGFudElkZW50aWZpZXIiOiJtZXJjaGFudC5jb20uYWR5ZW4uc2FuIiwic3RhdHVzIjoibW9jayIsInN1cHBvcnRlZE5ldHdvcmtzIjpbInZpc2EiLCJtYXN0ZXJjYXJkIiwiYW1leCIsImRpc2NvdmVyIl19LCJwYXlwYWxFbmFibGVkIjp0cnVlLCJwYXlwYWwiOnsiYmlsbGluZ0FncmVlbWVudHNFbmFibGVkIjp0cnVlLCJlbnZpcm9ubWVudE5vTmV0d29yayI6ZmFsc2UsInVudmV0dGVkTWVyY2hhbnQiOmZhbHNlLCJhbGxvd0h0dHAiOnRydWUsImRpc3BsYXlOYW1lIjoiSnVzcGF5IiwiY2xpZW50SWQiOiJBU0tBR2gyV1hncWZRNVR6anBaekxzZmhWR2xGYmpxNVZyVjVJT1g4S1hERDJOX1hxa0dlWU5Ea1d5cl9VWG5maFhwRWtBQmRtUDI4NGJfMiIsImJhc2VVcmwiOiJodHRwczovL2Fzc2V0cy5icmFpbnRyZWVnYXRld2F5LmNvbSIsImFzc2V0c1VybCI6Imh0dHBzOi8vY2hlY2tvdXQucGF5cGFsLmNvbSIsImRpcmVjdEJhc2VVcmwiOm51bGwsImVudmlyb25tZW50Ijoib2ZmbGluZSIsImJyYWludHJlZUNsaWVudElkIjoibWFzdGVyY2xpZW50MyIsIm1lcmNoYW50QWNjb3VudElkIjoianVzcGF5IiwiY3VycmVuY3lJc29Db2RlIjoiVVNEIn19"

@react.component
let make = (~sessionObj: option<SessionsType.token>) => {
  let sessionToken = sessionObj->Option.getOr(SessionsType.defaultToken)
  Console.log(sessionObj)
  let braintreeClientLoadStatus = CommonHooks.useScript(
    "https://js.braintreegateway.com/web/3.92.1/js/client.min.js",
  )
  let braintreeGPayScriptLoadStatus = CommonHooks.useScript(
    "https://js.braintreegateway.com/web/3.92.1/js/google-payment.min.js",
  )
  let gPayScriptLoadStatus = CommonHooks.useScript("https://pay.google.com/gp/p/js/pay.js")

  let areRequiredScriptsLoaded =
    braintreeClientLoadStatus == "ready" &&
    braintreeGPayScriptLoadStatus == "ready" &&
    gPayScriptLoadStatus == "ready"

  let gPayInstanceRef = React.useRef(Nullable.null)
  let paymentClientRef = React.useRef(Nullable.null)

  let handleGPayButtonClick = async () => {
    Console.log("Google Pay button clicked")
    switch gPayInstanceRef.current->Nullable.toOption {
    | Some(gPayInstance) => {
        let request = gPayInstance.createPaymentDataRequest(
          {
            "transactionInfo": {
              "currencyCode": sessionToken.transaction_info
              ->Utils.getDictFromJson
              ->Utils.getString("currency_code", ""),
              "totalPriceStatus": sessionToken.transaction_info
              ->Utils.getDictFromJson
              ->Utils.getString("total_price_status", "")
              ->String.toUpperCase,
              "totalPrice": sessionToken.transaction_info
              ->Utils.getDictFromJson
              ->Utils.getString("total_price", ""),
            },
          }->Identity.anyTypeToJson,
        )
        switch paymentClientRef.current->Nullable.toOption {
        | Some(paymentClient) =>
          try {
            let paymentData = await paymentClient.loadPaymentData(request)
            let payload = await gPayInstance.parseResponse(paymentData)
            let payloadDict = payload->Utils.getDictFromJson
            let nonce = payloadDict->Utils.getString("nonce", "")
            Console.log2("Payment data loaded successfully:", nonce)
          } catch {
          | _ => Console.error("Error loading payment data: ")
          }
        | None => Console.error("Payment client is not initialized.")
        }
      }
    | None => Console.error("Google Pay instance is not initialized.")
    }
  }

  React.useEffect(() => {
    if areRequiredScriptsLoaded {
      Console.log("Braintree Google Pay SDK loaded successfully.")
      braintreeClientCreate({authorization: token}, (err, clientInstance) => {
        if !err {
          Console.log("Braintree client instance created successfully.")
          braintreeGPayPaymentCreate(
            {
              "client": clientInstance,
              "googlePayVersion": 2,
              "googleMerchantId": "01234567890123456789",
            }->Identity.anyTypeToJson,
            (err, gPayInstance) => {
              if !err {
                Console.log("Google Pay instance created successfully.")
                gPayInstanceRef.current = Nullable.make(gPayInstance)
                paymentClientRef.current = Nullable.make(
                  newGPayPaymentClient({environment: "TEST"}),
                )

                switch paymentClientRef.current->Nullable.toOption {
                | Some(client) => {
                    let button = client.createButton({
                      onClick: handleGPayButtonClick,
                      buttonSizeMode: "fill",
                      buttonType: "checkout",
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
              }
            },
          )
        }
      })
    }
    None
  }, [areRequiredScriptsLoaded])

  <div className="w-full">
    <div id="google-pay-button" />
  </div>
}
