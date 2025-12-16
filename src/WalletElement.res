@react.component
let make = (~paymentType) => {
  let sessionsObj = Recoil.useRecoilValueFromAtom(RecoilAtoms.sessions)
  let methodslist = Recoil.useRecoilValueFromAtom(RecoilAtoms.paymentMethodList)
  let (sessions, setSessions) = React.useState(_ => Dict.make()->JSON.Encode.object)
  let (walletOptions, setWalletOptions) = React.useState(_ => [])
  let {publishableKey} = Recoil.useRecoilValueFromAtom(RecoilAtoms.keys)

  let setPaymentMethodListValue = Recoil.useSetRecoilState(PaymentUtils.paymentMethodListValue)

  let (walletList, _, _) = PaymentUtils.useGetPaymentMethodList(
    ~paymentOptions=[],
    ~paymentType,
    ~sessions,
  )

  React.useEffect(() => {
    switch methodslist {
    | Loaded(paymentlist) =>
      let pList = paymentlist->Utils.getDictFromJson->PaymentMethodsRecord.itemToObjMapper
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
