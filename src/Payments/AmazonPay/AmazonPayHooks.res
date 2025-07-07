open AmazonPayTypes
open AmazonPayHelpers
open Utils

let useAmazonPay = token => {
  let scriptLoadStatus = CommonHooks.useScript("https://static-na.payments-amazon.com/checkout.js")

  let loggerState = Recoil.useRecoilValueFromAtom(RecoilAtoms.loggerAtom)
  let options = Recoil.useRecoilValueFromAtom(RecoilAtoms.optionAtom)
  let intent = PaymentHelpers.usePaymentIntent(Some(loggerState), AmazonPay)
  let {publishableKey} = Recoil.useRecoilValueFromAtom(RecoilAtoms.keys)
  let isManualRetryEnabled = Recoil.useRecoilValueFromAtom(RecoilAtoms.isManualRetryEnabled)
  let shippingAddressRef = React.useRef(defaultShipping)

  let getAmazonPayConfig = (sessionToken: amazonPayTokenType): amazonPayConfigType => {
    let baseAmount = sessionToken.totalBaseAmount->Float.fromString->Option.getOr(0.0)
    let taxAmount = sessionToken.totalTaxAmount->Float.fromString->Option.getOr(0.0)
    let defaultShippingAmount =
      sessionToken.deliveryOptions
      ->Array.find(option => option.isDefault)
      ->Option.mapOr("0.0", option => option.price.amount)

    let shippingAmount = defaultShippingAmount->Float.fromString->Option.getOr(0.0)

    let totalOrderAmount = (baseAmount +. taxAmount +. shippingAmount)->Float.toString
    let currencyCode = sessionToken.ledgerCurrency

    {
      merchantId: sessionToken.merchantId,
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
        storeId: sessionToken.storeId,
        scopes: ["name", "email", "phoneNumber", "billingAddress"],
        paymentDetails: {
          paymentIntent: sessionToken.paymentIntent,
          canHandlePendingAuthorization: false,
        },
      },
      onInitCheckout: event => {
        shippingAddressRef.current = event->getShippingAddressFromEvent

        {
          totalShippingAmount: {amount: defaultShippingAmount, currencyCode},
          totalBaseAmount: {amount: sessionToken.totalBaseAmount, currencyCode},
          totalTaxAmount: {amount: sessionToken.totalTaxAmount, currencyCode},
          totalChargeAmount: {amount: totalOrderAmount, currencyCode},
          totalDiscountAmount: {amount: "0.00", currencyCode},
          deliveryOptions: sessionToken.deliveryOptions,
        }
      },
      onShippingAddressSelection: event => {
        shippingAddressRef.current = event->getShippingAddressFromEvent

        {
          totalShippingAmount: {amount: defaultShippingAmount, currencyCode},
          totalBaseAmount: {amount: sessionToken.totalBaseAmount, currencyCode},
          totalTaxAmount: {amount: sessionToken.totalTaxAmount, currencyCode},
          totalChargeAmount: {amount: totalOrderAmount, currencyCode},
          totalDiscountAmount: {amount: "0.00", currencyCode},
          deliveryOptions: sessionToken.deliveryOptions,
        }
      },
      onDeliveryOptionSelection: event => {
        let selectedOption =
          sessionToken.deliveryOptions->Array.find(option => option.id === event.deliveryOptions.id)
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
        let amazonCheckoutSessionId =
          event->getDictFromJson->getString("amazonCheckoutSessionId", "")

        intent(
          ~bodyArr=amazonPayBody(amazonCheckoutSessionId, shippingAddressRef.current),
          ~confirmParam={
            return_url: options.wallets.walletReturnUrl,
            publishableKey,
          },
          ~handleUserError=true,
          ~manualRetry=isManualRetryEnabled,
        )
      },
      onCancel: _ => {
        intent(
          ~bodyArr=amazonPayBody("", shippingAddressRef.current),
          ~confirmParam={
            return_url: options.wallets.walletReturnUrl,
            publishableKey,
          },
          ~handleUserError=true,
          ~manualRetry=isManualRetryEnabled,
        )
      },
    }
  }

  let isRenderedOnce = React.useRef(false)
  let config = React.useMemo(() => getAmazonPayConfig(token), [token])

  React.useEffect3(() => {
    let shouldRender =
      scriptLoadStatus == "ready" && config.merchantId != "" && !isRenderedOnce.current

    if shouldRender {
      try {
        renderAmazonPayButton(~buttonId="#AmazonPayButton", ~config)
        isRenderedOnce.current = true
      } catch {
      | e => Console.error2("Error rendering Amazon Pay button:", e)
      }
    }
    None
  }, (config, scriptLoadStatus, isRenderedOnce.current))
}
