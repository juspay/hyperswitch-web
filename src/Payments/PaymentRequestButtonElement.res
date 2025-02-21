type wallet =
  GPayWallet | PaypalWallet | ApplePayWallet | KlarnaWallet | SamsungPayWallet | PazeWallet | AmazonPayWallet | NONE
let paymentMode = str => {
  switch str {
  | "gpay"
  | "google_pay" =>
    GPayWallet
  | "paypal" => PaypalWallet
  | "applepay"
  | "apple_pay" =>
    ApplePayWallet
  | "samsungpay"
  | "samsung_pay" =>
    SamsungPayWallet
  | "klarna" => KlarnaWallet
  | "paze" => PazeWallet
  | "amazonpay"
  | "amazon_pay" =>
    AmazonPayWallet
  | _ => NONE
  }
}

module WalletsSaveDetailsText = {
  @react.component
  let make = (~paymentType) => {
    open RecoilAtoms
    let {isGooglePay, isApplePay, isPaypal, isSamsungPay, isAmazonPay} = Recoil.useRecoilValueFromAtom(
      areOneClickWalletsRendered,
    )
    let {localeString} = Recoil.useRecoilValueFromAtom(configAtom)
    let isGuestCustomer = UtilityHooks.useIsGuestCustomer()

    <RenderIf
      condition={PaymentUtils.isAppendingCustomerAcceptance(~isGuestCustomer, ~paymentType) &&
      (isGooglePay || isApplePay || isPaypal || isSamsungPay || isAmazonPay)}>
      <div className="flex items-center text-xs mt-2">
        <Icon name="lock" size=10 className="mr-1" />
        <em className="text-left text-gray-400">
          {localeString.saveWalletDetails->React.string}
        </em>
      </div>
    </RenderIf>
  }
}

