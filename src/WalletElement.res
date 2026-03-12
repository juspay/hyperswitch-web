@react.component
let make = (~paymentType) => {
  let sessionsObj = Jotai.useAtomValue(JotaiAtoms.sessions)
  let methodslist = Jotai.useAtomValue(JotaiAtoms.paymentMethodList)
  let (sessions, setSessions) = React.useState(_ => Dict.make()->JSON.Encode.object)
  let (walletOptions, setWalletOptions) = React.useState(_ => [])
  let {publishableKey} = Jotai.useAtomValue(JotaiAtoms.keys)

  let setPaymentMethodListValue = Jotai.useSetAtom(PaymentUtils.paymentMethodListValue)

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
