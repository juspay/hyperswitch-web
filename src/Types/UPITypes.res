@val @scope("window") @nullable
external webkit: option<'a> = "webkit"

@get @nullable
external messageHandlers: 'a => option<'b> = "messageHandlers"

@val @scope(("window", "document", "documentElement"))
external clientHeight: int = "clientHeight"

@val @scope(("window", "document", "documentElement"))
external scrollHeight: int = "scrollHeight"

type screenState = AppSelection | VerificationScreen

type appInfo = {
  name: string,
  packageName: string,
}

type paymentMethodDataUrl = {url: string}

type paymentMethodData = {supportedMethods: string}

type paymentCurrencyAmount = {
  currency: string,
  value: string,
}

type paymentItem = {
  label: string,
  amount: paymentCurrencyAmount,
}

type paymentDetailsInit = {total: paymentItem}

type paymentRequest

@new @scope("window")
external createPaymentRequest: (array<paymentMethodData>, paymentDetailsInit) => paymentRequest =
  "PaymentRequest"

@send
external canMakePayment: paymentRequest => promise<bool> = "canMakePayment"

@val @scope("window")
external paymentRequestAvailable: option<'a> = "PaymentRequest"

@send
external postMessageToWindow: (Window.window, string, string) => unit = "postMessage"

let allUpiApps: array<appInfo> = [
  {name: "Google Pay", packageName: "tez://upi/pay"},
  {name: "PhonePe", packageName: "phonepe://pay"},
  {name: "Paytm", packageName: "paytmmp://pay"},
  {name: "BHIM", packageName: "bhim://pay"},
  {name: "Mobikwik", packageName: "mobikwik://upi/pay"},
  {name: "CRED", packageName: "credpay://upi/pay"},
  {name: "Navi", packageName: "navipay://pay"},
  {name: "Kiwi", packageName: "kiwi://upi/pay"},
  {name: "Moneyview", packageName: "mv://upi/upi://pay"},
  {name: "Super Money", packageName: "super://pay"},
]

let anyUpiApp: appInfo = {name: "Pay by any UPI app", packageName: "upi://pay"}
