type paymentMethods = {
  paymentMethodType: string,
  paymentMethodSubType: string,
  requiredFields: array<PaymentMethodsRecord.required_fields>,
}
type bank = {mask: string}
type customerCard = {
  network: option<string>,
  last4Digits: string,
  expiryMonth: string,
  expiryYear: string,
  cardHolderName: option<string>,
  nickname: option<string>,
}
type card = {card: customerCard}
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
}
type paymentMethodsManagement = {
  paymentMethodsEnabled: array<paymentMethods>,
  customerPaymentMethods: array<customerMethods>,
}
type loadstate = LoadingV2 | LoadedV2(paymentMethodsManagement) | SemiLoadedV2 | LoadErrorV2(JSON.t)
type paymentManagementList = loadstate

let defaultPaymentMethods = {
  paymentMethodType: "",
  paymentMethodSubType: "",
  requiredFields: [],
}
let defaultCustomerMethods = {
  id: "",
  customerId: "",
  paymentMethodType: "",
  paymentMethodSubType: "",
  recurringEnabled: false,
  paymentMethodData: {
    card: {
      network: None,
      last4Digits: "",
      expiryMonth: "",
      expiryYear: "",
      cardHolderName: None,
      nickname: None,
    },
  },
  isDefault: false,
  requiresCvv: false,
  lastUsedAt: "",
  created: "",
  bank: {mask: ""},
}
let defaultPaymentManagementList = {
  paymentMethodsEnabled: [defaultPaymentMethods],
  customerPaymentMethods: [defaultCustomerMethods],
}
