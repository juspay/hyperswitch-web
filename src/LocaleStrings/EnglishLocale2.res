let localeStrings: LocaleStringTypes.localeStrings = {
  locale: "en",
  localeDirection: "ltr",
  cardNumberLabel: "Card Number",
  inValidCardErrorText: "Card number is invalid.",
  inCompleteCVCErrorText: "Your card's security code is incomplete.",
  inCompleteExpiryErrorText: "Your card's expiration date is incomplete.",
  pastExpiryErrorText: "Your card's expiration year is in the past.",
  poweredBy: "Powered By Hyperswitch",
  validThruText: "Expiry",
  sortCodeText: "Sort Code",
  cvcTextLabel: "CVC",
  line1Label: "Address line 1",
  line1Placeholder: "Street address",
  line1EmptyText: "Address line 1 cannot be empty",
  line2Label: "Address line 2",
  line2Placeholder: "Apt., unit number, etc (optional)",
  line2EmptyText: "Address line 2 cannot be empty",
  cityLabel: "City",
  cityEmptyText: "City cannot be empty",
  postalCodeLabel: "Postal Code",
  postalCodeEmptyText: "Postal code cannot be empty",
  postalCodeInvalidText: "Invalid postal code",
  stateLabel: "State",
  stateEmptyText: "State cannot be empty",
  accountNumberText: "Account Number",
  emailLabel: "Email",
  emailEmptyText: "Email cannot be empty",
  emailInvalidText: "Invalid email address",
  fullNameLabel: "Full name",
  fullNamePlaceholder: "First and last name",
  countryLabel: "Country",
  currencyLabel: "Currency",
  bankLabel: "Select Bank",
  redirectText: "After submitting your order, you will be redirected to securely complete your purchase.",
  bankDetailsText: "After submitting these details, you will get bank account information to make payment. Please make sure to take a note of it.",
  orPayUsing: "Or pay using",
  addNewCard: "Add credit/debit card",
  useExisitingSavedCards: "Use saved debit/credit cards",
  saveCardDetails: "Save card details",
  addBankAccount: "Add bank account",
  achBankDebitTerms: _ =>
    `Your ACH Debit Authorization will be set up now, but we'll confirm the amount and let you know before future payments are taken.`,
  sepaDebitTerms: str =>
    `By providing your payment information and confirming this payment, you authorise (A) ${str} and Hyperswitch, our payment service provider and/or PPRO, its local service provider, to send instructions to your bank to debit your account and (B) your bank to debit your account in accordance with those instructions. As part of your rights, you are entitled to a refund from your bank under the terms and conditions of your agreement with your bank. A refund must be claimed within 8 weeks starting from the date on which your account was debited. Your rights are explained in a statement that you can obtain from your bank. You agree to receive notifications for future debits up to 2 days before they occur.`,
  becsDebitTerms: `By providing your bank account details and confirming this payment, you agree to this Direct Debit Request and the Direct Debit Request service agreement and authorise Hyperswitch Payments Australia Pty Ltd ACN 160 180 343 Direct Debit User ID number 507156 (“Hyperswitch”) to debit your account through the Bulk Electronic Clearing System (BECS) on behalf of Hyperswitch Payment Widget (the "Merchant") for any amounts separately communicated to you by the Merchant. You certify that you are either an account holder or an authorised signatory on the account listed above.`,
  cardTerms: str =>
    `By providing your card information, you allow ${str} to charge your card for future payments in accordance with their terms.`,
  payNowButton: "Pay Now",
  cardNumberEmptyText: "Card Number cannot be empty",
  cardExpiryDateEmptyText: "Card expiry date cannot be empty",
  cvcNumberEmptyText: "CVC Number cannot be empty",
  enterFieldsText: "Please enter all fields",
  enterValidDetailsText: "Please enter valid details",
  card: "Card",
  surchargeMsgAmount: (currency, str) => <>
    {React.string(`A surcharge amount of${Utils.nbsp}`)}
    <strong> {React.string(`${currency} ${str}`)} </strong>
    {React.string({`${Utils.nbsp}will be applied for this transaction`})}
  </>,
  surchargeMsgAmountForCard: (currency, str) => <>
    {React.string(`A surcharge amount of upto${Utils.nbsp}`)}
    <strong> {React.string(`${currency} ${str}`)} </strong>
    {React.string(`${Utils.nbsp}will be applied for this transaction`)}
  </>,
  surchargeMsgAmountForOneClickWallets: "Additional fee applicable",
  billingNameLabel: "Billing name",
  billingNamePlaceholder: "First and last name",
  cardHolderName: "Card Holder Name",
  on: "on",
  \"and": "and",
  nameEmptyText: str => `Please provide your ${str}`,
  completeNameEmptyText: str => `Please provide your complete ${str}`,
  billingDetailsText: "Billing Details",
  socialSecurityNumberLabel: "Social Security Number",
  saveWalletDetails: "Wallets details will be saved upon selection",
  morePaymentMethods: "More payment methods",
  useExistingPaymentMethods: "Use saved payment methods",
  nicknameLabel: "Card Nickname",
  nicknamePlaceholder: "Card Nickname (Optional)",
}
