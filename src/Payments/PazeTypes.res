type client = {
  id: string,
  name: string,
  profileId: string,
}
type initialize = {client: client}

type canCheckout = {emailAddress: string}

type transactionValue = {
  transactionAmount: string,
  transactionCurrencyCode: string,
}

type transactionOptions = {
  billingPreference: string,
  merchantCategoryCode: string,
  payloadTypeIndicator: string,
}

type checkout = {
  acceptedPaymentCardNetworks: array<string>,
  emailAddress?: string,
  sessionId: string,
  actionCode: string,
  transactionValue: transactionValue,
  shippingPreference: string,
}

type complete = {
  transactionOptions: transactionOptions,
  transactionId: string,
  emailAddress?: string,
  sessionId: string,
  transactionType: string,
  transactionValue: transactionValue,
}

type digitalWalletSdk = {
  canCheckout: canCheckout => promise<JSON.t>,
  checkout: checkout => promise<JSON.t>,
  complete: complete => promise<JSON.t>,
  initialize: initialize => promise<JSON.t>,
}
