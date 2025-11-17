let useIsGiftCardOnlyPayment = () => {
  let appliedGiftCards = Recoil.useRecoilValueFromAtom(RecoilAtomsV2.appliedGiftCardsAtom)
  let remainingAmount = Recoil.useRecoilValueFromAtom(RecoilAtomsV2.remainingAmountAtom)

  React.useMemo2(() => {
    switch (appliedGiftCards->Array.length > 0, remainingAmount) {
    | (true, Some(amount)) if amount == 0.0 => true
    | _ => false
    }
  }, (appliedGiftCards->Array.length, remainingAmount))
}
