@react.component
let make = (~paymentType) => {
  let sessionsObj = Recoil.useRecoilValueFromAtom(RecoilAtoms.sessions)
  let methodslist = Recoil.useRecoilValueFromAtom(RecoilAtoms.paymentMethodList)
  let (sessions, setSessions) = React.useState(_ => Dict.make()->JSON.Encode.object)
  let (walletOptions, setWalletOptions) = React.useState(_ => [])
  let {publishableKey} = Recoil.useRecoilValueFromAtom(RecoilAtoms.keys)

  let setPaymentMethodListValue = Recoil.useSetRecoilState(PaymentUtils.paymentMethodListValue)

  let areAllApplePayRequiredFieldsPrefilled = DynamicFieldsUtils.useAreWalletRequiredFieldsPrefilled(
    ~paymentMethodType="apple_pay",
  )
  let areAllGooglePayRequiredFieldsPrefilled = DynamicFieldsUtils.useAreWalletRequiredFieldsPrefilled(
    ~paymentMethodType="google_pay",
  )
  let areAllPaypalRequiredFieldsPrefilled = DynamicFieldsUtils.useAreWalletRequiredFieldsPrefilled(
    ~paymentMethodType="paypal",
  )
  let (walletList, _, _) = PaymentUtils.useGetPaymentMethodList(
    ~paymentType,
    ~sessions,
    ~areAllApplePayRequiredFieldsPrefilled,
    ~areAllGooglePayRequiredFieldsPrefilled,
    ~areAllPaypalRequiredFieldsPrefilled,
  )

  React.useEffect(() => {
    switch methodslist {
    | Loaded(paymentlist) =>
      let pList =
        paymentlist->Utils.getDictFromJson->PaymentMethodsRecord.itemToObjMapperFromClientList
      setWalletOptions(_ => walletList)
      setPaymentMethodListValue(_ => pList)
    | _ => ()
    }
    None
  }, (methodslist, walletList))
  React.useEffect(() => {
    switch sessionsObj {
    | Loaded(ssn) => setSessions(_ => ssn)
    | _ => ()
    }
    None
  }, [sessionsObj])

  <RenderIf condition={walletOptions->Array.length > 0}>
    <div className="flex flex-col place-items-center">
      <ErrorBoundary
        key="payment_request_buttons_all"
        level={ErrorBoundary.RequestButton}
        componentName="WalletElement"
        publishableKey>
        <PaymentRequestButtonElement sessions walletOptions />
      </ErrorBoundary>
    </div>
  </RenderIf>
}
