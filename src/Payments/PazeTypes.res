type client = {
  id: string,
  name: string,
  profileId: string,
}
type initialize = {client: client}

type canCheckout = {emailAddress: string}

type checkout = {
  acceptedPaymentCardNetworks: array<string>,
  emailAddress: string,
  sessionId: string,
  actionCode: string,
  transactionValue: JSON.t,
  shippingPreference: string,
}

type complete = {
  transactionOptions: JSON.t,
  transactionId: string,
  emailAddress: string,
  sessionId: string,
  transactionType: string,
  transactionValue: JSON.t,
}

type digitalWalletSdk = {
  canCheckout: canCheckout => promise<JSON.t>,
  checkout: checkout => promise<JSON.t>,
  complete: complete => promise<JSON.t>,
  initialize: initialize => promise<JSON.t>,
}
