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
  totalOrderAmount: amountDetails,
  totalChargeAmount: amountDetails,
  totalDiscountAmount: amountDetails,
  deliveryOptions: array<deliveryOption>,
}

type deliveryOptionResponse = {
  totalShippingAmount: amountDetails,
  totalBaseAmount: amountDetails,
  totalTaxAmount: amountDetails,
  totalOrderAmount: amountDetails,
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

let getAmazonPayConfig = (sessionToken: amazonPayTokenType): amazonPayConfigType<'a> => {
  let baseAmount = sessionToken.totalBaseAmount->Float.fromString->Option.getOr(0.0)
  let taxAmount = sessionToken.totalTaxAmount->Float.fromString->Option.getOr(0.0)
  let shippingAmount = sessionToken.totalShippingAmount->Float.fromString->Option.getOr(0.0)
  let totalOrderAmount = (baseAmount +. taxAmount +. shippingAmount)->Float.toString
  let sanitizedMerchantId = sessionToken.merchantId->String.replaceRegExp(%re("/\s+/g"), "")

  {
    merchantId: "A3UJN62U20X4GB",
    ledgerCurrency: "USD",
    sandbox: true,
    checkoutLanguage: "en_US",
    productType: "PayAndShip",
    placement: "Checkout",
    buttonColor: "Gold",
    estimatedOrderAmount: {
      amount: "110.44",
      currencyCode: "USD",
    },
    checkoutSessionConfig: {
      storeId: "amzn1.application-oa2-client.43ee1af277a94b6c8efd9118dd6c156c",
      scopes: ["name", "email", "phoneNumber", "billingAddress"],
      paymentDetails: {
        paymentIntent: "AuthorizeWithCapture",
        canHandlePendingAuthorization: false,
      },
    },
    onInitCheckout: _event => {
      Console.log("Checkout initialized successfully!")
      {
        totalShippingAmount: {amount: "50.00", currencyCode: "USD"},
        totalBaseAmount: {amount: "50.44", currencyCode: "USD"},
        totalTaxAmount: {amount: "10.00", currencyCode: "USD"},
        totalChargeAmount: {amount: "110.44", currencyCode: "USD"},
        totalDiscountAmount: {amount: "0.00", currencyCode: "USD"},
        deliveryOptions: [
          {
            id: "standard-delivery",
            price: {amount: "20.00", currencyCode: "USD"},
            shippingMethod: {
              shippingMethodName: "standard-courier",
              shippingMethodCode: "standard-courier",
            },
            isDefault: true,
          },
          {
            id: "express-delivery",
            price: {amount: "50.00", currencyCode: "USD"},
            shippingMethod: {
              shippingMethodName: "express-courier",
              shippingMethodCode: "express-courier",
            },
            isDefault: false,
          },
        ],
      }
    },
    onShippingAddressSelection: _event => {
      Console.log("Shipping address updated")
      {
        totalShippingAmount: {amount: "50.00", currencyCode: "USD"},
        totalBaseAmount: {amount: "50.44", currencyCode: "USD"},
        totalTaxAmount: {amount: "10.00", currencyCode: "USD"},
        totalOrderAmount: {amount: "110.44", currencyCode: "USD"},
        totalChargeAmount: {amount: "110.44", currencyCode: "USD"},
        totalDiscountAmount: {amount: "0.00", currencyCode: "USD"},
        deliveryOptions: [
          {
            id: "standard-delivery",
            price: {amount: "20.00", currencyCode: "USD"},
            shippingMethod: {
              shippingMethodName: "standard-courier",
              shippingMethodCode: "standard-courier",
            },
            isDefault: true,
          },
          {
            id: "express-delivery",
            price: {amount: "50.00", currencyCode: "USD"},
            shippingMethod: {
              shippingMethodName: "express-courier",
              shippingMethodCode: "express-courier",
            },
            isDefault: false,
          },
        ],
      }
    },
    onDeliveryOptionSelection: event => {
      Console.log("Delivery option updated")
      let deliveryOptions = [
        {
          id: "standard-delivery",
          price: {amount: "20.00", currencyCode: "USD"},
          shippingMethod: {
            shippingMethodName: "standard-courier",
            shippingMethodCode: "standard-courier",
          },
          isDefault: true,
        },
        {
          id: "express-delivery",
          price: {amount: "50.00", currencyCode: "USD"},
          shippingMethod: {
            shippingMethodName: "express-courier",
            shippingMethodCode: "express-courier",
          },
          isDefault: false,
        },
      ]

      let selectedOption =
        deliveryOptions->Array.find(option => option.id === event.deliveryOptions.id)
      let newShippingAmount = selectedOption->Option.mapOr("50.00", option => option.price.amount)
      let baseAmount = 50.44
      let taxAmount = 10.00
      let shippingAmount = newShippingAmount->Float.fromString->Option.getOr(50.00)
      let newTotalAmount = (baseAmount +. taxAmount +. shippingAmount)->Float.toString

      {
        totalShippingAmount: {amount: newShippingAmount, currencyCode: "USD"},
        totalBaseAmount: {amount: "50.44", currencyCode: "USD"},
        totalTaxAmount: {amount: "10.00", currencyCode: "USD"},
        totalOrderAmount: {amount: newTotalAmount, currencyCode: "USD"},
        totalChargeAmount: {amount: newTotalAmount, currencyCode: "USD"},
        totalDiscountAmount: {amount: "0.00", currencyCode: "USD"},
      }
    },
    onCompleteCheckout: _event => {
      Console.log(
        "Checkout completed successfully! (This is a demo - no actual payment was processed)",
      )
      {status: "success"}
    },
    onCancel: _event => {
      Console.log("Checkout was cancelled by user")
    },
  }
}

external renderAmazonPayButton: (~buttonId: string, ~config: amazonPayConfigType<'a>) => unit =
  "amazon.Pay.renderJSButton"

@react.component
let make = (~amazonPayToken) => {
  let token = amazonPayToken->amazonPayTokenMapper
  let config = getAmazonPayConfig(token)
  let status = CommonHooks.useScript("https://static-na.payments-amazon.com/checkout.js")
  let isAmazonPayReady = React.useRef(false)

  React.useEffect1(() => {
    if isAmazonPayReady.current {
      Console.log("Amazon Pay is already ready, skipping re-render")
      renderAmazonPayButton(~buttonId="#AmazonPayButton", ~config)
    }
    None
  }, [isAmazonPayReady.current])

  React.useEffect2(() => {
    if status == "ready" && config.merchantId != "" {
      try {
        isAmazonPayReady.current = true
      } catch {
      | e => Console.error2("Error rendering Amazon Pay button:", e)
      }
    }
    None
  }, (config, status))

  <div id="AmazonPayButton" />
}
