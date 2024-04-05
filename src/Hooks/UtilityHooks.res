let useIsGuestCustomer = () => {
  let {customerPaymentMethods} = RecoilAtoms.optionAtom->Recoil.useRecoilValueFromAtom

  React.useMemo(() => {
    switch customerPaymentMethods {
    | LoadedSavedCards(_, false)
    | NoResult(false) => false
    | _ => true
    }
  }, [customerPaymentMethods])
}

let useHandlePostMessages = (~complete, ~empty, ~paymentType, ~savedMethod=false) => {
  let loggerState = Recoil.useRecoilValueFromAtom(RecoilAtoms.loggerAtom)
  let setIsPayNowButtonDisable = RecoilAtoms.payNowButtonDisable->Recoil.useSetRecoilState

  React.useEffect(() => {
    let isCompletelyFilled = complete && paymentType !== ""
    setIsPayNowButtonDisable(_ => !isCompletelyFilled)
    Utils.handlePostMessageEvents(~complete, ~empty, ~paymentType, ~loggerState, ~savedMethod)
    None
  }, (complete, empty, paymentType))
}
