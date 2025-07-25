let localeStrings: LocaleStringTypes.localeStrings = {
  locale: `ca`,
  localeDirection: `ltr`,
  cardNumberLabel: `Número de targeta`,
  inValidCardErrorText: `El número de targeta no és vàlid.`,
  inValidExpiryErrorText: `La data de caducitat no és vàlida.`,
  inCompleteCVCErrorText: `El codi de seguretat de la targeta està incomplet.`,
  inCompleteExpiryErrorText: `La data de venciment de la targeta està incompleta.`,
  enterValidCardNumberErrorText: `Introduïu un número de targeta vàlid.`,
  pastExpiryErrorText: `La data de venciment de la targeta ja ha passat.`,
  poweredBy: `Amb tecnologia de Hyperswitch`,
  validThruText: `Venciment`,
  sortCodeText: `Codi de sucursal`,
  cvcTextLabel: `CVC`,
  line1Label: `Línia d'adreça 1`,
  line1Placeholder: `Adreça postal`,
  line2Label: `Línia d'adreça 2`,
  line2Placeholder: `Pis, número d'apartament, etc.`,
  cityLabel: `Ciutat`,
  postalCodeLabel: `Codi postal`,
  stateLabel: `Estat`,
  accountNumberText: `Número de compte`,
  emailLabel: `Adreça electrònica`,
  fullNameLabel: `Nom complet`,
  fullNamePlaceholder: `Nom i cognoms`,
  countryLabel: `País`,
  currencyLabel: `Moneda`,
  bankLabel: `Seleccioni un banc`,
  redirectText: `En fer la comanda, se li redirigirà perquè completi la compra de manera segura.`,
  bankDetailsText: `Després d'enviar aquestes dades, rebrà la informació del compte bancari per fer el pagament. Recordi prendre'n nota.`,
  orPayUsing: `O faci el pagament mitjançant`,
  addNewCard: `Afegeixi una targeta de crèdit o dèbit`,
  useExisitingSavedCards: `Faci servir les targetes de dèbit o crèdit desades`,
  saveCardDetails: `Desi les dades de la targeta`,
  addBankAccount: `Afegeixi un compte bancari`,
  achBankDebitTerms: str =>
    `En facilitar el número de compte i confirmar el pagament, autoritza ${str} i Hyperswitch, el nostre proveïdor de serveis de pagament, a enviar ordres al seu banc perquè apliqui els càrrecs corresponents al compte. Tindrà dret a rebre un reembossament del banc d'acord amb els termes i condicions del contracte que hi hagi subscrit. El reembossament s'ha de sol·licitar en un termini de 8 setmanes des de la data en què es va aplicar el càrrec al compte.`,
  sepaDebitTerms: str =>
    `En proporcionar la seva informació de pagament i confirmar aquest formulari de mandat, autoritza (A) ${str}, el Creditor i/o els nostres proveïdors de serveis de pagament a enviar instruccions al seu banc per carregar el seu compte i (B) al seu banc a carregar el seu compte d’acord amb les instruccions de ${str}. Com a part dels seus drets, té dret a un reemborsament del seu banc segons els termes i condicions del seu acord amb el seu banc. El reemborsament ha de ser sol·licitat dins de les 8 setmanes següents a la data en què el seu compte va ser carregat. Els seus drets es descriuen en un document que pot obtenir al seu banc.`,
  becsDebitTerms: `En facilitar les dades del compte bancari i confirmar el pagament, accepta aquesta sol·licitud de domiciliació bancària i l'acord de servei corresponent. A més, autoritza Hyperswitch Payments Australia Pty Ltd ACN 160 180 343, amb número d'identificació d'usuari de domiciliació bancària 507156, («Hyperswitch») a aplicar càrrecs al compte a través del sistema de compensació electrònica massiva (BECS) en nom de Hyperswitch Payment Widget (el «comerç») per a qualsevol import que el comerç li comuniqui individualment. Certifica que és titular d'un compte o signatari autoritzat del compte que s'indica anteriorment.`,
  cardTerms: str =>
    `En facilitar la informació de la targeta, permet a ${str} que faci càrrecs a la targeta per a pagaments futurs d'acord amb les seves condicions.`,
  payNowButton: `Pagui ara`,
  cardNumberEmptyText: `Cal indicar el número de la targeta`,
  cardExpiryDateEmptyText: `Cal indicar la data de venciment de la targeta`,
  cvcNumberEmptyText: `Cal indicar el número CVC`,
  enterFieldsText: `Empleni tots els camps`,
  enterValidDetailsText: `Introdueixi dades vàlides`,
  card: `Targeta`,
  billingNameLabel: `Nom de facturació`,
  cardHolderName: `Nom del titular de la targeta`,
  cardNickname: `Sobrenom de la targeta`,
  billingNamePlaceholder: `Nom i cognom`,
  ibanEmptyText: `L'IBAN no pot estar buit`,
  emailEmptyText: `El correu electrònic no pot estar buit`,
  emailInvalidText: `adressa de correu invàlida`,
  line1EmptyText: `La línia d'adreça 1 no pot estar buida`,
  line2EmptyText: `La línia d'adreça 2 no pot estar buida`,
  cityEmptyText: `La ciutat no pot estar buida`,
  postalCodeEmptyText: `El codi postal no pot estar buit`,
  postalCodeInvalidText: `Codi postal no vàlid`,
  stateEmptyText: `L'estat no pot estar buit`,
  surchargeMsgAmount: (currency, str) => <>
    {React.string(`Un import de recàrrec de${Utils.nbsp}`)}
    <strong> {React.string(`${currency} ${str}`)} </strong>
    {React.string({`${Utils.nbsp}s'aplicarà per a aquesta transacció`})}
  </>,
  shortSurchargeMessage: (currency, amount) => <>
    {React.string(`Tarifa :${Utils.nbsp}`)}
    <strong> {React.string(`${currency} ${amount}`)} </strong>
  </>,
  surchargeMsgAmountForCard: (currency, str) => <>
    {React.string(`Un recàrrec de fins a${Utils.nbsp}`)}
    <strong> {React.string(`${currency} ${str}`)} </strong>
    {React.string(`${Utils.nbsp}s'aplicarà per a aquesta transacció`)}
  </>,
  surchargeMsgAmountForOneClickWallets: `Taxa addicional aplicable`,
  on: `activat`,
  \"and": `i`,
  nameEmptyText: str => `Si us plau, proporcioneu el vostre${str}`,
  completeNameEmptyText: str => `Si us plau, proporcioneu el vostre complet ${str}`,
  billingDetailsText: `Detalls de facturació`,
  socialSecurityNumberLabel: `Número de la Seguretat Social`,
  saveWalletDetails: `Els detalls de les carteres es desaran en seleccionar-los`,
  morePaymentMethods: `més mètodes de pagament`,
  useExistingPaymentMethods: `Utilitzeu formes de pagament desades`,
  nicknamePlaceholder: `Àlies de la targeta (opcional)`,
  selectPaymentMethodText: `Seleccioneu una forma de pagament i torneu-ho a provar`,
  cardExpiredText: `Aquesta targeta ha caducat`,
  cardHeader: `Informació de la targeta`,
  cardBrandConfiguredErrorText: str => `${str} no està suportat en aquest moment.`,
  currencyNetwork: `Xarxes de Monedes`,
  expiryPlaceholder: `MM / AA`,
  dateOfBirth: `Data de naixement`,
  vpaIdLabel: `Vpa Id`,
  vpaIdEmptyText: `L'identificador de Vpa no pot estar buit`,
  vpaIdInvalidText: `Identificador de VPA no vàlid`,
  dateofBirthRequiredText: `Es requereix la data de naixement`,
  dateOfBirthInvalidText: `L'edat ha de ser igual o superior a 18 anys`,
  dateOfBirthPlaceholderText: `Introdueix la data de naixement`,
  formFundsInfoText: "Els fons seran acreditats a aquest compte",
  formFundsCreditInfoText: pmLabel =>
    `Els teus fons seran acreditats en el ${pmLabel} seleccionat.`,
  formEditText: `Editar`,
  formSaveText: `Desar`,
  formSubmitText: `Enviar`,
  formSubmittingText: `Enviant`,
  formSubheaderBillingDetailsText: `Introdueix la teva adreça de facturació`,
  formSubheaderCardText: `Detalls de la teva targeta`,
  formSubheaderAccountText: pmLabel => `El teu ${pmLabel}`,
  formHeaderReviewText: `Revisar`,
  formHeaderReviewTabLayoutText: pmLabel => `Revisa els detalls del teu ${pmLabel}`,
  formHeaderBankText: bankTransferType => `Introdueix els detalls bancaris de ${bankTransferType}`,
  formHeaderWalletText: walletTransferType =>
    `Introdueix els detalls de la cartera ${walletTransferType}`,
  formHeaderEnterCardText: `Introdueix els detalls de la targeta`,
  formHeaderSelectBankText: `Selecciona un mètode bancari`,
  formHeaderSelectWalletText: `Selecciona una cartera`,
  formHeaderSelectAccountText: `Selecciona un compte per a pagaments`,
  formFieldACHRoutingNumberLabel: `Número de ruta`,
  formFieldSepaIbanLabel: `Número de Compte Bancari Internacional (IBAN)`,
  formFieldSepaBicLabel: `Codi d'Identificació Bancària (Opcional)`,
  formFieldPixIdLabel: `ID Pix`,
  formFieldBankAccountNumberLabel: `Número de compte bancari`,
  formFieldPhoneNumberLabel: `Número de telèfon`,
  formFieldCountryCodeLabel: `Codi de país (Opcional)`,
  formFieldBankNameLabel: `Nom del banc (Opcional)`,
  formFieldBankCityLabel: `Ciutat del banc (Opcional)`,
  formFieldCardHoldernamePlaceholder: `El teu nom`,
  formFieldBankNamePlaceholder: `Nom del banc`,
  formFieldBankCityPlaceholder: `Ciutat del banc`,
  formFieldEmailPlaceholder: `El teu correu electrònic`,
  formFieldPhoneNumberPlaceholder: `El teu telèfon`,
  formFieldInvalidRoutingNumber: `El número de ruta és invàlid.`,
  infoCardRefId: `ID de referència`,
  infoCardErrCode: `Codi d'error`,
  infoCardErrMsg: `Missatge d'error`,
  infoCardErrReason: `Raó`,
  linkRedirectionText: seconds => `Redirigint en ${seconds->Int.toString} segons ...`,
  linkExpiryInfo: expiry => `L'enllaç caduca el: ${expiry}`,
  payoutFromText: merchant => `Pagament de ${merchant}`,
  payoutStatusFailedMessage: `No s'ha pogut processar el teu pagament. Comprova amb el teu proveïdor per a més detalls.`,
  payoutStatusPendingMessage: `El teu pagament s'ha de processar en 2-3 dies hàbils.`,
  payoutStatusSuccessMessage: `El teu pagament s'ha realitzat amb èxit. Els fons han estat ingressats en la teva modalitat de pagament seleccionada.`,
  payoutStatusFailedText: `Pagament fallit`,
  payoutStatusPendingText: `Processant el pagament`,
  payoutStatusSuccessText: `Pagament realitzat`,
  pixCNPJInvalidText: `CNPJ Pix no vàlid`,
  pixCNPJEmptyText: `El CNPJ Pix no pot estar buit`,
  pixCNPJLabel: `CNPJ Pix`,
  pixCNPJPlaceholder: `Introdueix el CNPJ Pix`,
  pixCPFInvalidText: `CPF Pix no vàlid`,
  pixCPFEmptyText: `El CPF Pix no pot estar buit`,
  pixCPFLabel: `CPF Pix`,
  pixCPFPlaceholder: `Introdueix el CPF Pix`,
  pixKeyEmptyText: `La clau Pix no pot estar buida`,
  pixKeyPlaceholder: `Introdueix la clau Pix`,
  pixKeyLabel: `Clau Pix`,
  destinationBankAccountIdEmptyText: `L'identificador del compte bancari de destinació no pot estar buit`,
  sourceBankAccountIdEmptyText: `L'identificador del compte bancari d'origen no pot estar buit`,
  invalidCardHolderNameError: `El nom del titular de la targeta no pot contenir dígits`,
  invalidNickNameError: `El sobrenom no pot contenir més de 2 dígits`,
  expiry: `caducitat`,
  payment_methods_afterpay_clearpay: `After Pay`,
  payment_methods_google_pay: `Google Pay`,
  payment_methods_apple_pay: `Apple Pay`,
  payment_methods_samsung_pay: "Samsung Pay",
  payment_methods_mb_way: `Mb Way`,
  payment_methods_mobile_pay: `Mobile Pay`,
  payment_methods_ali_pay: `Ali Pay`,
  payment_methods_ali_pay_hk: `Ali Pay HK`,
  payment_methods_we_chat_pay: `WeChat`,
  payment_methods_duit_now: `DuitNow`,
  payment_methods_revolut_pay: `Revolut Pay`,
  payment_methods_affirm: `Affirm`,
  payment_methods_crypto_currency: `Crypto`,
  payment_methods_card: `Carte`,
  payment_methods_klarna: `Klarna`,
  payment_methods_sofort: `Sofort`,
  payment_methods_ach_transfer: `Virement ACH`,
  payment_methods_bacs_transfer: `Virement BACS`,
  payment_methods_sepa_bank_transfer: `Virement SEPA`,
  payment_methods_instant_bank_transfer: `Virement instantané`,
  payment_methods_instant_bank_transfer_finland: `Virement instantané Finlande`,
  payment_methods_instant_bank_transfer_poland: `Virement instantané Pologne`,
  payment_methods_sepa_debit: `Prélèvement SEPA`,
  payment_methods_giropay: `GiroPay`,
  payment_methods_eps: `EPS`,
  payment_methods_walley: `Walley`,
  payment_methods_pay_bright: `Pay Bright`,
  payment_methods_ach_debit: `Prélèvement ACH`,
  payment_methods_bacs_debit: `Prélèvement BACS`,
  payment_methods_becs_debit: `Prélèvement BECS`,
  payment_methods_blik: `Blik`,
  payment_methods_trustly: `Trustly`,
  payment_methods_bancontact_card: `Carte Bancontact`,
  payment_methods_online_banking_czech_republic: `Banque en ligne Tchéquie`,
  payment_methods_online_banking_slovakia: `Banque en ligne Slovaquie`,
  payment_methods_online_banking_finland: `Banque en ligne Finlande`,
  payment_methods_online_banking_poland: `Banque en ligne Pologne`,
  payment_methods_ideal: `iDEAL`,
  payment_methods_ban_connect: `Ban Connect`,
  payment_methods_ach_bank_debit: `Prélèvement bancaire ACH`,
  payment_methods_przelewy24: `Przelewy24`,
  payment_methods_interac: `Interac`,
  payment_methods_twint: `Twint`,
  payment_methods_vipps: `Vipps`,
  payment_methods_dana: `Dana`,
  payment_methods_go_pay: `Go Pay`,
  payment_methods_kakao_pay: `Kakao Pay`,
  payment_methods_gcash: `GCash`,
  payment_methods_momo: `Momo`,
  payment_methods_touch_n_go: `Touch N Go`,
  payment_methods_bizum: `Bizum`,
  payment_methods_classic: `Argent comptant / Bon`,
  payment_methods_online_banking_fpx: `Banque en ligne FPX`,
  payment_methods_online_banking_thailand: `Banque en ligne Thaïlande`,
  payment_methods_alma: `Alma`,
  payment_methods_atome: `Atome`,
  payment_methods_multibanco_transfer: `Multibanco`,
  payment_methods_card_redirect: `Carte`,
  payment_methods_open_banking_uk: `Payer par banque`,
  payment_methods_open_banking_pis: `Bancaire ouvert`,
  payment_methods_evoucher: `E-Voucher`,
  payment_methods_pix_transfer: `Pix`,
  payment_methods_boleto: `Boleto`,
  payment_methods_paypal: `Paypal`,
  payment_methods_local_bank_transfer_transfer: `Union Pay`,
  payment_methods_mifinity: `Mifinity`,
  payment_methods_upi_collect: `UPI Collect`,
  payment_methods_eft: `EFT`,
}
