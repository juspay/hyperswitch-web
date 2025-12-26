type appliedGiftCard = {
  giftCardType: string,
  maskedNumber: string,
  balance: float,
  currency: string,
  id: string,
  requiredFieldsBody: Dict.t<Core__JSON.t>,
}

type giftCardInfo = {
  appliedGiftCards: array<appliedGiftCard>,
  remainingAmount: float,
}

let defaultGiftCardInfo: giftCardInfo = {
  appliedGiftCards: [],
  remainingAmount: 0.0,
}