@react.component
let make = (~sessions, ~walletOptions, ~paymentType) => {
  open SessionsType
  let dict = sessions->Utils.getDictFromJson
  let paymentMethodListValue = Recoil.useRecoilValueFromAtom(PaymentUtils.paymentMethodListValue)

  let sessionObj = React.useMemo(() => itemToObjMapper(dict, Others), [dict])

  let {
    paypalToken,
    isPaypalSDKFlow,
    isPaypalRedirectFlow,
  } = PayPalHelpers.usePaymentMethodExperience(~paymentMethodListValue, ~sessionObj)

  let gPayToken = getPaymentSessionObj(sessionObj.sessionsToken, Gpay)
  let applePaySessionObj = itemToObjMapper(dict, ApplePayObject)
  let applePayToken = getPaymentSessionObj(applePaySessionObj.sessionsToken, ApplePay)

  let samsungPaySessionObj = itemToObjMapper(dict, SamsungPayObject)
  let samsungPayToken = getPaymentSessionObj(samsungPaySessionObj.sessionsToken, SamsungPay)

  let googlePayThirdPartySessionObj = itemToObjMapper(dict, GooglePayThirdPartyObject)
  let googlePayThirdPartyToken = getPaymentSessionObj(
    googlePayThirdPartySessionObj.sessionsToken,
    Gpay,
  )

  let {isKlarnaSDKFlow, isKlarnaCheckoutFlow} = KlarnaHelpers.usePaymentMethodExperience(
    ~paymentMethodListValue,
    ~sessionObj,
  )

  let klarnaTokenObj = getPaymentSessionObj(sessionObj.sessionsToken, Klarna)
  let pazeTokenObj = getPaymentSessionObj(sessionObj.sessionsToken, Paze)

  let amazonPaySessionObj = itemToObjMapper(dict, AmazonPayObject)
  let amazonPayToken = getPaymentSessionObj(
    amazonPaySessionObj.sessionsToken,
    AmazonPay,
  )

  let amazonPaySessionObj = itemToObjMapper(dict, AmazonPayObject)
  let amazonPayToken = getPaymentSessionObj(
    amazonPaySessionObj.sessionsToken,
    AmazonPay,
  )

  let {clientSecret} = Recoil.useRecoilValueFromAtom(RecoilAtoms.keys)
  let options = Recoil.useRecoilValueFromAtom(RecoilAtoms.optionAtom)
  Console.log(walletOptions)
  <div role="region" ariaLabel="Wallet Section" className="flex flex-col gap-2 h-auto w-full">
    {walletOptions
    ->Array.mapWithIndex((item, i) => {
      <ErrorBoundary
        level={ErrorBoundary.RequestButton}
        key={`${item}-${i->Int.toString}-request-button`}
        componentName="PaymentRequestButtonElement">
        <ReusableReactSuspense
          loaderComponent={<WalletShimmer />}
          componentName="PaymentRequestButtonElement"
          key={i->Int.toString}>
          {switch clientSecret {
          | Some(_) =>
            switch item->paymentMode {
            | GPayWallet =>
              <SessionPaymentWrapper type_={Wallet}>
                {switch gPayToken {
                | OtherTokenOptional(optToken) =>
                  switch googlePayThirdPartyToken {
                  | GooglePayThirdPartyTokenOptional(googlePayThirdPartyOptToken) =>
                    <GPayLazy
                      sessionObj=optToken
                      thirdPartySessionObj=googlePayThirdPartyOptToken
                      walletOptions
                      paymentType
                    />
                  | _ =>
                    <GPayLazy
                      sessionObj=optToken thirdPartySessionObj=None walletOptions paymentType
                    />
                  }
                | _ => React.null
                }}
              </SessionPaymentWrapper>
            | PaypalWallet =>
              <SessionPaymentWrapper type_={Wallet}>
                {switch paypalToken {
                | OtherTokenOptional(optToken) =>
                  switch (optToken, isPaypalSDKFlow, isPaypalRedirectFlow) {
                  | (Some(token), true, _) => <PaypalSDKLazy sessionObj=token paymentType />
                  | (_, _, true) => <PayPalLazy paymentType walletOptions />
                  | _ => React.null
                  }
                | _ =>
                  <RenderIf condition={isPaypalRedirectFlow}>
                    <PayPalLazy paymentType walletOptions />
                  </RenderIf>
                }}
              </SessionPaymentWrapper>
            | ApplePayWallet =>
              switch applePayToken {
              | ApplePayTokenOptional(optToken) =>
                <ApplePayLazy sessionObj=optToken walletOptions paymentType />
              | _ => React.null
              }
            | SamsungPayWallet =>
              switch samsungPayToken {
              | SamsungPayTokenOptional(optToken) =>
                <SamsungPayComponent sessionObj=optToken walletOptions />
              | _ => React.null
              }
            | KlarnaWallet =>
              <SessionPaymentWrapper type_={Others}>
                {switch klarnaTokenObj {
                | OtherTokenOptional(optToken) =>
                  switch (optToken, isKlarnaSDKFlow, isKlarnaCheckoutFlow) {
                  | (Some(token), true, _) => <KlarnaSDKLazy sessionObj=token />
                  | (_, _, true) => <KlarnaCheckoutLazy />
                  | _ => React.null
                  }
                | _ => React.null
                }}
              </SessionPaymentWrapper>

            | PazeWallet =>
              <RenderIf condition={options.wallets.paze === Auto}>
                <SessionPaymentWrapper type_={Wallet}>
                  {switch pazeTokenObj {
                  | OtherTokenOptional(optToken) =>
                    switch optToken {
                    | Some(token) => <PazeButton token />
                    | None => React.null
                    }
                  | _ => React.null
                  }}
                </SessionPaymentWrapper>
              </RenderIf>
            | AmazonPayWallet =>
              Console.log("inside PaymentRequestButtonElement AmazonPayWallet")
              <RenderIf condition={options.wallets.amazonPay === Auto}>
                <SessionPaymentWrapper type_={Wallet}>
                  {switch amazonPayToken {
                  | AmazonPayTokenOptional(optToken) =>
                    switch optToken {
                    | Some(token) => <AmazonPay walletOptions/>
                    | None => React.null
                    }
                  | _ => React.null
                  }}
                </SessionPaymentWrapper>
              </RenderIf>
            | NONE => React.null
            }
          | None => React.null
          }}
        </ReusableReactSuspense>
      </ErrorBoundary>
    })
    ->React.array}
    <Surcharge paymentMethod="wallet" paymentMethodType="google_pay" isForWallets=true />
    <WalletsSaveDetailsText paymentType=paymentMethodListValue.payment_type />
  </div>
}
