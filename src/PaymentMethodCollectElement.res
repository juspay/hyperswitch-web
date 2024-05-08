open PaymentMethodCollectUtils
open PaymentMethodCollectTypes
open RecoilAtoms

@react.component
let make = (~integrateError, ~logger) => {
  let keys = Recoil.useRecoilValueFromAtom(keys)
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
  let (paymentMethodData, setPaymentMethodData) = React.useState(_ => Dict.make())
  let (merchantName, setMerchantName) = React.useState(_ =>
    defaultPaymentMethodCollectOptions.collectorName
  )
  let (fieldValidityDict, setFieldValidityDict): (
    Js.Dict.t<option<bool>>,
    (Js.Dict.t<option<bool>> => Js.Dict.t<option<bool>>) => unit,
  ) = React.useState(_ => Dict.make())

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

  // Update merchant's name
  React.useEffect(() => {
    setMerchantName(_ => options.collectorName)
    None
  }, [options.collectorName])

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

  let renderInputElement = (label, onChangeHandler) => {
    <div className="input-wrapper">
      <label htmlFor=""> {React.string(label)} </label>
      <input type_="text" onChange={onChangeHandler} />
    </div>
  }

  let updatePaymentMethodDataDict = (record, field, value): 'a => {
    let updatedRecord = Dict.copy(record)
    switch field {
    // Card
    | "nameOnCard" | "cardNumber" | "expiryDate" => updatedRecord->Dict.set(field, value)

    // ACH
    | "routingNumber"
    | "accountNumber"
    | "bankName"
    | "city" =>
      updatedRecord->Dict.set(field, value)
    // Bacs
    | "sortCode" => updatedRecord->Dict.set(field, value)
    // SEPA
    | "iban"
    | "bic"
    | "countryCode" =>
      updatedRecord->Dict.set(field, value)

    // Paypal
    | "email" => updatedRecord->Dict.set(field, value)
    | _ => ()
    }

    updatedRecord
  }

  let inputHandler = (event: ReactEvent.Form.t, pmt: paymentMethodType, field) => {
    let updatedPmdDict = updatePaymentMethodDataDict(
      paymentMethodData,
      field,
      ReactEvent.Form.target(event)["value"],
    )
    setPaymentMethodData(_ => updatedPmdDict)
  }

  let renderInputs = (pmt: paymentMethodType) => {
    switch pmt {
    | Card(_) =>
      <div className="collect-card">
        <InputField
          id="nameOnCard"
          fieldName="Cardholder Name"
          placeholder="Your name"
          value={getValueFromDict(paymentMethodData, "nameOnCard")}
          paymentType={PaymentMethodCollectElement}
          inputRef={React.useRef(Nullable.null)}
          isFocus={true}
          isValid={fieldValidityDict->Dict.get("nameOnCard")->Option.getOr(None)}
          onChange={event => inputHandler(event, pmt, "nameOnCard")}
          setIsValid={updatedValidity => {
            let v = updatedValidity()
            setFieldValidity("nameOnCard", v, fieldValidityDict, setFieldValidityDict)
          }}
          onBlur={_ev =>
            calculateAndSetValidity(
              paymentMethodData,
              "nameOnCard",
              fieldValidityDict,
              setFieldValidityDict,
            )}
        />
        <InputField
          id="cardNumber"
          fieldName="Card Number"
          placeholder="1234 1234 1234 1234"
          value={getValueFromDict(paymentMethodData, "cardNumber")}
          paymentType={PaymentMethodCollectElement}
          type_="tel"
          inputRef={React.useRef(Nullable.null)}
          isFocus={true}
          isValid={fieldValidityDict->Dict.get("cardNumber")->Option.getOr(None)}
          onChange={event => inputHandler(event, pmt, "cardNumber")}
          setIsValid={updatedValidity => {
            let v = updatedValidity()
            setFieldValidity("cardNumber", v, fieldValidityDict, setFieldValidityDict)
          }}
          onBlur={_ev =>
            calculateAndSetValidity(
              paymentMethodData,
              "cardNumber",
              fieldValidityDict,
              setFieldValidityDict,
            )}
        />
        <InputField
          id="expiryDate"
          fieldName="Expiry Date"
          placeholder="MM / YY"
          maxLength=7
          value={getValueFromDict(paymentMethodData, "expiryDate")}
          paymentType={PaymentMethodCollectElement}
          inputRef={React.useRef(Nullable.null)}
          isFocus={true}
          isValid={fieldValidityDict->Dict.get("expiryDate")->Option.getOr(None)}
          onChange={event => inputHandler(event, pmt, "expiryDate")}
          setIsValid={updatedValidity => {
            let v = updatedValidity()
            setFieldValidity("expiryDate", v, fieldValidityDict, setFieldValidityDict)
          }}
          onBlur={_ev =>
            calculateAndSetValidity(
              paymentMethodData,
              "expiryDate",
              fieldValidityDict,
              setFieldValidityDict,
            )}
        />
      </div>
    | BankTransfer(bankTransferType) =>
      <div className="collect-bank">
        {switch bankTransferType {
        | ACH =>
          <React.Fragment>
            {renderInputElement("Routing Number", event =>
              inputHandler(event, pmt, "routingNumber")
            )}
            {renderInputElement("Bank Account Number", event =>
              inputHandler(event, pmt, "accountNumber")
            )}
          </React.Fragment>
        | Bacs =>
          <React.Fragment>
            {renderInputElement("Sort Code", event => inputHandler(event, pmt, "sortCode"))}
            {renderInputElement("Bank Account Number", event =>
              inputHandler(event, pmt, "accountNumber")
            )}
          </React.Fragment>
        | Sepa =>
          <React.Fragment>
            {renderInputElement("IBAN", event => inputHandler(event, pmt, "iban"))}
            {renderInputElement("BIC", event => inputHandler(event, pmt, "bic"))}
          </React.Fragment>
        }}
      </div>
    | Wallet(walletType) =>
      <div className="collect-wallet">
        {switch walletType {
        | Paypal =>
          <React.Fragment>
            {renderInputElement("Email ID", event => inputHandler(event, pmt, "email"))}
            {renderInputElement("Mobile Number (Optional)", event =>
              inputHandler(event, pmt, "mobile")
            )}
          </React.Fragment>
        }}
      </div>
    }
  }

  let handleSubmit = _ev => {
    let pmdBody = formCreatePaymentMethodRequestBody(selectedPaymentMethodType, paymentMethodData)

    switch pmdBody {
    | Some(pmd) => {
        let paymentMethod = selectedPaymentMethod->getPaymentMethod
        let pmdBody =
          pmd->Array.map(((k, v)) => (k, v->JSON.Encode.string))->Dict.fromArray->Js.Json.object_
        let body: array<(string, Js.Json.t)> = [
          ("payment_method", paymentMethod->Js.Json.string),
          (paymentMethod, pmdBody),
          ("customer_id", options.customerId->Js.Json.string),
        ]
        switch selectedPaymentMethodType {
        | Some(selectedPaymentMethodType) =>
          body->Array.push((
            "payment_method_type",
            selectedPaymentMethodType->getPaymentMethodType->Js.Json.string,
          ))
        | None => ()
        }
        // Create payment method
        open Promise
        PaymentHelpers.createPaymentMethod(
          ~clientSecret=keys.clientSecret->Option.getOr(""),
          ~publishableKey=keys.publishableKey,
          ~logger,
          ~switchToCustomPod=false,
          ~endpoint="http://localhost:8080",
          ~body,
        )
        ->then(res => {
          resolve()
        })
        ->catch(err => {
          Js.Console.log2("DEBUG ERR", err)
          resolve()
        })
        ->ignore
      }
    | None => Js.Console.log2("DEBUG", "Invalid data")
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
        <div className="merchant-title"> {React.string(merchantName)} </div>
      </div>
      // Collect widget
      <div id="collect" className="flex flex-row">
        <div className="collect-sidebar">
          {availablePaymentMethods
          ->Array.mapWithIndex((pm, i) => {
            <div key={Int.toString(i)} onClick={_e => setSelectedPaymentMethod(_ => pm)}>
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
          <button className="collect-submit" onClick={handleSubmit}>
            {React.string("SUBMIT")}
          </button>
        </div>
      </div>
    </div>
  }
}

let default = make
