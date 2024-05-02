open PaymentMethodCollectUtils
open ErrorUtils

type paymentMethodCollectOptions = {enabledPaymentMethods: array<paymentMethodType>}

let defaultEnabledPaymentMethods: array<paymentMethodType> = [
  Card(Credit),
  Card(Debit),
  BankTransfer(ACH),
  BankTransfer(Bacs),
  BankTransfer(Sepa),
  Wallet(Paypal),
]

let defaultPaymentMethodCollectOptions = {
  enabledPaymentMethods: defaultEnabledPaymentMethods,
}

let itemToObjMapper = (dict, logger) => {
  unknownKeysWarning(["enabledPaymentMethods"], dict, "options", ~logger)
  {
    enabledPaymentMethods: switch dict->Dict.get("enabledPaymentMethods") {
    | Some(json) => json->decodePaymentMethodTypeArray
    | None => defaultEnabledPaymentMethods
    },
  }
}
