// open AmazonPayTypes
// open React

// @module("https://static-na.payments-amazon.com/checkout.js") external renderJSButton: (string, config) => unit = "renderJSButton"

// let renderAmazonPayButton = (~config) => {
//   renderJSButton("#AmazonPayButton", config)
// }

// @react.component
// let make = (~config) => {
//   // let script = CommonHooks.useScript("https://static-na.payments-amazon.com/checkout.js")
//   useEffect0(() => {
//     renderAmazonPayButton(~config)
//     None
//   })

//   <div id="AmazonPayButton" />
// }

// let default = make




// open AmazonPayTypes
// open React

// @module("https://static-na.payments-amazon.com/checkout.js")
// external renderJSButton: (string, config) => unit = "renderJSButton"

// let renderAmazonPayButton = (~config) => {
//   renderJSButton("#AmazonPayButton", config)
// }

// @react.component
// let make = () => {
//   /* Local state to store config once received via postMessage */
//   let (amazonPayConfig, setAmazonPayConfig) =
//     React.useState(() => None)

//   /* On mount, add message event listener. */
//   useEffect0(() => {
//     let handleMessage = (e: Dom.event) => {
//       switch Js.Json.decodeObject(e->Dom.EventTarget.asEvent->Dom.Event.data) {
//       | Some(dict) =>
//         switch Js.Dict.get(dict, "amazonPayConfig") {
//         | Some(configJson) => setAmazonPayConfig(_ => Some(configJson))
//         | None => ()
//         }
//       | None => ()
//       }
//     }
//     Js.Global.addEventListener("message", handleMessage)
//     Some(() => Js.Global.removeEventListener("message", handleMessage))
//   })

//   /* Whenever config is set, call renderAmazonPayButton */
//   useEffect1(
//     () => {
//       switch amazonPayConfig {
//       | Some(configJson) =>
//         /* configJson must be forced to the correct type or shape for button rendering */
//         renderJSButton("#AmazonPayButton", configJson)
//       | None => ()
//       }
//       None
//     },
//     [amazonPayConfig],
//   )

//   <div id="AmazonPayButton" />
// }

// let default = make




open AmazonPayTypes
open Utils

