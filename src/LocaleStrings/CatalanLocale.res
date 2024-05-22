let localeStrings: LocaleStringTypes.localeStrings = {
  locale: `ca`,
  localeDirection: `ltr`,
  cardNumberLabel: `Número de targeta`,
  inValidCardErrorText: `El número de targeta no és vàlid.`,
  inCompleteCVCErrorText: `El codi de seguretat de la targeta està incomplet.`,
  inCompleteExpiryErrorText: `La data de venciment de la targeta està incompleta.`,
  pastExpiryErrorText: `La data de venciment de la targeta ja ha passat.`,
  poweredBy: `Amb tecnologia de Hyperswitch`,
  validThruText: `Venciment`,
  sortCodeText: `Codi de sucursal`,
  cvcTextLabel: `CVC`,
  line1Label: `Línia d'adreça 1`,
  line1Placeholder: `Adreça postal`,
  line2Label: `Línia d'adreça 2`,
  line2Placeholder: `Pis, número d'apartament, etc. (opcional)`,
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
    `En facilitar la informació de pagament i confirmar el pagament, autoritza ${str} i Hyperswitch, el nostre proveïdor de serveis de pagament, o a PPRO, el seu proveïdor de serveis local, a enviar ordres al seu banc i a (B) perquè apliqui els càrrecs corresponents al compte. Com a part dels seus drets, podrà rebre un reembossament del banc d'acord amb els termes i condicions del contracte que hi hagi subscrit. El reembossament s'ha de sol·licitar en un termini de 8 setmanes des de la data en què es va aplicar el càrrec al compte. Els seus drets s'expliquen en un extracte que podrà sol·licitar al banc. Accepta rebre notificacions dels càrrecs futurs fins 2 dies abans que es produeixin.`,
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
}