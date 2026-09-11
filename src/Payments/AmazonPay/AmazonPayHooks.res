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
    let baseAmount = sessionToken.totalBaseAmount->getFloatFromString(0.0)
    let taxAmount = sessionToken.totalTaxAmount->getFloatFromString(0.0)
    let defaultShippingAmount =
      sessionToken.deliveryOptions
      ->Array.find(option => option.isDefault)
      ->Option.mapOr("0.0", option => option.price.amount)

    let shippingAmount = defaultShippingAmount->getFloatFromString(0.0)

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
      onInitCheckout: e =>
        handleOnInitCheckout(
          e,
          shippingAddressRef,
          defaultShippingAmount,
          currencyCode,
          sessionToken,
          totalOrderAmount,
        ),
      onShippingAddressSelection: e =>
        handleOnShippingAddressSelection(
          e,
          shippingAddressRef,
          defaultShippingAmount,
          currencyCode,
          sessionToken,
          totalOrderAmount,
        ),
      onDeliveryOptionSelection: e =>
        handleOnDeliveryOptionSelection(e, currencyCode, sessionToken),
      onCompleteCheckout: event =>
        intent(
          ~bodyArr=amazonPayBody(
            event->getDictFromJson->getString("amazonCheckoutSessionId", ""),
            shippingAddressRef.current,
          ),
          ~confirmParam={
            return_url: options.wallets.walletReturnUrl,
            publishableKey,
          },
          ~handleUserError=true,
          ~manualRetry=isManualRetryEnabled,
        ),
      onCancel: _ =>
        intent(
          ~bodyArr=amazonPayBody("", shippingAddressRef.current),
          ~confirmParam={
            return_url: options.wallets.walletReturnUrl,
            publishableKey,
          },
          ~handleUserError=true,
          ~manualRetry=isManualRetryEnabled,
        ),
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
