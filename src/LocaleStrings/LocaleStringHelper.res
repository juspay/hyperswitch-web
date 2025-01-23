open LocaleStringTypes

let defaultLocale: localeStringsWebAndroid = {
  locale: "en",
  localeDirection: "ltr",
  cardNumberLabel: "Card Number",
  cardDetailsLabel: "Card Details",
  inValidCardErrorText: "Card number is invalid.",
  inCompleteCVCErrorText: "Your card's security code is incomplete.",
  inValidCVCErrorText: "Your card's security code is invalid.",
  inCompleteExpiryErrorText: "Your card's expiration date is incomplete.",
  inValidExpiryErrorText: "Your card's expiration date is invalid.",
  pastExpiryErrorText: "Your card's expiration date is invalid",
  poweredBy: "Powered By Hyperswitch",
  validThruText: "Expiry",
  sortCodeText: "Sort Code",
  accountNumberText: "Account Number",
  cvcTextLabel: "CVC",
  emailLabel: "Email",
  emailInvalidText: "Invalid email address",
  emailEmptyText: "Email cannot be empty",
  line1Label: "Address line 1",
  line1Placeholder: "Street address",
  line1EmptyText: "Address line 1 cannot be empty",
  line2Label: "Address line 2",
  line2Placeholder: "Apt., unit number, etc (optional)",
  cityLabel: "City",
  cityEmptyText: "City cannot be empty",
  postalCodeLabel: "Postal Code",
  postalCodeEmptyText: "Postal code cannot be empty",
  stateLabel: "State",
  fullNameLabel: "Full name",
  fullNamePlaceholder: "First and last name",
  countryLabel: "Country",
  currencyLabel: "Currency",
  bankLabel: "Select Bank",
  redirectText: "After submitting your order, you will be redirected to securely complete your purchase.",
  bankDetailsText: "After submitting these details, you will get bank account information to make payment. Please make sure to take a note of it.",
  orPayUsing: "Or pay using",
  addNewCard: "Add credit/debit card",
  useExisitingSavedCards: "Use saved payment methods",
  saveCardDetails: "Save card details",
  addBankAccount: "Add bank account",
  payNowButton: "Pay Now",
  cardNumberEmptyText: "Card Number cannot be empty",
  cardExpiryDateEmptyText: "Card expiry date cannot be empty",
  cvcNumberEmptyText: "CVC Number cannot be empty",
  enterFieldsText: "Please enter all fields",
  enterValidDetailsText: "Please enter valid details",
  card: "Card",
  billingNameLabel: "Billing name",
  cardHolderName: "Card Holder Name",
  cardNickname: "Card Nickname",
  billingNamePlaceholder: "First and last name",
  firstName: "First name",
  lastName: "Last name",
  billingDetails: "Billing Details",
  requiredText: "Required",
  cardHolderNameRequiredText: "Card Holder's name required",
  invalidDigitsCardHolderNameError: "Card Holder's name cannot have digits",
  lastNameRequiredText: "Last Name Required",
  nickNameLengthExceedError: "Nickname cannot exceed 12 characters",
  invalidDigitsNickNameError: "Nickname cannot have more than 2 digits",
  cardExpiresText: "expires",
  addPaymentMethodLabel: "Add new payment method",
  walletDisclaimer: "Wallet details will be saved upon selection",
  deletePaymentMethod: "Delete",
  // newly added list
  enterValidCardNumberErrorText: "Please enter a valid card number",
  line2EmptyText: "Address line 2 cannot be empty",
  postalCodeInvalidText: "Invalid postal code",
  stateEmptyText: "State cannot be empty",
  ibanEmptyText: "IBAN cannot be empty",
  selectPaymentMethodText: "Please select a payment method and try again",
  achBankDebitTermsPart1: "Your ACH Debit Authorization will be set up now, but we'll confirm the amount and let you know before future payments are taken.",
  achBankDebitTermsPart2: "",
  sepaDebitTermsPart1: "By providing your payment information and confirming to this mandate form, you authorise (A) ",
  sepaDebitTermsPart2: ", the Creditor and/or our payment service provider(s) to send instructions to your bank to debit your account and (B) your bank to debit your account in accordance with the instructions from ",
  sepaDebitTermsPart3: ". As part of your rights, you are entitled to a refund from your bank under the terms and conditions of your agreement with your bank. A refund must be claimed within 8 weeks starting from the date on which your account was debited. Your rights are explained in a statement that you can obtain from your bank.",
  becsDebitTerms: `By providing your bank account details and confirming this payment, you agree to this Direct Debit Request and the Direct Debit Request service agreement and authorise Hyperswitch Payments Australia Pty Ltd ACN 160 180 343 Direct Debit User ID number 507156 (“Hyperswitch”) to debit your account through the Bulk Electronic Clearing System (BECS) on behalf of Hyperswitch Payment Widget (the "Merchant") for any amounts separately communicated to you by the Merchant. You certify that you are either an account holder or an authorised signatory on the account listed above.`,
  cardTermsPart1: `By providing your card information, you allow `,
  cardTermsPart2: ` to charge your card for future payments in accordance with their terms.`,
  surchargeMsgAmountPart1: "A surcharge amount of ",
  surchargeMsgAmountPart2: " will be applied for this transaction",
  surchargeMsgAmountForCardPart1: "A surcharge amount of upto ",
  surchargeMsgAmountForCardPart2: " will be applied for this transaction",
  surchargeMsgAmountForOneClickWallets: "Additional fee applicable",
  on: "on",
  \"and": "and",
  nameEmptyText: "Please provide your",
  completeNameEmptyText: "Please provide your complete ",
  billingDetailsText: "Billing Details",
  socialSecurityNumberLabel: "Social Security Number",
  saveWalletDetails: "Wallet details will be saved upon selection",
  morePaymentMethods: "More payment methods",
  useExisitingSavedCardsWeb: "Use saved debit/credit cards",
  useExistingPaymentMethods: "Use saved payment methods",
  nicknamePlaceholder: "Card Nickname (Optional)",
  cardExpiredText: "This card has expired",
  cardHeader: "Card information",
  cardBrandConfiguredErrorText: "is not supported at the moment",
  currencyNetwork: "Currency Networks",
  expiryPlaceholder: "MM / YY",
  dateOfBirth: "Date of Birth",
  vpaIdLabel: "Vpa Id",
  vpaIdEmptyText: "Vpa Id cannot be empty",
  vpaIdInvalidText: "Invalid Vpa Id address",
  dateofBirthRequiredText: "Date of birth is required",
  dateOfBirthInvalidText: "Age should be greater than or equal to 18 years",
  dateOfBirthPlaceholderText: "Enter Date of Birth",
  formFundsInfoText: "Funds will be credited to this account",
  formFundsCreditInfoTextPart1: "Your funds will be credited in the selected ",
  formFundsCreditInfoTextPart2: ".",
  formEditText: "Edit",
  formSaveText: "Save",
  formSubmitText: "Submit",
  formSubmittingText: "Submitting",
  formSubheaderBillingDetailsText: "Enter your billing address",
  formSubheaderCardText: "Your card details",
  formSubheaderAccountTextPart1: "Your",
  formSubheaderAccountTextPart2: "",
  formHeaderReviewText: "Review",
  formHeaderReviewTabLayoutTextPart1: "Review your",
  formHeaderReviewTabLayoutTextPart2: "details",
  formHeaderBankTextPart1: "Enter",
  formHeaderBankTextPart2: "bank details",
  formHeaderWalletTextPart1: "Enter",
  formHeaderWalletTextPart2: "wallet details",
  formHeaderEnterCardText: "Enter card details",
  formHeaderSelectBankText: "Select a bank method",
  formHeaderSelectWalletText: "Select a wallet",
  formHeaderSelectAccountText: "Select an account for payouts",
  formFieldACHRoutingNumberLabel: "Routing Number",
  formFieldSepaIbanLabel: "IBAN",
  formFieldSepaBicLabel: "BIC (Optional)",
  formFieldPixIdLabel: "Pix ID",
  formFieldBankAccountNumberLabel: "Bank Account Number",
  formFieldPhoneNumberLabel: "Phone Number",
  formFieldCountryCodeLabel: "Country Code (Optional)",
  formFieldBankNameLabel: "Bank Name",
  formFieldBankCityLabel: "Bank City",
  formFieldCardHoldernamePlaceholder: "Your Name",
  formFieldBankNamePlaceholder: "Bank Name",
  formFieldBankCityPlaceholder: "Bank City",
  formFieldEmailPlaceholder: "Your Email",
  formFieldPhoneNumberPlaceholder: "Your Phone",
  formFieldInvalidRoutingNumber: "Routing number is invalid",
  infoCardRefId: "Ref Id",
  infoCardErrCode: "Error Code",
  infoCardErrMsg: "Error Message",
  infoCardErrReason: "Reason",
  linkRedirectionTextPart1: "Redirecting in ",
  linkRedirectionTextPart2: " seconds ...",
  linkExpiryInfoPart1: "Link expires on: ",
  linkExpiryInfoPart2: "",
  payoutFromTextPart1: "Payout from ",
  payoutFromTextPart2: "",
  payoutStatusFailedMessage: "Failed to process your payout. Please check with your provider for more details.",
  payoutStatusPendingMessage: "Your payout should be processed within 2-3 business days.",
  payoutStatusSuccessMessage: "Your payout was successful. Funds were deposited in your selected payment mode.",
  payoutStatusFailedText: "Payout Failed",
  payoutStatusPendingText: "Payout Processing",
  payoutStatusSuccessText: "Payout Successful",
  pixCNPJInvalidText: "Invalid Pix CNPJ",
  pixCNPJEmptyText: "Pix CNPJ cannot be empty",
  pixCNPJLabel: "Pix CNPJ",
  pixCNPJPlaceholder: "Enter Pix CNPJ",
  pixCPFInvalidText: "Invalid Pix CPF",
  pixCPFEmptyText: "Pix CPF cannot be empty",
  pixCPFLabel: "Pix CPF",
  pixCPFPlaceholder: "Enter Pix CPF",
  pixKeyEmptyText: "Pix key cannot be empty",
  pixKeyPlaceholder: "Enter Pix key",
  pixKeyLabel: "Pix key",
  invalidCardHolderNameError: "Card Holder's name cannot have digits",
  invalidNickNameError: "Nickname cannot have more than 2 digits",
}

