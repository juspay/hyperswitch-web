@react.component
let make = (~paymentType) => {
  let sessionsObj = Recoil.useRecoilValueFromAtom(RecoilAtoms.sessions)
  let methodslist = Recoil.useRecoilValueFromAtom(RecoilAtoms.paymentMethodList)
  let (sessions, setSessions) = React.useState(_ => Dict.make()->JSON.Encode.object)
  let (walletOptions, setWalletOptions) = React.useState(_ => [])

  let (paymentMethodListValue, setPaymentMethodListValue) = Recoil.useRecoilState(
    PaymentUtils.paymentMethodListValue,
  )

  let (walletList, _, _) = PaymentUtils.useGetPaymentMethodList(
    ~paymentMethodListValue,
    ~paymentOptions=[],
    ~paymentType,
  )

  React.useEffect(() => {
    switch methodslist {
    | Loaded(paymentlist) =>
      let plist = paymentlist->Utils.getDictFromJson->PaymentMethodsRecord.itemToObjMapper
      setWalletOptions(_ => walletList)
      setPaymentMethodListValue(_ => plist)
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
      <ErrorBoundary key="payment_request_buttons_all" level={ErrorBoundary.RequestButton}>
        <PaymentRequestButtonElement sessions walletOptions />
      </ErrorBoundary>
    </div>
  </RenderIf>
}
