open PaymentMethodCollectUtils
open PaymentMethodCollectTypes
open RecoilAtoms

@react.component
let make = (~integrateError, ~logger) => {
  let {iframeId} = Recoil.useRecoilValueFromAtom(keys)
  let options = Recoil.useRecoilValueFromAtom(paymentMethodCollectOptionAtom)
  let enabledPaymentMethods = options.enabledPaymentMethods

  // Component states
  let (availablePaymentMethods, setAvailablePaymentMethods) = React.useState(_ =>
    defaultAvailablePaymentMethods
  )
  let (availablePaymentMethodTypes, setAvailablePaymentMethodTypes) = React.useState(_ =>
    defaultAvailablePaymentMethodTypes
  )
  let (selectedPaymentMethod, setSelectedPaymentMethod) = React.useState(_ =>
    defaultSelectedPaymentMethod
  )
  let (selectedPaymentMethodType, setSelectedPaymentMethodType) = React.useState(_ =>
    defaultSelectedPaymentMethodType
  )
  let (paymentMethodData, setPaymentMethodData) = React.useState(_ => defaultPaymentMethodData)

  // Form a list of available payment methods
  React.useEffect(() => {
    let availablePMT = availablePaymentMethodTypes
    let _ = enabledPaymentMethods->Array.map(pm => {
      switch pm {
      | Card(cardType) =>
        if !(availablePMT.card->Array.includes(cardType)) {
          availablePMT.card->Array.push(cardType)
        }
      | BankTransfer(bankTransferType) =>
        if !(availablePMT.bankTransfer->Array.includes(bankTransferType)) {
          availablePMT.bankTransfer->Array.push(bankTransferType)
        }
      | Wallet(walletType) =>
        if !(availablePMT.wallet->Array.includes(walletType)) {
          availablePMT.wallet->Array.push(walletType)
        }
      }
    })

    let availablePM = availablePaymentMethods
    if !(availablePM->Array.includes(BankTransfer)) && availablePMT.bankTransfer->Array.length > 0 {
      availablePM->Array.push(BankTransfer)
    }
    if !(availablePM->Array.includes(Card)) && availablePMT.card->Array.length > 0 {
      availablePM->Array.push(Card)
    }
    if !(availablePM->Array.includes(Wallet)) && availablePMT.wallet->Array.length > 0 {
      availablePM->Array.push(Wallet)
    }

    setAvailablePaymentMethods(_ => availablePM)
    setAvailablePaymentMethodTypes(_ => availablePMT)

    None
  }, [enabledPaymentMethods])

  // Reset payment method type
  React.useEffect(() => {
    switch selectedPaymentMethod {
    | Card => setSelectedPaymentMethodType(_ => Some(Card(Debit)))
    | _ => setSelectedPaymentMethodType(_ => None)
    }

    None
  }, [selectedPaymentMethod])

  let renderContentHeader = () =>
    switch selectedPaymentMethodType {
    | Some(pmt) =>
      switch pmt {
      | Card(_) => React.string("Enter card details")
      | BankTransfer(bankTransferType) =>
        React.string("Enter " ++ bankTransferType->String.make ++ " bank details ")
      | Wallet(walletTransferType) =>
        React.string("Enter " ++ walletTransferType->String.make ++ " wallet details ")
      }
    | None => React.string("Select payment method type")
    }

  let renderPMTOptions = () =>
    switch selectedPaymentMethod {
    | Card => React.null
    | BankTransfer =>
      <div>
        {availablePaymentMethodTypes.bankTransfer
        ->Array.mapWithIndex((pmt, i) =>
          <div
            key={Int.toString(i)}
            onClick={_ => setSelectedPaymentMethodType(_ => Some(BankTransfer(pmt)))}>
            {React.string(pmt->String.make)}
          </div>
        )
        ->React.array}
      </div>
    | Wallet =>
      <div>
        {availablePaymentMethodTypes.wallet
        ->Array.mapWithIndex((pmt, i) =>
          <div
            key={Int.toString(i)}
            onClick={_ => setSelectedPaymentMethodType(_ => Some(Wallet(pmt)))}>
            {React.string(pmt->String.make)}
          </div>
        )
        ->React.array}
      </div>
    }

  let renderInputElement = (label, onClickHandler) => {
    <div className="input-wrapper">
      <label htmlFor=""> {React.string(label)} </label>
      <input type_="text" onClick={onClickHandler} />
    </div>
  }

  let renderInputs = (pmt: paymentMethodType) => {
    switch pmt {
    | Card(_) =>
      <div className="collect-card">
        {renderInputElement("Name on card")}
        {renderInputElement("Card Number")}
        {renderInputElement("Expiry Date")}
      </div>
    | BankTransfer(bankTransferType) =>
      <div className="collect-bank">
        {switch bankTransferType {
        | ACH =>
          <React.Fragment>
            {renderInputElement("Routing Number")}
            {renderInputElement("Bank Account Number")}
          </React.Fragment>
        | Bacs =>
          <React.Fragment>
            {renderInputElement("Sort Code")}
            {renderInputElement("Bank Account Number")}
          </React.Fragment>
        | Sepa =>
          <React.Fragment>
            {renderInputElement("IBAN")}
            {renderInputElement("BIC")}
          </React.Fragment>
        }}
      </div>
    | Wallet(walletType) =>
      <div className="collect-wallet">
        {switch walletType {
        | Paypal =>
          <React.Fragment>
            {renderInputElement("Email ID")}
            {renderInputElement("Mobile Number (Optional)")}
          </React.Fragment>
        }}
      </div>
    }
  }

  if integrateError {
    <ErrorOccured />
  } else {
    <div className="flex">
      // Merchant's info
      <div className="flex flex-row merchant-header">
        <img
          className="h-8 w-auto merchant-logo"
          src="https://app.hyperswitch.io/HyperswitchFavicon.png"
          alt="O"
        />
        <div className="merchant-title"> {React.string("HyperSwitch")} </div>
      </div>
      // Collect widget
      <div id="collect" className="flex flex-row">
        <div className="collect-sidebar">
          {availablePaymentMethods
          ->Array.mapWithIndex((pm, i) => {
            <div key={Int.toString(i)} onClick={e => setSelectedPaymentMethod(_ => pm)}>
              {React.string(pm->String.make)}
            </div>
          })
          ->React.array}
        </div>
        <div className="collect-content">
          <div className="content-header"> {renderContentHeader()} </div>
          <div>
            {switch selectedPaymentMethodType {
            | Some(pmt) => renderInputs(pmt)
            | None => renderPMTOptions()
            }}
          </div>
        </div>
      </div>
    </div>
  }
}

let default = make
