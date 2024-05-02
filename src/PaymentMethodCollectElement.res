open PaymentMethodCollectUtils
open RecoilAtoms

@react.component
let make = (~integrateError, ~logger) => {
  let {iframeId} = Recoil.useRecoilValueFromAtom(keys)
  let options = Recoil.useRecoilValueFromAtom(paymentMethodCollectOptionAtom)
  let enabledPaymentMethods = options.enabledPaymentMethods
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
    <div className="flex">
      // Merchant's header / sidebar
      <div className="flex flex-col merchant-header">
        <div className="flex flex-row merchant-title"> {React.string("HyperSwitch")} </div>
        <img
          className="flex flex-row merchant-logo"
          src="https://app.hyperswitch.io/HyperswitchFavicon.png"
          alt="O"
        />
      </div>
      // Collect widget
      <div className="flex-col">
        {availablePaymentMethods
        ->Array.map(pm => {
          <div>
            {React.string(pm->String.make)}
            {switch pm->String.make {
            | "BankTransfer" =>
              availablePaymentMethodTypes.bankTransfer
              ->Array.map(v => {
                React.string(v->String.make)
              })
              ->React.array
            | "Wallet" =>
              availablePaymentMethodTypes.wallet
              ->Array.map(v => {
                React.string(v->String.make)
              })
              ->React.array
            | _ => React.null
            }}
          </div>
        })
        ->React.array}
      </div>
    </div>
  }
}

let default = make
