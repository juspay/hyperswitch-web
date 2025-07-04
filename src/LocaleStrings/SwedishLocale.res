let localeStrings: LocaleStringTypes.localeStrings = {
  locale: `sv`,
  localeDirection: `ltr`,
  cardNumberLabel: `Kortnummer`,
  inValidCardErrorText: `Kortnumret är ogiltigt.`,
  inValidExpiryErrorText: `Kortets utgångsdatum är ogiltigt.`,
  inCompleteCVCErrorText: `Kortets säkerhetskod är ofullständig.`,
  inCompleteExpiryErrorText: `Kortets utgångsdatum är ofullständigt.`,
  enterValidCardNumberErrorText: `Ange ett giltigt kortnummer.`,
  pastExpiryErrorText: `Kortets utgångsår är i det förflutna.`,
  poweredBy: `Drivs av Hyperswitch`,
  validThruText: `Utgångsdatum`,
  sortCodeText: `Sorteringskod`,
  cvcTextLabel: `CVC`,
  line1Label: `Adressrad 1`,
  line1Placeholder: `Gatuadress`,
  line2Label: `Adressrad 2`,
  line2Placeholder: `Lägenhetsnummer osv.`,
  cityLabel: `Ort`,
  postalCodeLabel: `Postnummer`,
  stateLabel: `Region`,
  accountNumberText: `Kontonummer`,
  emailLabel: `E-postadress`,
  fullNameLabel: `Fullständigt namn`,
  fullNamePlaceholder: `För- och efternamn`,
  countryLabel: `Land`,
  currencyLabel: `Valuta`,
  bankLabel: `Välj bank`,
  redirectText: `När du har skickat in din beställning kommer du att omdirigeras för att säkert slutföra ditt köp.`,
  bankDetailsText: `När du har skickat in dessa uppgifter får du bankkontoinformation för att göra betalningen. Se till att komma ihåg den.`,
  orPayUsing: `Eller betala med`,
  addNewCard: `Lägg till kredit-/betalkort`,
  useExisitingSavedCards: `Använd sparade betal-/kreditkort`,
  saveCardDetails: `Spara kortuppgifter`,
  addBankAccount: `Lägg till bankkonto`,
  achBankDebitTerms: str =>
    `Genom att ange ditt kontonummer och bekräfta denna betalning godkänner du att ${str} och Hyperswitch, vår betaltjänstleverantör, skickar instruktioner till din bank att debitera ditt konto och att din bank debiterar ditt konto i enlighet med dessa instruktioner. Du har rätt till återbetalning från din bank enligt villkoren i ditt avtal med din bank. En återbetalning måste begäras inom 8 veckor från det datum då ditt konto debiterades.`,
  sepaDebitTerms: str =>
    `Genom att lämna din betalningsinformation och bekräfta detta mandatformulär, godkänner du (A) ${str}, borgenären och/eller våra betaltjänstleverantörer att skicka instruktioner till din bank för att debitera ditt konto och (B) din bank att debitera ditt konto enligt instruktioner från ${str}. Som en del av dina rättigheter har du rätt till återbetalning från din bank enligt villkoren i ditt avtal med din bank. Återbetalning måste begäras inom 8 veckor från det datum då ditt konto debiterades. Dina rättigheter förklaras i ett uttalande som du kan få från din bank.`,
  becsDebitTerms: "Genom att ange dina bankkontouppgifter och bekräfta denna betalning godkänner du denna autogirering och serviceavtalet för autogirering och godkänner att Hyperswitch Payments Australia Pty Ltd ACN 160 180 343 med användar-ID för direktdebitering 507156 ( \"Hyperswitch\") debiterar ditt konto via Bulk Electronic Clearing System (BECS) på uppdrag av Hyperswitch Payment Widget (\"Handlaren\") för eventuella belopp som separat meddelats dig av Handlaren. Du intygar att du antingen är kontoinnehavare eller behörig undertecknare för kontot som anges ovan.",
  cardTerms: str =>
    `Genom att ange din kortinformation tillåter du att ${str} debiterar ditt kort för framtida betalningar i enlighet med deras villkor.`,
  payNowButton: `Betala nu`,
  cardNumberEmptyText: `Kortnummer får inte vara tomt`,
  cardExpiryDateEmptyText: `Kortets utgångsdatum får inte vara tomt`,
  cvcNumberEmptyText: `CVC-nummer får inte vara tomt`,
  enterFieldsText: `Fyll i samtliga fält`,
  enterValidDetailsText: `Ange giltiga uppgifter`,
  card: `Kort`,
  billingNameLabel: `Faktureringsnamn`,
  cardHolderName: `Korthållarens namn`,
  cardNickname: `Kortets smeknamn`,
  billingNamePlaceholder: `Förnamn och efternamn`,
  ibanEmptyText: `IBAN får inte vara tomt`,
  emailEmptyText: `E-post får inte vara tom`,
  emailInvalidText: `Ogiltig e-postadress`,
  line1EmptyText: `Adressrad 1 får inte vara tom`,
  line2EmptyText: `Adressrad 2 får inte vara tom`,
  cityEmptyText: `Staden får inte vara tom`,
  postalCodeEmptyText: `Postnummer får inte vara tomt`,
  postalCodeInvalidText: `Ogiltigt postnummer`,
  stateEmptyText: `Staten får inte vara tom`,
  surchargeMsgAmount: (currency, str) => <>
    {React.string(`Ett tilläggsbelopp på${Utils.nbsp}`)}
    <strong> {React.string(`${currency} ${str}`)} </strong>
    {React.string({`${Utils.nbsp}kommer att tillämpas för denna transaktion`})}
  </>,
  shortSurchargeMessage: (currency, amount) => <>
    {React.string(`Avgift :${Utils.nbsp}`)}
    <strong> {React.string(`${currency} ${amount}`)} </strong>
  </>,
  surchargeMsgAmountForCard: (currency, str) => <>
    {React.string(`Ett tilläggsbelopp på upp till${Utils.nbsp}`)}
    <strong> {React.string(`${currency} ${str}`)} </strong>
    {React.string(`${Utils.nbsp}kommer att tillämpas för denna transaktion`)}
  </>,
  surchargeMsgAmountForOneClickWallets: "Tilläggsavgift tillkommer",
  on: `på`,
  \"and": "och",
  nameEmptyText: str => `Vänligen ange din ${str}`,
  completeNameEmptyText: str => `Vänligen ange din fullständiga ${str}`,
  billingDetailsText: `Faktureringsuppgifter`,
  socialSecurityNumberLabel: `Personnummer`,
  saveWalletDetails: `Information om plånböcker kommer att sparas vid val`,
  morePaymentMethods: `Fler betalningsmetoder`,
  useExistingPaymentMethods: `Använd sparade betalningsmetoder`,
  nicknamePlaceholder: `Kortets smeknamn (valfritt)`,
  selectPaymentMethodText: `Välj en betalningsmetod och försök igen`,
  cardExpiredText: `Detta kort har gått ut`,
  cardHeader: `Kortinformation`,
  cardBrandConfiguredErrorText: str => `${str} stöds inte för tillfället.`,
  currencyNetwork: `Valutanätverk`,
  expiryPlaceholder: `MM / ÅÅ`,
  dateOfBirth: `Födelsedatum`,
  vpaIdLabel: `Vpa-id`,
  vpaIdEmptyText: `Vpa-id får inte vara tomt`,
  vpaIdInvalidText: `Ogiltigt Vpa-ID`,
  dateofBirthRequiredText: `Födelsedatum krävs`,
  dateOfBirthInvalidText: `Åldern bör vara större än eller lika med 18 år`,
  dateOfBirthPlaceholderText: `Ange födelsedatum`,
  formFundsInfoText: `Medlen kommer att sättas in på detta konto`,
  formFundsCreditInfoText: pmLabel => `Dina medel kommer att sättas in på det valda ${pmLabel}.`,
  formEditText: `Redigera`,
  formSaveText: `Spara`,
  formSubmitText: `Skicka`,
  formSubmittingText: `Skickar`,
  formSubheaderBillingDetailsText: `Ange din faktureringsadress`,
  formSubheaderCardText: `Dina kortdetaljer`,
  formSubheaderAccountText: pmLabel => `Ditt ${pmLabel}`,
  formHeaderReviewText: `Granska`,
  formHeaderReviewTabLayoutText: pmLabel => `Granska detaljerna för ditt ${pmLabel}`,
  formHeaderBankText: bankTransferType => `Ange bankdetaljer för ${bankTransferType}`,
  formHeaderWalletText: walletTransferType => `Ange plånboksdetaljer för ${walletTransferType}`,
  formHeaderEnterCardText: `Ange kortdetaljer`,
  formHeaderSelectBankText: `Välj bankmetod`,
  formHeaderSelectWalletText: `Välj plånbok`,
  formHeaderSelectAccountText: `Välj ett konto för betalningar`,
  formFieldACHRoutingNumberLabel: `Routingnummer`,
  formFieldSepaIbanLabel: `Internationellt bankkontonummer (IBAN)`,
  formFieldSepaBicLabel: `Bankidentifieringskod (valfritt)`,
  formFieldPixIdLabel: `Pix ID`,
  formFieldBankAccountNumberLabel: `Bankkontonummer`,
  formFieldPhoneNumberLabel: `Telefonnummer`,
  formFieldCountryCodeLabel: `Landskod (valfritt)`,
  formFieldBankNameLabel: `Banknamn (valfritt)`,
  formFieldBankCityLabel: `Bankstad (valfritt)`,
  formFieldCardHoldernamePlaceholder: `Ditt namn`,
  formFieldBankNamePlaceholder: `Banknamn`,
  formFieldBankCityPlaceholder: `Bankstad`,
  formFieldEmailPlaceholder: `Din e-post`,
  formFieldPhoneNumberPlaceholder: `Ditt telefonnummer`,
  formFieldInvalidRoutingNumber: `Ogiltigt routingnummer.`,
  infoCardRefId: `Referens-ID`,
  infoCardErrCode: `Felkod`,
  infoCardErrMsg: `Felmeddelande`,
  infoCardErrReason: `Orsak`,
  linkRedirectionText: seconds => `Ompekning om ${seconds->Int.toString} sekunder ...`,
  linkExpiryInfo: expiry => `Länken går ut: ${expiry}`,
  payoutFromText: merchant => `Utbetalning från ${merchant}`,
  payoutStatusFailedMessage: `Det gick inte att behandla din betalning. Kontakta din leverantör för mer information.`,
  payoutStatusPendingMessage: `Din betalning bör behandlas inom 2-3 arbetsdagar.`,
  payoutStatusSuccessMessage: `Din betalning har slutförts framgångsrikt. Medlen har satts in på den valda betalningsmetoden.`,
  payoutStatusFailedText: `Betalning misslyckades`,
  payoutStatusPendingText: `Betalning under behandling`,
  payoutStatusSuccessText: `Betalning lyckad`,
  pixCNPJInvalidText: `Ogiltig Pix CNPJ`,
  pixCNPJEmptyText: `Pix CNPJ kan inte vara tomt`,
  pixCNPJLabel: `Pix CNPJ`,
  pixCNPJPlaceholder: `Ange Pix CNPJ`,
  pixCPFInvalidText: `Ogiltig Pix CPF`,
  pixCPFEmptyText: `Pix CPF kan inte vara tomt`,
  pixCPFLabel: `Pix CPF`,
  pixCPFPlaceholder: `Ange Pix CPF`,
  pixKeyEmptyText: `Pix-nyckel kan inte vara tom`,
  pixKeyPlaceholder: `Ange Pix-nyckel`,
  pixKeyLabel: `Pix-nyckel`,
  destinationBankAccountIdEmptyText: `Destinations bankkonto-ID kan inte vara tomt`,
  sourceBankAccountIdEmptyText: `Käll bankkonto-ID kan inte vara tomt`,
  invalidCardHolderNameError: `Kortinnehavarens namn får inte innehålla siffror`,
  invalidNickNameError: `Smeknamnet får inte innehålla mer än 2 siffror`,
  expiry: `upphörande`,
}