let mapLocalStringToTypeLocale = val => {
  switch val {
  | "he" => HE
  | "fr" => FR
  | "en-GB" => EN_GB
  | "ar" => AR
  | "ja" => JA
  | "de" => DE
  | "fr-BE" => FR_BE
  | "es" => ES
  | "ca" => CA
  | "pt" => PT
  | "it" => IT
  | "pl" => PL
  | "nl" => NL
  | "sv" => SV
  | "ru" => RU
  | "zh" => ZH
  | "zh-Hant" => ZH_HANT
  | "en"
  | _ =>
    EN
  }
}

let getLocaleStrings: Js.Json.t => localeStringsWebAndroid = data => {
  switch data->Js.Json.decodeObject {
  | Some(res) => {
      locale: Utils.getString(res, "locale", defaultLocale.locale),
      cardDetailsLabel: Utils.getString(res, "cardDetailsLabel", defaultLocale.cardDetailsLabel),
      cardNumberLabel: Utils.getString(res, "cardNumberLabel", defaultLocale.cardNumberLabel),
      localeDirection: Utils.getString(res, "localeDirection", defaultLocale.localeDirection),
      inValidCardErrorText: Utils.getString(
        res,
        "inValidCardErrorText",
        defaultLocale.inValidCardErrorText,
      ),
      inCompleteCVCErrorText: Utils.getString(
        res,
        "inCompleteCVCErrorText",
        defaultLocale.inCompleteCVCErrorText,
      ),
      inValidCVCErrorText: Utils.getString(
        res,
        "inValidCVCErrorText",
        defaultLocale.inValidCVCErrorText,
      ),
      inCompleteExpiryErrorText: Utils.getString(
        res,
        "inCompleteExpiryErrorText",
        defaultLocale.inCompleteExpiryErrorText,
      ),
      inValidExpiryErrorText: Utils.getString(
        res,
        "inValidExpiryErrorText",
        defaultLocale.inValidExpiryErrorText,
      ),
      pastExpiryErrorText: Utils.getString(
        res,
        "pastExpiryErrorText",
        defaultLocale.pastExpiryErrorText,
      ),
      poweredBy: Utils.getString(res, "poweredBy", defaultLocale.poweredBy),
      validThruText: Utils.getString(res, "validThruText", defaultLocale.validThruText),
      sortCodeText: Utils.getString(res, "sortCodeText", defaultLocale.sortCodeText),
      cvcTextLabel: Utils.getString(res, "cvcTextLabel", defaultLocale.cvcTextLabel),
      emailLabel: Utils.getString(res, "emailLabel", defaultLocale.emailLabel),
      emailInvalidText: Utils.getString(res, "emailInvalidText", defaultLocale.emailInvalidText),
      emailEmptyText: Utils.getString(res, "emailEmptyText", defaultLocale.emailEmptyText),
      accountNumberText: Utils.getString(res, "accountNumberText", defaultLocale.accountNumberText),
      fullNameLabel: Utils.getString(res, "fullNameLabel", defaultLocale.fullNameLabel),
      line1Label: Utils.getString(res, "line1Label", defaultLocale.line1Label),
      line1Placeholder: Utils.getString(res, "line1Placeholder", defaultLocale.line1Placeholder),
      line1EmptyText: Utils.getString(res, "line1EmptyText", defaultLocale.line1EmptyText),
      line2Label: Utils.getString(res, "line2Label", defaultLocale.line2Label),
      line2Placeholder: Utils.getString(res, "line2Placeholder", defaultLocale.line2Placeholder),
      line2EmptyText: Utils.getString(res, "line2EmptyText", defaultLocale.line2EmptyText),
      cityLabel: Utils.getString(res, "cityLabel", defaultLocale.cityLabel),
      cityEmptyText: Utils.getString(res, "cityEmptyText", defaultLocale.cityEmptyText),
      postalCodeLabel: Utils.getString(res, "postalCodeLabel", defaultLocale.postalCodeLabel),
      postalCodeEmptyText: Utils.getString(
        res,
        "postalCodeEmptyText",
        defaultLocale.postalCodeEmptyText,
      ),
      postalCodeInvalidText: Utils.getString(
        res,
        "postalCodeInvalidText",
        defaultLocale.postalCodeInvalidText,
      ),
      stateLabel: Utils.getString(res, "stateLabel", defaultLocale.stateLabel),
      stateEmptyText: Utils.getString(res, "stateEmptyText", defaultLocale.stateEmptyText),
      fullNamePlaceholder: Utils.getString(
        res,
        "fullNamePlaceholder",
        defaultLocale.fullNamePlaceholder,
      ),
      countryLabel: Utils.getString(res, "countryLabel", defaultLocale.countryLabel),
      currencyLabel: Utils.getString(res, "currencyLabel", defaultLocale.currencyLabel),
      bankLabel: Utils.getString(res, "bankLabel", defaultLocale.bankLabel),
      redirectText: Utils.getString(res, "redirectText", defaultLocale.redirectText),
      bankDetailsText: Utils.getString(res, "bankDetailsText", defaultLocale.bankDetailsText),
      orPayUsing: Utils.getString(res, "orPayUsing", defaultLocale.orPayUsing),
      addNewCard: Utils.getString(res, "addNewCard", defaultLocale.addNewCard),
      useExisitingSavedCards: Utils.getString(
        res,
        "useExisitingSavedCards",
        defaultLocale.useExisitingSavedCards,
      ),
      saveCardDetails: Utils.getString(res, "saveCardDetails", defaultLocale.saveCardDetails),
      addBankAccount: Utils.getString(res, "addBankAccount", defaultLocale.addBankAccount),
      payNowButton: Utils.getString(res, "payNowButton", defaultLocale.payNowButton),
      cardNumberEmptyText: Utils.getString(
        res,
        "cardNumberEmptyText",
        defaultLocale.cardNumberEmptyText,
      ),
      cardExpiryDateEmptyText: Utils.getString(
        res,
        "cardExpiryDateEmptyText",
        defaultLocale.cardExpiryDateEmptyText,
      ),
      cvcNumberEmptyText: Utils.getString(
        res,
        "cvcNumberEmptyText",
        defaultLocale.cvcNumberEmptyText,
      ),
      enterFieldsText: Utils.getString(res, "enterFieldsText", defaultLocale.enterFieldsText),
      enterValidDetailsText: Utils.getString(
        res,
        "enterValidDetailsText",
        defaultLocale.enterValidDetailsText,
      ),
      enterValidCardNumberErrorText: Utils.getString(
        res,
        "enterValidCardNumberErrorText",
        defaultLocale.enterValidCardNumberErrorText,
      ),
      card: Utils.getString(res, "card", defaultLocale.card),
      billingNameLabel: Utils.getString(res, "billingNameLabel", defaultLocale.billingNameLabel),
      billingNamePlaceholder: Utils.getString(
        res,
        "billingNamePlaceholder",
        defaultLocale.billingNamePlaceholder,
      ),
      cardHolderName: Utils.getString(res, "cardHolderName", defaultLocale.cardHolderName),
      cardNickname: Utils.getString(res, "cardNickname", defaultLocale.cardNickname),
      firstName: Utils.getString(res, "firstName", defaultLocale.firstName),
      lastName: Utils.getString(res, "lastName", defaultLocale.lastName),
      billingDetails: Utils.getString(res, "billingDetails", defaultLocale.billingDetails),
      requiredText: Utils.getString(res, "requiredText", defaultLocale.requiredText),
      cardHolderNameRequiredText: Utils.getString(
        res,
        "cardHolderNameRequiredText",
        defaultLocale.cardHolderNameRequiredText,
      ),
      invalidDigitsCardHolderNameError: Utils.getString(
        res,
        "invalidDigitsCardHolderNameError",
        defaultLocale.invalidDigitsCardHolderNameError,
      ),
      nickNameLengthExceedError: Utils.getString(
        res,
        "nickNameLengthExceedError",
        defaultLocale.nickNameLengthExceedError,
      ),
      invalidDigitsNickNameError: Utils.getString(
        res,
        "invalidDigitsNickNameError",
        defaultLocale.invalidDigitsNickNameError,
      ),
      lastNameRequiredText: Utils.getString(
        res,
        "lastNameRequiredText",
        defaultLocale.lastNameRequiredText,
      ),
      cardExpiresText: Utils.getString(res, "cardExpiresText", defaultLocale.cardExpiresText),
      addPaymentMethodLabel: Utils.getString(
        res,
        "addPaymentMethodLabel",
        defaultLocale.addPaymentMethodLabel,
      ),
      walletDisclaimer: Utils.getString(res, "walletDisclaimer", defaultLocale.walletDisclaimer),
      deletePaymentMethod: Utils.getString(
        res,
        "deletePaymentMethod",
        defaultLocale.deletePaymentMethod->Option.getOr("delete"),
      ),
      ibanEmptyText: Utils.getString(res, "ibanEmptyText", defaultLocale.ibanEmptyText),
      selectPaymentMethodText: Utils.getString(
        res,
        "selectPaymentMethodText",
        defaultLocale.selectPaymentMethodText,
      ),
      achBankDebitTermsPart1: Utils.getString(
        res,
        "achBankDebitTermsPart1",
        defaultLocale.achBankDebitTermsPart1,
      ),
      achBankDebitTermsPart2: Utils.getString(
        res,
        "achBankDebitTermsPart2",
        defaultLocale.achBankDebitTermsPart2,
      ),
      sepaDebitTermsPart1: Utils.getString(
        res,
        "sepaDebitTermsPart1",
        defaultLocale.sepaDebitTermsPart1,
      ),
      sepaDebitTermsPart2: Utils.getString(
        res,
        "sepaDebitTermsPart2",
        defaultLocale.sepaDebitTermsPart2,
      ),
      sepaDebitTermsPart3: Utils.getString(
        res,
        "sepaDebitTermsPart3",
        defaultLocale.sepaDebitTermsPart3,
      ),
      becsDebitTerms: Utils.getString(res, "becsDebitTerms", defaultLocale.becsDebitTerms),
      surchargeMsgAmountPart1: Utils.getString(
        res,
        "surchargeMsgAmountPart1",
        defaultLocale.surchargeMsgAmountPart1,
      ),
      surchargeMsgAmountPart2: Utils.getString(
        res,
        "surchargeMsgAmountPart2",
        defaultLocale.surchargeMsgAmountPart2,
      ),
      surchargeMsgAmountForCardPart1: Utils.getString(
        res,
        "surchargeMsgAmountForCardPart1",
        defaultLocale.surchargeMsgAmountForCardPart1,
      ),
      surchargeMsgAmountForCardPart2: Utils.getString(
        res,
        "surchargeMsgAmountForCardPart2",
        defaultLocale.surchargeMsgAmountForCardPart2,
      ),
      surchargeMsgAmountForOneClickWallets: Utils.getString(
        res,
        "surchargeMsgAmountForOneClickWallets",
        defaultLocale.surchargeMsgAmountForOneClickWallets,
      ),
      on: Utils.getString(res, "on", defaultLocale.on),
      \"and": Utils.getString(res, "and", defaultLocale.\"and"),
      nameEmptyText: Utils.getString(res, "nameEmptyText", defaultLocale.nameEmptyText),
      completeNameEmptyText: Utils.getString(
        res,
        "completeNameEmptyText",
        defaultLocale.completeNameEmptyText,
      ),
      billingDetailsText: Utils.getString(
        res,
        "billingDetailsText",
        defaultLocale.billingDetailsText,
      ),
      socialSecurityNumberLabel: Utils.getString(
        res,
        "socialSecurityNumberLabel",
        defaultLocale.socialSecurityNumberLabel,
      ),
      saveWalletDetails: Utils.getString(res, "saveWalletDetails", defaultLocale.saveWalletDetails),
      morePaymentMethods: Utils.getString(
        res,
        "morePaymentMethods",
        defaultLocale.morePaymentMethods,
      ),
      useExistingPaymentMethods: Utils.getString(
        res,
        "useExistingPaymentMethods",
        defaultLocale.useExistingPaymentMethods,
      ),
      cardExpiredText: Utils.getString(res, "cardExpiredText", defaultLocale.cardExpiredText),
      cardHeader: Utils.getString(res, "cardHeader", defaultLocale.cardHeader),
      cardBrandConfiguredErrorText: Utils.getString(
        res,
        "cardBrandConfiguredErrorText",
        defaultLocale.cardBrandConfiguredErrorText,
      ),
      currencyNetwork: Utils.getString(res, "currencyNetwork", defaultLocale.currencyNetwork),
      expiryPlaceholder: Utils.getString(res, "expiryPlaceholder", defaultLocale.expiryPlaceholder),
      dateOfBirth: Utils.getString(res, "dateOfBirth", defaultLocale.dateOfBirth),
      vpaIdLabel: Utils.getString(res, "vpaIdLabel", defaultLocale.vpaIdLabel),
      vpaIdEmptyText: Utils.getString(res, "vpaIdEmptyText", defaultLocale.vpaIdEmptyText),
      vpaIdInvalidText: Utils.getString(res, "vpaIdInvalidText", defaultLocale.vpaIdInvalidText),
      dateofBirthRequiredText: Utils.getString(
        res,
        "dateofBirthRequiredText",
        defaultLocale.dateofBirthRequiredText,
      ),
      dateOfBirthInvalidText: Utils.getString(
        res,
        "dateOfBirthInvalidText",
        defaultLocale.dateOfBirthInvalidText,
      ),
      dateOfBirthPlaceholderText: Utils.getString(
        res,
        "dateOfBirthPlaceholderText",
        defaultLocale.dateOfBirthPlaceholderText,
      ),
      formFundsInfoText: Utils.getString(res, "formFundsInfoText", defaultLocale.formFundsInfoText),
      formFundsCreditInfoTextPart1: Utils.getString(
        res,
        "formFundsCreditInfoTextPart1",
        defaultLocale.formFundsCreditInfoTextPart1,
      ),
      formFundsCreditInfoTextPart2: Utils.getString(
        res,
        "formFundsCreditInfoTextPart2",
        defaultLocale.formFundsCreditInfoTextPart2,
      ),
      formEditText: Utils.getString(res, "formEditText", defaultLocale.formEditText),
      formSaveText: Utils.getString(res, "formSaveText", defaultLocale.formSaveText),
      formSubmitText: Utils.getString(res, "formSubmitText", defaultLocale.formSubmitText),
      formSubmittingText: Utils.getString(
        res,
        "formSubmittingText",
        defaultLocale.formSubmittingText,
      ),
      formSubheaderBillingDetailsText: Utils.getString(
        res,
        "formSubheaderBillingDetailsText",
        defaultLocale.formSubheaderBillingDetailsText,
      ),
      formSubheaderCardText: Utils.getString(
        res,
        "formSubheaderCardText",
        defaultLocale.formSubheaderCardText,
      ),
      formSubheaderAccountTextPart1: Utils.getString(
        res,
        "formSubheaderAccountTextPart1",
        defaultLocale.formSubheaderAccountTextPart1,
      ),
      formSubheaderAccountTextPart2: Utils.getString(
        res,
        "formSubheaderAccountTextPart2",
        defaultLocale.formSubheaderAccountTextPart2,
      ),
      formHeaderReviewText: Utils.getString(
        res,
        "formHeaderReviewText",
        defaultLocale.formHeaderReviewText,
      ),
      formHeaderReviewTabLayoutTextPart1: Utils.getString(
        res,
        "formHeaderReviewTabLayoutTextPart1",
        defaultLocale.formHeaderReviewTabLayoutTextPart1,
      ),
      formHeaderReviewTabLayoutTextPart2: Utils.getString(
        res,
        "formHeaderReviewTabLayoutTextPart2",
        defaultLocale.formHeaderReviewTabLayoutTextPart2,
      ),
      formHeaderBankTextPart1: Utils.getString(
        res,
        "formHeaderBankTextPart1",
        defaultLocale.formHeaderBankTextPart1,
      ),
      formHeaderBankTextPart2: Utils.getString(
        res,
        "formHeaderBankTextPart2",
        defaultLocale.formHeaderBankTextPart2,
      ),
      formHeaderWalletTextPart1: Utils.getString(
        res,
        "formHeaderWalletTextPart1",
        defaultLocale.formHeaderWalletTextPart1,
      ),
      formHeaderWalletTextPart2: Utils.getString(
        res,
        "formHeaderWalletTextPart2",
        defaultLocale.formHeaderWalletTextPart2,
      ),
      formHeaderEnterCardText: Utils.getString(
        res,
        "formHeaderEnterCardText",
        defaultLocale.formHeaderEnterCardText,
      ),
      formHeaderSelectBankText: Utils.getString(
        res,
        "formHeaderSelectBankText",
        defaultLocale.formHeaderSelectBankText,
      ),
      formHeaderSelectWalletText: Utils.getString(
        res,
        "formHeaderSelectWalletText",
        defaultLocale.formHeaderSelectWalletText,
      ),
      formHeaderSelectAccountText: Utils.getString(
        res,
        "formHeaderSelectAccountText",
        defaultLocale.formHeaderSelectAccountText,
      ),
      formFieldACHRoutingNumberLabel: Utils.getString(
        res,
        "formFieldACHRoutingNumberLabel",
        defaultLocale.formFieldACHRoutingNumberLabel,
      ),
      formFieldSepaIbanLabel: Utils.getString(
        res,
        "formFieldSepaIbanLabel",
        defaultLocale.formFieldSepaIbanLabel,
      ),
      formFieldSepaBicLabel: Utils.getString(
        res,
        "formFieldSepaBicLabel",
        defaultLocale.formFieldSepaBicLabel,
      ),
      formFieldPixIdLabel: Utils.getString(
        res,
        "formFieldPixIdLabel",
        defaultLocale.formFieldPixIdLabel,
      ),
      formFieldBankAccountNumberLabel: Utils.getString(
        res,
        "formFieldBankAccountNumberLabel",
        defaultLocale.formFieldBankAccountNumberLabel,
      ),
      formFieldPhoneNumberLabel: Utils.getString(
        res,
        "formFieldPhoneNumberLabel",
        defaultLocale.formFieldPhoneNumberLabel,
      ),
      formFieldCountryCodeLabel: Utils.getString(
        res,
        "formFieldCountryCodeLabel",
        defaultLocale.formFieldCountryCodeLabel,
      ),
      formFieldBankNameLabel: Utils.getString(
        res,
        "formFieldBankNameLabel",
        defaultLocale.formFieldBankNameLabel,
      ),
      formFieldBankCityLabel: Utils.getString(
        res,
        "formFieldBankCityLabel",
        defaultLocale.formFieldBankCityLabel,
      ),
      formFieldCardHoldernamePlaceholder: Utils.getString(
        res,
        "formFieldCardHoldernamePlaceholder",
        defaultLocale.formFieldCardHoldernamePlaceholder,
      ),
      formFieldBankNamePlaceholder: Utils.getString(
        res,
        "formFieldBankNamePlaceholder",
        defaultLocale.formFieldBankNamePlaceholder,
      ),
      formFieldBankCityPlaceholder: Utils.getString(
        res,
        "formFieldBankCityPlaceholder",
        defaultLocale.formFieldBankCityPlaceholder,
      ),
      formFieldEmailPlaceholder: Utils.getString(
        res,
        "formFieldEmailPlaceholder",
        defaultLocale.formFieldEmailPlaceholder,
      ),
      formFieldPhoneNumberPlaceholder: Utils.getString(
        res,
        "formFieldPhoneNumberPlaceholder",
        defaultLocale.formFieldPhoneNumberPlaceholder,
      ),
      formFieldInvalidRoutingNumber: Utils.getString(
        res,
        "formFieldInvalidRoutingNumber",
        defaultLocale.formFieldInvalidRoutingNumber,
      ),
      infoCardRefId: Utils.getString(res, "infoCardRefId", defaultLocale.infoCardRefId),
      infoCardErrCode: Utils.getString(res, "infoCardErrCode", defaultLocale.infoCardErrCode),
      infoCardErrMsg: Utils.getString(res, "infoCardErrMsg", defaultLocale.infoCardErrMsg),
      infoCardErrReason: Utils.getString(res, "infoCardErrReason", defaultLocale.infoCardErrReason),
      linkRedirectionTextPart1: Utils.getString(
        res,
        "linkRedirectionTextPart1",
        defaultLocale.linkRedirectionTextPart1,
      ),
      linkRedirectionTextPart2: Utils.getString(
        res,
        "linkRedirectionTextPart2",
        defaultLocale.linkRedirectionTextPart2,
      ),
      linkExpiryInfoPart1: Utils.getString(
        res,
        "linkExpiryInfoPart1",
        defaultLocale.linkExpiryInfoPart1,
      ),
      linkExpiryInfoPart2: Utils.getString(
        res,
        "linkExpiryInfoPart2",
        defaultLocale.linkExpiryInfoPart2,
      ),
      payoutFromTextPart1: Utils.getString(
        res,
        "payoutFromTextPart1",
        defaultLocale.payoutFromTextPart1,
      ),
      payoutFromTextPart2: Utils.getString(
        res,
        "payoutFromTextPart2",
        defaultLocale.payoutFromTextPart2,
      ),
      payoutStatusFailedMessage: Utils.getString(
        res,
        "payoutStatusFailedMessage",
        defaultLocale.payoutStatusFailedMessage,
      ),
      payoutStatusPendingMessage: Utils.getString(
        res,
        "payoutStatusPendingMessage",
        defaultLocale.payoutStatusPendingMessage,
      ),
      payoutStatusSuccessMessage: Utils.getString(
        res,
        "payoutStatusSuccessMessage",
        defaultLocale.payoutStatusSuccessMessage,
      ),
      payoutStatusFailedText: Utils.getString(
        res,
        "payoutStatusFailedText",
        defaultLocale.payoutStatusFailedText,
      ),
      payoutStatusPendingText: Utils.getString(
        res,
        "payoutStatusPendingText",
        defaultLocale.payoutStatusPendingText,
      ),
      payoutStatusSuccessText: Utils.getString(
        res,
        "payoutStatusSuccessText",
        defaultLocale.payoutStatusSuccessText,
      ),
      pixCNPJInvalidText: Utils.getString(
        res,
        "pixCNPJInvalidText",
        defaultLocale.pixCNPJInvalidText,
      ),
      pixCNPJEmptyText: Utils.getString(res, "pixCNPJEmptyText", defaultLocale.pixCNPJEmptyText),
      pixCNPJLabel: Utils.getString(res, "pixCNPJLabel", defaultLocale.pixCNPJLabel),
      pixCNPJPlaceholder: Utils.getString(
        res,
        "pixCNPJPlaceholder",
        defaultLocale.pixCNPJPlaceholder,
      ),
      pixCPFInvalidText: Utils.getString(res, "pixCPFInvalidText", defaultLocale.pixCPFInvalidText),
      pixCPFEmptyText: Utils.getString(res, "pixCPFEmptyText", defaultLocale.pixCPFEmptyText),
      pixCPFLabel: Utils.getString(res, "pixCPFLabel", defaultLocale.pixCPFLabel),
      pixCPFPlaceholder: Utils.getString(res, "pixCPFPlaceholder", defaultLocale.pixCPFPlaceholder),
      pixKeyEmptyText: Utils.getString(res, "pixKeyEmptyText", defaultLocale.pixKeyEmptyText),
      pixKeyPlaceholder: Utils.getString(res, "pixKeyPlaceholder", defaultLocale.pixKeyPlaceholder),
      pixKeyLabel: Utils.getString(res, "pixKeyLabel", defaultLocale.pixKeyLabel),
      invalidCardHolderNameError: Utils.getString(
        res,
        "invalidCardHolderNameError",
        defaultLocale.invalidCardHolderNameError,
      ),
      invalidNickNameError: Utils.getString(
        res,
        "invalidNickNameError",
        defaultLocale.invalidNickNameError,
      ),
      nicknamePlaceholder: Utils.getString(
        res,
        "nicknamePlaceholder",
        defaultLocale.nicknamePlaceholder,
      ),
      cardTermsPart1: Utils.getString(res, "cardTermsPart1", defaultLocale.cardTermsPart1),
      cardTermsPart2: Utils.getString(res, "cardTermsPart2", defaultLocale.cardTermsPart2),
      useExisitingSavedCardsWeb: Utils.getString(
        res,
        "useExisitingSavedCardsWeb",
        defaultLocale.useExisitingSavedCardsWeb,
      ),
    }
  | None => defaultLocale
  }
}