let convertToAmazonPayConfig = (
    config: JSON.t,
    buyerShippingAddress: ref<'a>,
    amazonPayCheckoutSessionId: ref<'a>,
    newShippingAmount: ref<float>,
  ): config => {
  {
    merchantId: config->getDictFromJson->getString("merchantId", ""),
    ledgerCurrency: config->getDictFromJson->getString("ledgerCurrency", ""),
    sandbox: config->getDictFromJson->getBool("sandbox", true),
    checkoutLanguage: config->getDictFromJson->getString("checkoutLanguage", "en_US"),
    productType: config->getDictFromJson->getString("productType", "PayAndShip"),
    placement: config->getDictFromJson->getString("placement", "Cart"),
    buttonColor: config->getDictFromJson->getString("buttonColor", "Gold"),
    checkoutSessionConfig: {
      storeId: config->getDictFromJson->getDictFromDict("checkoutSessionConfig")->getString("storeId", ""),
      paymentDetails: {
        paymentIntent: config->getDictFromJson->getDictFromDict("checkoutSessionConfig")->getDictFromDict("paymentDetails")->getString("paymentIntent", ""),
      },
    },
    onInitCheckout: (event) => {
      buyerShippingAddress := event
        ->Js.Json.decodeObject
        ->Option.flatMap(eventDict => Dict.get(eventDict, "shippingAddress"))
        ->Option.getOr(Js.Json.null)

      Js.log2("onInitCheckout:", Js.Json.stringifyAny(event))

      Js.Json.object_(
        Dict.fromArray([
          ("totalShippingAmount", Js.Json.object_(
            Dict.fromArray([
              ("amount", config->getDictFromJson->getString("totalShippingAmount", "")->Js.Json.string),
              ("currencyCode", Js.Json.string("USD")),
            ])
          )),
          ("totalBaseAmount", Js.Json.object_(
            Dict.fromArray([
              ("amount", config->getDictFromJson->getString("totalBaseAmount", "")->Js.Json.string),
              ("currencyCode", Js.Json.string("USD")),
            ])
          )),
          ("totalTaxAmount", Js.Json.object_(
            Dict.fromArray([
              ("amount", config->getDictFromJson->getString("totalTaxAmount", "")->Js.Json.string),
              ("currencyCode", Js.Json.string("USD")),
            ])
          )),
          ("totalDiscountAmount", Js.Json.object_(
            Dict.fromArray([
              ("amount", Js.Json.string("0")),
              ("currencyCode", Js.Json.string("USD")),
            ])
          )),
          ("totalChargeAmount", Js.Json.object_(
            Dict.fromArray([
              ("amount", config->getDictFromJson->getString("totalChargeAmount", "")->Js.Json.string),
              ("currencyCode", Js.Json.string("USD")),
            ])
          )),
          ("deliveryOptions", config->getDictFromJson->getJsonFromDict("deliveryOptions", Js.Json.null)),
        ])
      )
    },
    onShippingAddressSelection: (event) => {
      buyerShippingAddress := Js.Json.decodeObject(event)
        ->Option.flatMap(eventDict => Dict.get(eventDict, "shippingAddress"))
        ->Option.getOr(Js.Json.null)
      Js.log2("onShippingAddressSelection:", Js.Json.stringifyAny(event))
      Js.Json.object_(
        Dict.fromArray([
          ("totalShippingAmount", Js.Json.object_(
            Dict.fromArray([
              ("amount", config->getDictFromJson->getString("totalShippingAmount", "")->Js.Json.string),
              ("currencyCode", Js.Json.string("USD")),
            ])
          )),
          ("totalBaseAmount", Js.Json.object_(
            Dict.fromArray([
              ("amount", config->getDictFromJson->getString("totalBaseAmount", "")->Js.Json.string),
              ("currencyCode", Js.Json.string("USD")),
            ])
          )),
          ("totalTaxAmount", Js.Json.object_(
            Dict.fromArray([
              ("amount", config->getDictFromJson->getString("totalTaxAmount", "")->Js.Json.string),
              ("currencyCode", Js.Json.string("USD")),
            ])
          )),
          ("totalDiscountAmount", Js.Json.object_(
            Dict.fromArray([
              ("amount", Js.Json.string("0")),
              ("currencyCode", Js.Json.string("USD")),
            ])
          )),
          ("totalChargeAmount", Js.Json.object_(
            Dict.fromArray([
              ("amount", config->getDictFromJson->getString("totalChargeAmount", "")->Js.Json.string),
              ("currencyCode", Js.Json.string("USD")),
            ])
          )),
          ("deliveryOptions", config->getDictFromJson->getJsonFromDict("deliveryOptions", Js.Json.null)),
        ])
      )
    },
    onCompleteCheckout: (event) => {
      amazonPayCheckoutSessionId := Js.Json.decodeObject(event)
        ->Option.flatMap(eventDict => Dict.get(eventDict, "shippingAddress"))
        ->Option.getOr(Js.Json.null)
      Js.log2("onCompleteCheckout:", event)
      Js.log("Please use this values while calling backend API:")
      Js.log2("Shipping Address:", Js.Json.stringifyAny(buyerShippingAddress))
      Js.log2("Amazon Checkout Session ID:", amazonPayCheckoutSessionId)
    },
    onDeliveryOptionSelection: (event) => {
      newShippingAmount := event
        -> Js.Json.decodeObject
        -> Option.flatMap(eventDict => Dict.get(eventDict, "deliveryOptions"))
        -> Option.flatMap(deliveryOptionsJson => Js.Json.decodeObject(deliveryOptionsJson))
        -> Option.flatMap(deliveryOptionsDict => Dict.get(deliveryOptionsDict, "amount"))
        -> Option.flatMap(amountJson => Js.Json.decodeString(amountJson))
        -> Option.flatMap(amountString => Some(Js.Float.fromString(amountString)))
        -> Option.getOr(config->getDictFromJson->getString("totalShippingAmount", "")->Float.fromString->Option.getOr(0.0))

      let newTotalChargeAmount = (newShippingAmount.contents +. config->getDictFromJson->getString("totalBaseAmount", "")->Float.fromString->Option.getOr(0.0) +. config->getDictFromJson->getString("totalTaxAmount", "")->Float.fromString->Option.getOr(0.0))->Float.toString->Js.Json.string

      Js.Json.object_(
        Dict.fromArray([
          ("totalShippingAmount", Js.Json.object_(
            Dict.fromArray([
              ("amount", Js.Json.string(newShippingAmount.contents->Float.toString)),
              ("currencyCode", Js.Json.string("USD")),
            ])
          )),
          ("totalBaseAmount", Js.Json.object_(
            Dict.fromArray([
              ("amount", config->getDictFromJson->getString("totalBaseAmount", "")->Js.Json.string),
              ("currencyCode", Js.Json.string("USD")),
            ])
          )),
          ("totalTaxAmount", Js.Json.object_(
            Dict.fromArray([
              ("amount", config->getDictFromJson->getString("totalTaxAmount", "")->Js.Json.string),
              ("currencyCode", Js.Json.string("USD")),
            ])
          )),
          ("totalDiscountAmount", Js.Json.object_(
            Dict.fromArray([
              ("amount", Js.Json.string("0")),
              ("currencyCode", Js.Json.string("USD")),
            ])
          )),
          ("totalChargeAmount", Js.Json.object_(
            Dict.fromArray([
              ("amount", newTotalChargeAmount),
              ("currencyCode", Js.Json.string("USD")),
            ])
          )),
        ])
      )
    },
    onCancel: (_) => {
      Js.log("Checkout Cancelled")
    },
    // onInitCheckout: (_json: Js.Json.t) => Js.Json.null,
    // onShippingAddressSelection: (_json: Js.Json.t) => Js.Json.null,
    // onCompleteCheckout: (_json: Js.Json.t) => (),
    // onDeliveryOptionSelection: (_json: Js.Json.t) => Js.Json.null,
    // onCancel: () => (),
  }
}

