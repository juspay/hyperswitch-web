type wallet =
  GPayWallet | PaypalWallet | ApplePayWallet | KlarnaWallet | SamsungPayWallet | PazeWallet | NONE
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
  | _ => NONE
  }
}

module WalletsSaveDetailsText = {
  @react.component
  let make = () => {
    open RecoilAtoms
    let {isGooglePay, isApplePay, isPaypal, isSamsungPay} = Recoil.useRecoilValueFromAtom(
      areOneClickWalletsRendered,
    )
    let {localeString} = Recoil.useRecoilValueFromAtom(configAtom)
    let isGuestCustomer = UtilityHooks.useIsGuestCustomer()
    let paymentMethodListValue = Recoil.useRecoilValueFromAtom(PaymentUtils.paymentMethodListValue)

    <RenderIf
      condition={PaymentUtils.isAppendingCustomerAcceptance(
        ~isGuestCustomer,
        ~paymentType=paymentMethodListValue.payment_type,
      ) &&
      (isGooglePay || isApplePay || isPaypal || isSamsungPay)}>
      <div
        className="SaveWalletDetailsLabel flex items-center text-xs mt-2 text-left text-gray-400">
        <Icon name="lock" size=10 className="mr-1" />
        <em> {localeString.saveWalletDetails->React.string} </em>
      </div>
    </RenderIf>
  }
}

@react.component
let make = (~sessions, ~walletOptions) => {
  open SessionsType
  open PayPalHelpers
  let dict = sessions->Utils.getDictFromJson
  let paymentMethodListValue = Recoil.useRecoilValueFromAtom(PaymentUtils.paymentMethodListValue)
  let paymentMethodListValueV2 = Recoil.useRecoilValueFromAtom(
    RecoilAtomsV2.paymentMethodListValueV2,
  )

  let sessionObj = React.useMemo(() => itemToObjMapper(dict, Others), [dict])

  let paypalPaymentMethodDataV1 = usePaymentMethodData(~paymentMethodListValue, ~sessionObj)
  let paypalPaymentMethodDataV2 = usePaymentMethodDataV2(~paymentMethodListValueV2, ~sessionObj)

  let trustPayScriptStatus = Recoil.useRecoilValueFromAtom(RecoilAtoms.trustPayScriptStatus)
  let isApplePayReady = Recoil.useRecoilValueFromAtom(RecoilAtoms.isApplePayReady)
  let (
    isApplePayDelayedSessionFlow,
    isGooglePayDelayedSessionFlow,
  ) = ThirdPartyFlowCheck.useIsThirdPartyFlow()
  let setIsShowOrPayUsingWhileLoading = Recoil.useSetRecoilState(
    RecoilAtoms.isShowOrPayUsingWhileLoading,
  )

  let {paypalToken, isPaypalSDKFlow, isPaypalRedirectFlow} = switch GlobalVars.sdkVersion {
  | V1 => paypalPaymentMethodDataV1
  | V2 => paypalPaymentMethodDataV2
  }

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

  React.useEffect(() => {
    let isTrustPayScriptLoading = !trustPayScriptStatus.isLoaded && !trustPayScriptStatus.isFailed
    let isApplePayThirdPartyLoading =
      isApplePayDelayedSessionFlow && isApplePayReady && isTrustPayScriptLoading

    let isGooglePayThirdPartyLoading = isGooglePayDelayedSessionFlow && isTrustPayScriptLoading
    if isGooglePayThirdPartyLoading || isApplePayThirdPartyLoading {
      setIsShowOrPayUsingWhileLoading(_ => true)
    } else {
      setIsShowOrPayUsingWhileLoading(_ => false)
    }
    None
  }, (
    isGooglePayDelayedSessionFlow,
    isApplePayDelayedSessionFlow,
    isApplePayReady,
    trustPayScriptStatus,
  ))

  let {isKlarnaSDKFlow, isKlarnaCheckoutFlow} = KlarnaHelpers.usePaymentMethodExperience(
    ~paymentMethodListValue,
    ~sessionObj,
  )

  let klarnaTokenObj = getPaymentSessionObj(sessionObj.sessionsToken, Klarna)
  let pazeTokenObj = getPaymentSessionObj(sessionObj.sessionsToken, Paze)

  let {clientSecret} = Recoil.useRecoilValueFromAtom(RecoilAtoms.keys)
  let options = Recoil.useRecoilValueFromAtom(RecoilAtoms.optionAtom)

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
                    />
                  | _ => <GPayLazy sessionObj=optToken thirdPartySessionObj=None walletOptions />
                  }
                | _ => React.null
                }}
              </SessionPaymentWrapper>
            | PaypalWallet =>
              <SessionPaymentWrapper type_={Wallet}>
                {switch paypalToken {
                | OtherTokenOptional(optToken) =>
                  switch (optToken, isPaypalSDKFlow, isPaypalRedirectFlow) {
                  | (Some(token), true, _) => <PaypalSDKLazy sessionObj=token />
                  | (_, _, true) => <PayPalLazy walletOptions />
                  | _ => React.null
                  }
                | _ =>
                  <RenderIf condition={isPaypalRedirectFlow}>
                    <PayPalLazy walletOptions />
                  </RenderIf>
                }}
              </SessionPaymentWrapper>
            | ApplePayWallet =>
              switch applePayToken {
              | ApplePayTokenOptional(optToken) =>
                <ApplePayLazy sessionObj=optToken walletOptions />
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
            | NONE => React.null
            }
          | None => React.null
          }}
        </ReusableReactSuspense>
      </ErrorBoundary>
    })
    ->React.array}
    <Surcharge paymentMethod="wallet" paymentMethodType="google_pay" isForWallets=true />
    <WalletsSaveDetailsText />
  </div>
}
