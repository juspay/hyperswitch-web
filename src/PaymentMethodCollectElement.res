open PaymentMethodCollectUtils
open RecoilAtoms

@react.component
let make = (
  ~enabledPaymentMethods: array<PaymentMethodCollectUtils.paymentMethodType>,
  ~integrateError,
  ~logger,
) => {
  let {iframeId} = Recoil.useRecoilValueFromAtom(keys)
  let options = Recoil.useRecoilValueFromAtom(elementOptions)
  let availablePaymentMethods: array<paymentMethod> = []
  let availablePaymentMethodTypes: paymentMethodTypes = {
    card: [],
    bankTransfer: [],
    wallet: [],
  }

  // Form a list of available payment method types
  let _ = enabledPaymentMethods->Array.map(pm => {
    switch pm {
    | Card(cardType) =>
      switch cardType {
      | Credit =>
        if !(availablePaymentMethodTypes.card->Array.includes(Credit)) {
          availablePaymentMethodTypes.card->Array.push(Credit)
        }
      | Debit =>
        if !(availablePaymentMethodTypes.card->Array.includes(Debit)) {
          availablePaymentMethodTypes.card->Array.push(Debit)
        }
      }
    | BankTransfer(bankTransferType) =>
      switch bankTransferType {
      | ACH =>
        if !(availablePaymentMethodTypes.bankTransfer->Array.includes(ACH)) {
          availablePaymentMethodTypes.bankTransfer->Array.push(ACH)
        }
      | Bacs =>
        if !(availablePaymentMethodTypes.bankTransfer->Array.includes(Bacs)) {
          availablePaymentMethodTypes.bankTransfer->Array.push(Bacs)
        }
      | Sepa =>
        if !(availablePaymentMethodTypes.bankTransfer->Array.includes(Sepa)) {
          availablePaymentMethodTypes.bankTransfer->Array.push(Sepa)
        }
      }
    | Wallet(walletType) =>
      switch walletType {
      | Paypal =>
        if !(availablePaymentMethodTypes.wallet->Array.includes(Paypal)) {
          availablePaymentMethodTypes.wallet->Array.push(Paypal)
        }
      }
    }
  })

  if availablePaymentMethodTypes.bankTransfer->Array.length > 0 {
    availablePaymentMethods->Array.push(BankTransfer)
  }

  if availablePaymentMethodTypes.card->Array.length > 0 {
    availablePaymentMethods->Array.push(Card)
  }

  if availablePaymentMethodTypes.wallet->Array.length > 0 {
    availablePaymentMethods->Array.push(Wallet)
  }

  if integrateError {
    <ErrorOccured />
  } else {
    <div disabled=options.disabled className="flex flex-col">
      <div className="flex flex-row m-auto w-full justify-between items-center">
        {availablePaymentMethods
        ->Array.map(pm => {
          <div> {React.string(pm->String.make)} </div>
        })
        ->React.array}
      </div>
    </div>
  }
}

let default = make
