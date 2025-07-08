open Utils

@val @scope("window")
type deliveryPrice = {
  amount: int,
  displayAmount: string,
  currencyCode: string,
}

type shippingMethod = {
  shippingMethodName: string,
  shippingMethodCode: string,
}

type priceAmount = {
  amount: string,
  currencyCode: string,
}

type deliveryOption = {
  id: string,
  price: priceAmount,
  shippingMethod: shippingMethod,
  isDefault: bool,
}

type amazonPayTokenType = {
  walletName: string,
  merchantId: string,
  ledgerCurrency: string,
  storeId: string,
  paymentIntent: string,
  totalShippingAmount: string,
  totalTaxAmount: string,
  totalBaseAmount: string,
  deliveryOptions: array<deliveryOption>,
}

// Amazon Pay Config Types
type estimatedOrderAmount = {
  amount: string,
  currencyCode: string,
}

type paymentDetails = {
  paymentIntent: string,
  canHandlePendingAuthorization: bool,
}

type checkoutSessionConfig = {
  storeId: string,
  scopes: array<string>,
  paymentDetails: paymentDetails,
}

type amountDetails = {
  amount: string,
  currencyCode: string,
}

type cartDetails = {
  totalShippingAmount: amountDetails,
  totalBaseAmount: amountDetails,
  totalTaxAmount: amountDetails,
  totalChargeAmount: amountDetails,
  totalDiscountAmount: amountDetails,
  deliveryOptions: array<deliveryOption>,
}

type shippingAddressResponse = {
  totalShippingAmount: amountDetails,
  totalBaseAmount: amountDetails,
  totalTaxAmount: amountDetails,
  totalChargeAmount: amountDetails,
  totalDiscountAmount: amountDetails,
  deliveryOptions: array<deliveryOption>,
}

type deliveryOptionResponse = {
  totalShippingAmount: amountDetails,
  totalBaseAmount: amountDetails,
  totalTaxAmount: amountDetails,
  totalChargeAmount: amountDetails,
  totalDiscountAmount: amountDetails,
}

type checkoutCompleteResponse = {status: string}

type deliveryOptionEventDetails = {id: string}

type deliveryOptionEvent = {deliveryOptions: deliveryOptionEventDetails}

type amazonPayConfigType<'a> = {
  merchantId: string,
  ledgerCurrency: string,
  sandbox: bool,
  checkoutLanguage: string,
  productType: string,
  placement: string,
  buttonColor: string,
  estimatedOrderAmount: estimatedOrderAmount,
  checkoutSessionConfig: checkoutSessionConfig,
  onInitCheckout: 'a => cartDetails,
  onShippingAddressSelection: 'a => shippingAddressResponse,
  onDeliveryOptionSelection: deliveryOptionEvent => deliveryOptionResponse,
  onCompleteCheckout: 'a => checkoutCompleteResponse,
  onCancel: 'a => unit,
}

let deliveryPriceMapper = dict => {
  {
    amount: getInt(dict, "amount", 0),
    displayAmount: getString(dict, "display_amount", ""),
    currencyCode: getString(dict, "currency_code", ""),
  }
}

let shippingMethodMapper = dict => {
  {
    shippingMethodName: getString(dict, "shipping_method_name", ""),
    shippingMethodCode: getString(dict, "shipping_method_code", ""),
  }
}

let deliveryOptionMapper = dict => {
  let priceData = dict->getDictFromDict("price")->deliveryPriceMapper
  {
    id: getString(dict, "id", ""),
    price: {
      amount: priceData.displayAmount,
      currencyCode: priceData.currencyCode,
    },
    shippingMethod: dict->getDictFromDict("shipping_method")->shippingMethodMapper,
    isDefault: getBool(dict, "is_default", false),
  }
}

