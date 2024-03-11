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