@module("https://static-na.payments-amazon.com/checkout.js") external renderJSButton: (string, config) => unit = "renderJSButton"

@react.component
let make = (~walletOptions) => {
  Console.log("AmazonPayComponent")
  let isAmazonPayReady = Recoil.useRecoilValueFromAtom(RecoilAtoms.isAmazonPayReady)
  let options = Recoil.useRecoilValueFromAtom(RecoilAtoms.optionAtom)
  let status = CommonHooks.useScript("https://static-na.payments-amazon.com/checkout.js")
  let isWallet = walletOptions->Array.includes("amazon_pay")

  Js.log2(status, isWallet)

  let (_, _, _, _, heightType, _) = options.wallets.style.height
  let height = switch heightType {
  | AmazonPay(val) => val
  | _ => 45
  }

  React.useEffect0(() => {
    let handleAmazonPay = (ev: Window.event) => {
      let json = ev.data->safeParse
      let dict = json->getDictFromJson
      if status == "ready" && dict->Dict.get("amazonPayConfig")->Option.isSome  {
        let buyerShippingAddress = ref(Js.Json.null)
        let amazonPayCheckoutSessionId = ref(Js.Json.null)
        let newShippingAmount = ref(0.0)
        let config = dict->getJsonObjectFromDict("amazonPayConfig")
        let amazonPayConfig = config->convertToAmazonPayConfig(buyerShippingAddress, amazonPayCheckoutSessionId, newShippingAmount)
        renderJSButton("#AmazonPayButton", amazonPayConfig)
      }
    }
    Window.addEventListener("message", handleAmazonPay)
    Some(() => {Window.removeEventListener("message", handleAmazonPay)})
  })


  // React.useEffect1(() => {
  //   let handleAmazonPay = (ev: Window.event) => {
  //     let json = ev.data->safeParse
  //     let dict = json->getDictFromJson

  //     // Ensure script is loaded & amazonPayConfig exists
  //     if status == "ready" && dict->Dict.get("amazonPayConfig")->Option.isSome {
  //       let config = dict->getJsonObjectFromDict("amazonPayConfig")
  //       let amazonPayConfig = config->convertToAmazonPayConfig

  //       // Ensure amazon.pay exists before using it
  //       switch (Js.Undefined.fromNullable(Js.Global, #amazon)) {
  //       | Some(amazon) => renderJSButton("#AmazonPayButton", amazonPayConfig)
  //       | None => Js.log("Amazon Pay SDK not available yet")
  //       }
  //     }
  //   }

  //   // Add event listener
  //   Webapi.Dom.window->EventTarget.addEventListener("message", handleAmazonPay, {capture: false})

  //   // Cleanup event listener on component unmount
  //   Some(() => {
  //     Webapi.Dom.window->EventTarget.removeEventListener("message", handleAmazonPay, {capture: false})
  //   })
  // }, [status]) // Only re-run when script status changes


//   React.useEffect0(() => {
//   let handleAmazonPay = (ev: Window.event) => {
//     let json = ev.data->safeParse
//     let dict = json->getDictFromJson

//     // Ensure SDK is ready & config exists
//     if status == "ready" && dict->Dict.get("amazonPayConfig")->Option.isSome {
//       let config = dict->getJsonObjectFromDict("amazonPayConfig")
//       let amazonPayConfig = config->convertToAmazonPayConfig

//       // Ensure #AmazonPayButton exists before calling renderJSButton
//       let button = Webapi.Dom.document->Webapi.Dom.Document.querySelector("#AmazonPayButton")
//       switch (Js.Undefined.fromNullable(button)) {
//       | Some(_) => renderJSButton("#AmazonPayButton", amazonPayConfig)
//       | None => Js.log("AmazonPay button is not available in the DOM yet!")
//       }
//     }
//   }

//   // Attach event listener
//   Webapi.Dom.window->EventTarget.addEventListener("message", handleAmazonPay, {capture: false})

//   // Cleanup on unmount
//   Some(() => {
//     Webapi.Dom.window->EventTarget.removeEventListener("message", handleAmazonPay, {capture: false})
//   })
// })


  // <div id="AmazonPayButton" />
  let isRenderAmazonPayButton = isAmazonPayReady && isWallet
  <RenderIf condition={isRenderAmazonPayButton}>
    <div
      style={height: `${height->Int.toString}px`}
      id="AmazonPayButton"
      className={`w-full flex flex-row justify-center rounded-md  [&>*]:w-full [&>button]:!bg-contain`}
    />
  </RenderIf>
}

let default = make