let getLocaleStringsFromJson: Js.Json.t => localeStringsWebAndroid = jsonData => {
  switch jsonData->Js.Json.decodeObject {
  | Some(res) => getLocaleStrings(res->Utils.getJsonObjectFromRecord)
  | None => defaultLocale
  }
}

let getAchBankDebitTerms = (localString, str) => {
  `${localString.achBankDebitTermsPart1} ${localString.achBankDebitTermsPart2 === ""
      ? ""
      : str} ${localString.achBankDebitTermsPart2}`
}

let getSepaDebitTerms = (localString, str) => {
  `${localString.sepaDebitTermsPart1} ${str} ${localString.sepaDebitTermsPart2} ${str} ${localString.sepaDebitTermsPart3}`
}

let getCardTerms = (localString, str) => {
  `${localString.cardTermsPart1} ${str} ${localString.cardTermsPart2}`
}

let getSurchangeMsgAmountComponent = (localString, currency, str) => {
  <>
    {React.string(`${localString.surchargeMsgAmountPart1}${Utils.nbsp}`)}
    <strong> {React.string(`${currency} ${str}`)} </strong>
    {React.string({`${Utils.nbsp} ${localString.surchargeMsgAmountPart2}`})}
  </>
}

let getSurchangeMsgAmountForCardComponent = (localString, currency, str) => {
  <>
    {React.string(`${localString.surchargeMsgAmountForCardPart1}${Utils.nbsp}`)}
    <strong> {React.string(`${currency} ${str}`)} </strong>
    {React.string({`${Utils.nbsp} ${localString.surchargeMsgAmountForCardPart2}`})}
  </>
}

