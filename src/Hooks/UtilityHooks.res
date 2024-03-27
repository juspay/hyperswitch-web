let useIsGuestCustomer = () => {
  let {customerPaymentMethods} = RecoilAtoms.optionAtom->Recoil.useRecoilValueFromAtom

  React.useMemo1(() => {
    switch customerPaymentMethods {
    | LoadedSavedCards(_, false)
    | NoResult(false) => false
    | _ => true
    }
  }, [customerPaymentMethods])
}

let useHandlePostMessages = (~complete, ~empty, ~paymentType) => {
  let loggerState = Recoil.useRecoilValueFromAtom(RecoilAtoms.loggerAtom)
  let setIsPayNowButtonDisable = RecoilAtoms.payNowButtonDisable->Recoil.useSetRecoilState

  React.useEffect(() => {
    let isCompletelyFilled = complete && paymentType !== ""
    setIsPayNowButtonDisable(_ => !isCompletelyFilled)
    Utils.handlePostMessageEvents(~complete, ~empty, ~paymentType, ~loggerState)
    None
  }, (complete, empty))
}
