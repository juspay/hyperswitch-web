type appliedGiftCard = {
  giftCardType: string,
  maskedNumber: string,
  balance: float,
  currency: string,
  id: string,
  requiredFieldsBody: Dict.t<JSON.t>,
}

type giftCardInfo = {
  appliedGiftCards: array<appliedGiftCard>,
  remainingAmount: float,
}

let defaultAppliedGiftCard: appliedGiftCard = {
  giftCardType: "",
  maskedNumber: "",
  balance: 0.0,
  currency: "",
  id: "",
  requiredFieldsBody: Dict.make(),
}

let defaultGiftCardInfo: giftCardInfo = {
  appliedGiftCards: [],
  remainingAmount: 0.0,
}