let getNameEmptyText = (localString, str) => {
  `${localString.nameEmptyText} ${str}`
}

let getCompleteNameEmptyText = (localString, str) => {
  `${localString.completeNameEmptyText} ${str}`
}

let getCardBrandConfiguredErrorText = (localString, str) => {
  `${str} ${localString.cardBrandConfiguredErrorText}`
}

let getFormFundsCreditInfoText = (localString, pmLabel) => {
  `${localString.formFundsCreditInfoTextPart1} ${pmLabel}${localString.formFundsCreditInfoTextPart2}`
}

let getFormSubheaderAccountText = (localString, pmLabel) => {
  `${localString.formSubheaderAccountTextPart1} ${pmLabel} ${localString.formSubheaderAccountTextPart2}`
}

let getFormHeaderReviewTabLayoutText = (localString, pmLabel) => {
  `${localString.formHeaderReviewTabLayoutTextPart1} ${pmLabel} ${localString.formHeaderReviewTabLayoutTextPart2}`
}

let getFormHeaderBankText = (localString, bankTransferType) => {
  `${localString.formHeaderBankTextPart1} ${bankTransferType} ${localString.formHeaderBankTextPart2}`
}

let getFormHeaderWalletText = (localString, walletTransferType) => {
  `${localString.formHeaderWalletTextPart1} ${walletTransferType} ${localString.formHeaderWalletTextPart2}`
}

let getLinkRedirectionText = (localString, seconds) => {
  `${localString.linkRedirectionTextPart1} ${seconds} ${localString.linkRedirectionTextPart2}`
}

let getLinkExpiryInfo = (localString, expiry) => {
  `${localString.linkExpiryInfoPart1} ${expiry} ${localString.linkExpiryInfoPart2}`
}

let getPayoutFromText = (localString, merchant) => {
  `${localString.payoutFromTextPart1} ${merchant} ${localString.payoutFromTextPart2}`
}
