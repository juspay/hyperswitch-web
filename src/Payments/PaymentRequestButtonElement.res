type wallet = GPayWallet | PaypalWallet | ApplePayWallet | NONE
let paymentMode = str => {
  switch str {
  | "gpay"
  | "google_pay" =>
    GPayWallet
  | "paypal" => PaypalWallet
  | "applepay"
  | "apple_pay" =>
    ApplePayWallet
  | _ => NONE
  }
}

module WalletsSaveDetailsText = {
  @react.component
  let make = () => {
    let {localeString} = Recoil.useRecoilValueFromAtom(RecoilAtoms.configAtom)
    <div className="flex items-center text-xs mt-2">
      <Icon name="lock" size=10 className="mr-1" />
      <em className="text-left text-gray-400"> {localeString.saveWalletDetails->React.string} </em>
    </div>
  }
}

@react.component
let make = (~sessions, ~walletOptions, ~list: PaymentMethodsRecord.list) => {
  open SessionsType
  let dict = sessions->Utils.getDictFromJson

  let sessionObj = React.useMemo1(() => itemToObjMapper(dict, Others), [dict])
  let paypalToken = React.useMemo1(
    () => getPaymentSessionObj(sessionObj.sessionsToken, Paypal),
    [sessionObj],
  )
  let gPayToken = getPaymentSessionObj(sessionObj.sessionsToken, Gpay)
  let applePaySessionObj = itemToObjMapper(dict, ApplePayObject)
  let applePayToken = getPaymentSessionObj(applePaySessionObj.sessionsToken, ApplePay)

  let googlePayThirdPartySessionObj = itemToObjMapper(dict, GooglePayThirdPartyObject)
  let googlePayThirdPartyToken = getPaymentSessionObj(
    googlePayThirdPartySessionObj.sessionsToken,
    Gpay,
  )
  let {isGooglePay, isApplePay, isPaypal} = Recoil.useRecoilValueFromAtom(
    RecoilAtoms.areOneClickWalletsRendered,
  )
  let {customerPaymentMethods} = Recoil.useRecoilValueFromAtom(RecoilAtoms.optionAtom)

  let isGuestCustomer = React.useMemo1(() => {
    switch customerPaymentMethods {
    | LoadedSavedCards(_, false)
    | NoResult(false) => false
    | _ => true
    }
  }, [customerPaymentMethods])

  let {clientSecret} = Recoil.useRecoilValueFromAtom(RecoilAtoms.keys)

  <div className="flex flex-col gap-2 h-auto w-full">
    {walletOptions
    ->Js.Array2.mapi((item, i) => {
      <ErrorBoundary
        level={ErrorBoundary.RequestButton} key={`${item}-${i->Belt.Int.toString}-request-button`}>
        <React.Suspense fallback={<WalletShimmer />} key={i->Belt.Int.toString}>
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
                      paymentType=NONE
                      sessionObj=optToken
                      list
                      thirdPartySessionObj=googlePayThirdPartyOptToken
                      walletOptions
                    />
                  | _ =>
                    <GPayLazy
                      paymentType=NONE
                      sessionObj=optToken
                      list
                      thirdPartySessionObj=None
                      walletOptions
                    />
                  }
                | _ => React.null
                }}
              </SessionPaymentWrapper>
            | PaypalWallet =>
              <SessionPaymentWrapper type_={Wallet}>
                {switch paypalToken {
                | OtherTokenOptional(optToken) =>
                  switch optToken {
                  | Some(token) => <PaypalSDKLazy sessionObj=token list />
                  | None => <PayPalLazy list />
                  }
                | _ => <PayPalLazy list />
                }}
              </SessionPaymentWrapper>
            | ApplePayWallet =>
              switch applePayToken {
              | ApplePayTokenOptional(optToken) =>
                <ApplePayLazy sessionObj=optToken list paymentType=NONE walletOptions />
              | _ => React.null
              }

            | NONE => React.null
            }
          | None => React.null
          }}
        </React.Suspense>
      </ErrorBoundary>
    })
    ->React.array}
    <Surcharge list paymentMethod="wallet" paymentMethodType="google_pay" isForWallets=true />
    <RenderIf
      condition={!isGuestCustomer &&
      (list.payment_type === "new_mandate" || list.payment_type === "setup_mandate") &&
      (isGooglePay || isApplePay || isPaypal)}>
      <WalletsSaveDetailsText />
    </RenderIf>
  </div>
}
