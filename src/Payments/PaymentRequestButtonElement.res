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
@react.component
let make = (~sessions, ~walletOptions, ~list: PaymentMethodsRecord.list) => {
  open SessionsType
  let dict = sessions->Utils.getDictFromJson

  let sessionObj = itemToObjMapper(dict, Others)
  let paypalToken = getPaymentSessionObj(sessionObj.sessionsToken, Paypal)
  let gPayToken = getPaymentSessionObj(sessionObj.sessionsToken, Gpay)
  let applePaySessionObj = itemToObjMapper(dict, ApplePayObject)
  let applePayToken = getPaymentSessionObj(applePaySessionObj.sessionsToken, ApplePay)

  let googlePayThirdPartySessionObj = itemToObjMapper(dict, GooglePayThirdPartyObject)
  let googlePayThirdPartyToken = getPaymentSessionObj(
    googlePayThirdPartySessionObj.sessionsToken,
    Gpay,
  )

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
                      sessionObj=optToken list thirdPartySessionObj=googlePayThirdPartyOptToken
                    />
                  | _ => <GPayLazy sessionObj=optToken list thirdPartySessionObj=None />
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
              | ApplePayTokenOptional(optToken) => <ApplePayLazy sessionObj=optToken list />
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
  </div>
}
