let useIsGiftCardOnlyPayment = () => {
  let giftCardInfo = Recoil.useRecoilValueFromAtom(RecoilAtomsV2.giftCardInfoAtom)
  giftCardInfo.appliedGiftCards->Array.length > 0 && giftCardInfo.remainingAmount == 0.0
}
