let useIsGiftCardOnlyPayment = () => {
  let giftCardInfo = Recoil.useRecoilValueFromAtom(RecoilAtomsV2.giftCardInfoAtom)

  React.useMemo2(() => {
    switch (giftCardInfo.appliedGiftCards->Array.length > 0, giftCardInfo.remainingAmount) {
    | (true, amount) => amount == 0.0
    | _ => false
    }
  }, (giftCardInfo.appliedGiftCards->Array.length, giftCardInfo.remainingAmount))
}