let amazonPayTokenMapper = dict => {
  {
    walletName: getString(dict, "wallet_name", ""),
    merchantId: getString(dict, "merchant_id", ""),
    ledgerCurrency: getString(dict, "ledger_currency", ""),
    storeId: getString(dict, "store_id", ""),
    paymentIntent: getString(dict, "payment_intent", ""),
    totalShippingAmount: getString(dict, "total_shipping_amount", ""),
    totalTaxAmount: getString(dict, "total_tax_amount", ""),
    totalBaseAmount: getString(dict, "total_base_amount", ""),
    deliveryOptions: getArray(dict, "delivery_options")->Array.map(item =>
      item->getDictFromJson->deliveryOptionMapper
    ),
  }
}

let mapDeliveryOptionsToConfig = (options: array<deliveryOption>): array<deliveryOption> => {
  options->Array.map(option => {
    {
      id: option.id,
      price: {
        amount: option.price.amount,
        currencyCode: option.price.currencyCode,
      },
      shippingMethod: option.shippingMethod,
      isDefault: option.isDefault,
    }
  })
}

external renderAmazonPayButton: (~buttonId: string, ~config: amazonPayConfigType<'a>) => unit =
  "amazon.Pay.renderJSButton"

type amazonPayData = {checkout_session_id: string}

type wallet = {amazon_pay: amazonPayData}

let amazonPayBody = amazonCheckoutSessionId => {
  let wallet = {
    amazon_pay: {
      checkout_session_id: amazonCheckoutSessionId,
    },
  }
  let paymentMethodData =
    [
      ("wallet", wallet->Identity.anyTypeToJson),
      ("capture_method", "automatic"->JSON.Encode.string),
      ("payment_experience", "invoke_sdk_client"->JSON.Encode.string),
      ("payment_method_type", "amazon_pay"->JSON.Encode.string),
    ]->Utils.getJsonFromArrayOfJson

  [("payment_method", "wallet"->JSON.Encode.string), ("payment_method_data", paymentMethodData)]
}

let useAmazonPay = () => {
  let loggerState = Recoil.useRecoilValueFromAtom(RecoilAtoms.loggerAtom)
  let options = Recoil.useRecoilValueFromAtom(RecoilAtoms.optionAtom)
  let intent = PaymentHelpers.usePaymentIntent(Some(loggerState), AmazonPay)
  let {publishableKey} = Recoil.useRecoilValueFromAtom(RecoilAtoms.keys)
  let isManualRetryEnabled = Recoil.useRecoilValueFromAtom(RecoilAtoms.isManualRetryEnabled)

  let getAmazonPayConfig = (sessionToken: amazonPayTokenType): amazonPayConfigType<'a> => {
    let baseAmount = sessionToken.totalBaseAmount->Float.fromString->Option.getOr(0.0)
    let taxAmount = sessionToken.totalTaxAmount->Float.fromString->Option.getOr(0.0)
    let shippingAmount = sessionToken.totalShippingAmount->Float.fromString->Option.getOr(0.0)
    let totalOrderAmount = (baseAmount +. taxAmount +. shippingAmount)->Float.toString

    Console.log(sessionToken)

    {
      merchantId: "A3UJN62U20X4GB",
      ledgerCurrency: sessionToken.ledgerCurrency,
      sandbox: true,
      checkoutLanguage: "en_US",
      productType: "PayAndShip",
      placement: "Checkout",
      buttonColor: "Gold",
      estimatedOrderAmount: {
        amount: totalOrderAmount,
        currencyCode: sessionToken.ledgerCurrency,
      },
      checkoutSessionConfig: {
        storeId: "amzn1.application-oa2-client.43ee1af277a94b6c8efd9118dd6c156c",
        scopes: ["name", "email", "phoneNumber", "billingAddress"],
        paymentDetails: {
          paymentIntent: sessionToken.paymentIntent,
          canHandlePendingAuthorization: false,
        },
      },
      onInitCheckout: _event => {
        Console.log("Checkout initialized successfully!")
        let currencyCode = sessionToken.ledgerCurrency
        {
          totalShippingAmount: {amount: sessionToken.totalShippingAmount, currencyCode},
          totalBaseAmount: {amount: sessionToken.totalBaseAmount, currencyCode},
          totalTaxAmount: {amount: sessionToken.totalTaxAmount, currencyCode},
          totalChargeAmount: {amount: totalOrderAmount, currencyCode},
          totalDiscountAmount: {amount: "0.00", currencyCode},
          deliveryOptions: sessionToken.deliveryOptions,
        }
      },
      onShippingAddressSelection: event => {
        Console.log2("Shipping address updated", event)
        let currencyCode = sessionToken.ledgerCurrency

        {
          totalShippingAmount: {amount: sessionToken.totalShippingAmount, currencyCode},
          totalBaseAmount: {amount: sessionToken.totalBaseAmount, currencyCode},
          totalTaxAmount: {amount: sessionToken.totalTaxAmount, currencyCode},
          totalChargeAmount: {amount: totalOrderAmount, currencyCode},
          totalDiscountAmount: {amount: "0.00", currencyCode},
          deliveryOptions: sessionToken.deliveryOptions,
        }
      },
      onDeliveryOptionSelection: event => {
        Console.log("Delivery option updated")
        let deliveryOptions = sessionToken.deliveryOptions
        let currencyCode = sessionToken.ledgerCurrency
        let selectedOption =
          deliveryOptions->Array.find(option => option.id === event.deliveryOptions.id)
        let newShippingAmount = selectedOption->Option.mapOr("0.0", option => option.price.amount)
        let baseAmount = sessionToken.totalBaseAmount->Float.fromString->Option.getOr(0.0)
        let taxAmount = sessionToken.totalTaxAmount->Float.fromString->Option.getOr(0.0)
        let shippingAmount = newShippingAmount->Float.fromString->Option.getOr(0.0)
        let newTotalAmount = (baseAmount +. taxAmount +. shippingAmount)->Float.toString

        {
          totalShippingAmount: {amount: newShippingAmount, currencyCode},
          totalBaseAmount: {amount: sessionToken.totalBaseAmount, currencyCode},
          totalTaxAmount: {amount: sessionToken.totalTaxAmount, currencyCode},
          totalChargeAmount: {amount: newTotalAmount, currencyCode},
          totalDiscountAmount: {amount: "0.00", currencyCode},
        }
      },
      onCompleteCheckout: event => {
        Console.log(
          "Checkout completed successfully! (This is a demo - no actual payment was processed)",
        )

        let checkoutResponseDict = event->getDictFromJson
        let amazonCheckoutSessionId = checkoutResponseDict->getString("amazonCheckoutSessionId", "")

        intent(
          ~bodyArr=amazonPayBody(amazonCheckoutSessionId),
          ~confirmParam={
            return_url: options.wallets.walletReturnUrl,
            publishableKey,
          },
          ~handleUserError=true,
          ~manualRetry=isManualRetryEnabled,
        )

        Console.log2("Checkout event details:", event)
        {status: "success"}
      },
      onCancel: _event => {
        Console.log("Checkout was cancelled by user")
      },
    }
  }
  getAmazonPayConfig
}

@react.component
let make = (~amazonPayToken) => {
  let token = amazonPayToken->amazonPayTokenMapper
  let getAmazonPayConfig = useAmazonPay()
  let config = getAmazonPayConfig(token)
  let scriptLoadStatus = CommonHooks.useScript("https://static-na.payments-amazon.com/checkout.js")
  let isAmazonPayRenderedOnce = React.useRef(false)

  React.useEffect3(() => {
    if scriptLoadStatus == "ready" && config.merchantId != "" && !isAmazonPayRenderedOnce.current {
      try {
        renderAmazonPayButton(~buttonId="#AmazonPayButton", ~config)
        isAmazonPayRenderedOnce.current = true
      } catch {
      | e => Console.error2("Error rendering Amazon Pay button:", e)
      }
    }
    None
  }, (config, scriptLoadStatus, isAmazonPayRenderedOnce.current))

  <div id="AmazonPayButton" />
}
