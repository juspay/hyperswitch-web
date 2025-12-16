let useIsGiftCardOnlyPayment = () => {
  let appliedGiftCards = Recoil.useRecoilValueFromAtom(RecoilAtomsV2.appliedGiftCardsAtom)
  let remainingAmount = Recoil.useRecoilValueFromAtom(RecoilAtomsV2.remainingAmountAtom)

  React.useMemo2(() => {
    switch (appliedGiftCards->Array.length > 0, remainingAmount) {
    | (true, amount) => amount == 0.0
    | _ => false
    }
  }, (appliedGiftCards->Array.length, remainingAmount))
}
