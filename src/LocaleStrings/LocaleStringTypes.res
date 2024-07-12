type locale = EN | HE | FR | EN_GB | AR | JA | DE | FR_BE | ES | CA | PT | IT | PL | NL | SV | RU

type localeStrings = {
  locale: string,
  cardNumberLabel: string,
  localeDirection: string,
  inValidCardErrorText: string,
  inCompleteCVCErrorText: string,
  inCompleteExpiryErrorText: string,
  pastExpiryErrorText: string,
  poweredBy: string,
  validThruText: string,
  sortCodeText: string,
  cvcTextLabel: string,
  emailLabel: string,
  emailEmptyText: string,
  emailInvalidText: string,
  accountNumberText: string,
  fullNameLabel: string,
  line1Label: string,
  line1Placeholder: string,
  line1EmptyText: string,
  line2Label: string,
  line2Placeholder: string,
  line2EmptyText: string,
  cityLabel: string,
  cityEmptyText: string,
  postalCodeLabel: string,
  postalCodeEmptyText: string,
  postalCodeInvalidText: string,
  stateLabel: string,
  stateEmptyText: string,
  fullNamePlaceholder: string,
  countryLabel: string,
  currencyLabel: string,
  bankLabel: string,
  redirectText: string,
  bankDetailsText: string,
  orPayUsing: string,
  addNewCard: string,
  useExisitingSavedCards: string,
  saveCardDetails: string,
  addBankAccount: string,
  achBankDebitTerms: string => string,
  sepaDebitTerms: string => string,
  becsDebitTerms: string,
  cardTerms: string => string,
  payNowButton: string,
  cardNumberEmptyText: string,
  cardExpiryDateEmptyText: string,
  cvcNumberEmptyText: string,
  enterFieldsText: string,
  enterValidDetailsText: string,
  selectPaymentMethodText: string,
  card: string,
  surchargeMsgAmount: (string, string) => React.element,
  surchargeMsgAmountForCard: (string, string) => React.element,
  surchargeMsgAmountForOneClickWallets: string,
  billingNameLabel: string,
  billingNamePlaceholder: string,
  cardHolderName: string,
  on: string,
  \"and": string,
  nameEmptyText: string => string,
  completeNameEmptyText: string => string,
  billingDetailsText: string,
  socialSecurityNumberLabel: string,
  saveWalletDetails: string,
  morePaymentMethods: string,
  useExistingPaymentMethods: string,
  cardNickname: string,
  nicknamePlaceholder: string,
  cardExpiredText: string,
  cardHeader: string,
  cardBrandConfiguredErrorText: string => string,
  currencyNetwork: string,
  expiryPlaceholder: string,
  dateOfBirth: string,
  vpaIdLabel: string,
  vpaIdEmptyText: string,
  vpaIdInvalidText: string,
  dateofBirthRequiredText: string,
  dateOfBirthInvalidText: string,
}
