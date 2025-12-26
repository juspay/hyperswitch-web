type address = {
  city: string,
  country: string,
  line1: string,
  line2: string,
  line3: string,
  zip: string,
  state: string,
  firstName: string,
  lastName: string,
}

type phone = {
  number: string,
  countryCode: string,
}

type billing = {
  address: address,
  phone: phone,
  email: string,
}

type cardNetwork = {
  cardNetwork: CardUtils.cardIssuer,
  surchargeDetails: option<PaymentMethodsRecord.surchargeDetails>,
  eligibleConnectors: array<string>,
}

type paymentMethodEnabled = {
  cardNetworks?: array<cardNetwork>,
  paymentMethodType: string,
  paymentMethodSubtype: string,
  bankNames?: array<string>,
  requiredFields: array<PaymentMethodsRecord.required_fields>,
  surchargeDetails: option<PaymentMethodsRecord.surchargeDetails>,
  paymentExperience?: array<PaymentMethodsRecord.paymentFlow>,
}

type bank = {mask: string}

type customerCard = {
  network: option<string>,
  last4Digits: string,
  expiryMonth: string,
  expiryYear: string,
  cardHolderName: option<string>,
  nickname: option<string>,
  issuerCountry: option<string>,
  cardFingerprint: string,
  cardIsin: string,
  cardIssuer: string,
  cardType: string,
  savedToLocker: bool,
}

type card = {card: customerCard}

type networkTokenizationData = {
  last4Digits: string,
  issuerCountry: string,
  networkTokenExpiryMonth: string,
  networkTokenExpiryYear: string,
  nickName: string,
  cardHolderName: string,
  cardIsin: string,
  cardIssuer: string,
  cardNetwork: string,
  cardType: string,
  savedToLocker: bool,
}

type networkTokenization = {paymentMethodData: networkTokenizationData}

type customerMethods = {
  id: string,
  customerId: string,
  paymentMethodType: string,
  paymentMethodSubType: string,
  recurringEnabled: bool,
  paymentMethodData: card,
  isDefault: bool,
  requiresCvv: bool,
  lastUsedAt: string,
  created: string,
  bank: bank,
  billing?: billing,
  networkTokenization?: networkTokenization,
}

type paymentMethodsManagement = {
  paymentMethodsEnabled: array<paymentMethodEnabled>,
  customerPaymentMethods: array<customerMethods>,
}

type loadstate = LoadingV2 | LoadedV2(paymentMethodsManagement) | SemiLoadedV2 | LoadErrorV2(JSON.t)

type paymentManagementList = loadstate

type paymentListLookupNew = {
  walletsList: array<string>,
  otherPaymentList: array<string>,
}

type intentCall = {paymentType: PaymentMethodsRecord.payment_type}

type intentLoadState = LoadingIntent | LoadedIntent(intentCall) | Error(JSON.t)
