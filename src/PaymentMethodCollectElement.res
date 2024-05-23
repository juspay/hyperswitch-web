open PaymentMethodCollectUtils
open PaymentMethodCollectTypes
open RecoilAtoms
open Utils

@react.component
let make = (~integrateError, ~logger) => {
  let keys = Recoil.useRecoilValueFromAtom(keys)
  let options = Recoil.useRecoilValueFromAtom(paymentMethodCollectOptionAtom)

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
  let (merchantName, setMerchantName) = React.useState(_ => options.collectorName)
  let (merchantLogo, setMerchantLogo) = React.useState(_ => options.logo)
  let (merchantTheme, setMerchantTheme) = React.useState(_ => options.theme)
  let (fieldValidityDict, setFieldValidityDict): (
    Js.Dict.t<option<bool>>,
    (Js.Dict.t<option<bool>> => Js.Dict.t<option<bool>>) => unit,
  ) = React.useState(_ => Dict.make())

  // DOM references
  let nameOnCardRef = React.useRef(Nullable.null)
  let cardNumberRef = React.useRef(Nullable.null)
  let expiryDateRef = React.useRef(Nullable.null)
  let routingNumberRef = React.useRef(Nullable.null)
  let accountNumberRef = React.useRef(Nullable.null)
  let sortCodeRef = React.useRef(Nullable.null)

  // Form a list of available payment methods
  React.useEffect(() => {
    let availablePMT = {
      card: [],
      bankTransfer: [],
      wallet: [],
    }
    let _ = options.enabledPaymentMethods->Array.map(pm => {
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

    let availablePM: array<paymentMethod> = []
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
  }, [options.enabledPaymentMethods])

  // Update merchant's name
  React.useEffect(() => {
    setMerchantName(_ => options.collectorName)
    None
  }, [options.collectorName])

  // Update merchant's logo
  React.useEffect(() => {
    setMerchantLogo(_ => options.logo)
    None
  }, [options.logo])

  React.useEffect(() => {
    setMerchantTheme(_ => options.theme)
    None
  }, [options.theme])

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
          <button
            key={Int.toString(i)}
            onClick={_ => setSelectedPaymentMethodType(_ => Some(BankTransfer(pmt)))}>
            {React.string(pmt->String.make)}
          </button>
        )
        ->React.array}
      </div>
    | Wallet =>
      <div>
        {availablePaymentMethodTypes.wallet
        ->Array.mapWithIndex((pmt, i) =>
          <button
            key={Int.toString(i)}
            onClick={_ => setSelectedPaymentMethodType(_ => Some(Wallet(pmt)))}>
            {React.string(pmt->String.make)}
          </button>
        )
        ->React.array}
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
          inputRef={nameOnCardRef}
          isFocus={true}
          isValid={fieldValidityDict->Dict.get("nameOnCard")->Option.getOr(None)}
          onChange={event => inputHandler(event, pmt, "nameOnCard")}
          setIsValid={updatedValidityFn => {
            setFieldValidity(
              "nameOnCard",
              updatedValidityFn(),
              fieldValidityDict,
              setFieldValidityDict,
            )
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
          inputRef={cardNumberRef}
          isFocus={true}
          isValid={fieldValidityDict->Dict.get("cardNumber")->Option.getOr(None)}
          onChange={event => inputHandler(event, pmt, "cardNumber")}
          setIsValid={updatedValidityFn => {
            setFieldValidity(
              "cardNumber",
              updatedValidityFn(),
              fieldValidityDict,
              setFieldValidityDict,
            )
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
          inputRef={expiryDateRef}
          isFocus={true}
          isValid={fieldValidityDict->Dict.get("expiryDate")->Option.getOr(None)}
          onChange={event => inputHandler(event, pmt, "expiryDate")}
          setIsValid={updatedValidityFn => {
            setFieldValidity(
              "expiryDate",
              updatedValidityFn(),
              fieldValidityDict,
              setFieldValidityDict,
            )
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
            <InputField
              id="routingNumber"
              fieldName="Routing Number"
              placeholder="110000000"
              maxLength=9
              value={getValueFromDict(paymentMethodData, "routingNumber")}
              paymentType={PaymentMethodCollectElement}
              inputRef={routingNumberRef}
              isFocus={true}
              isValid={fieldValidityDict->Dict.get("routingNumber")->Option.getOr(None)}
              onChange={event => inputHandler(event, pmt, "routingNumber")}
              setIsValid={updatedValidityFn => {
                setFieldValidity(
                  "routingNumber",
                  updatedValidityFn(),
                  fieldValidityDict,
                  setFieldValidityDict,
                )
              }}
              onBlur={_ev =>
                calculateAndSetValidity(
                  paymentMethodData,
                  "routingNumber",
                  fieldValidityDict,
                  setFieldValidityDict,
                )}
            />
            <InputField
              id="accountNumber"
              fieldName="Bank Account Number"
              placeholder="000123456789"
              maxLength=12
              value={getValueFromDict(paymentMethodData, "accountNumber")}
              paymentType={PaymentMethodCollectElement}
              inputRef={accountNumberRef}
              isFocus={true}
              isValid={fieldValidityDict->Dict.get("accountNumber")->Option.getOr(None)}
              onChange={event => inputHandler(event, pmt, "accountNumber")}
              setIsValid={updatedValidityFn => {
                setFieldValidity(
                  "accountNumber",
                  updatedValidityFn(),
                  fieldValidityDict,
                  setFieldValidityDict,
                )
              }}
              onBlur={_ev =>
                calculateAndSetValidity(
                  paymentMethodData,
                  "accountNumber",
                  fieldValidityDict,
                  setFieldValidityDict,
                )}
            />
          </React.Fragment>
        | Bacs =>
          <React.Fragment>
            <InputField
              id="sortCode"
              fieldName="Sort Code"
              placeholder="11000"
              maxLength=5
              value={getValueFromDict(paymentMethodData, "sortCode")}
              paymentType={PaymentMethodCollectElement}
              inputRef={sortCodeRef}
              isFocus={true}
              isValid={fieldValidityDict->Dict.get("sortCode")->Option.getOr(None)}
              onChange={event => inputHandler(event, pmt, "sortCode")}
              setIsValid={updatedValidityFn => {
                setFieldValidity(
                  "sortCode",
                  updatedValidityFn(),
                  fieldValidityDict,
                  setFieldValidityDict,
                )
              }}
              onBlur={_ev =>
                calculateAndSetValidity(
                  paymentMethodData,
                  "sortCode",
                  fieldValidityDict,
                  setFieldValidityDict,
                )}
            />
            <InputField
              id="accountNumber"
              fieldName="Bank Account Number"
              placeholder="28821822"
              maxLength=8
              value={getValueFromDict(paymentMethodData, "accountNumber")}
              paymentType={PaymentMethodCollectElement}
              inputRef={accountNumberRef}
              isFocus={true}
              isValid={fieldValidityDict->Dict.get("accountNumber")->Option.getOr(None)}
              onChange={event => inputHandler(event, pmt, "accountNumber")}
              setIsValid={updatedValidityFn => {
                setFieldValidity(
                  "accountNumber",
                  updatedValidityFn(),
                  fieldValidityDict,
                  setFieldValidityDict,
                )
              }}
              onBlur={_ev =>
                calculateAndSetValidity(
                  paymentMethodData,
                  "accountNumber",
                  fieldValidityDict,
                  setFieldValidityDict,
                )}
            />
          </React.Fragment>
        | Sepa =>
          <React.Fragment>
            <InputField
              id="iban"
              fieldName="International Bank Account Number (IBAN)"
              placeholder="NL42TEST0123456789"
              maxLength=18
              value={getValueFromDict(paymentMethodData, "iban")}
              paymentType={PaymentMethodCollectElement}
              inputRef={sortCodeRef}
              isFocus={true}
              isValid={fieldValidityDict->Dict.get("iban")->Option.getOr(None)}
              onChange={event => inputHandler(event, pmt, "iban")}
              setIsValid={updatedValidityFn => {
                setFieldValidity(
                  "iban",
                  updatedValidityFn(),
                  fieldValidityDict,
                  setFieldValidityDict,
                )
              }}
              onBlur={_ev =>
                calculateAndSetValidity(
                  paymentMethodData,
                  "iban",
                  fieldValidityDict,
                  setFieldValidityDict,
                )}
            />
            <InputField
              id="bic"
              fieldName="Bank Identifier Code"
              placeholder="ABNANL2A"
              maxLength=8
              value={getValueFromDict(paymentMethodData, "bic")}
              paymentType={PaymentMethodCollectElement}
              inputRef={accountNumberRef}
              isFocus={true}
              isValid={fieldValidityDict->Dict.get("bic")->Option.getOr(None)}
              onChange={event => inputHandler(event, pmt, "bic")}
              setIsValid={updatedValidityFn => {
                setFieldValidity(
                  "bic",
                  updatedValidityFn(),
                  fieldValidityDict,
                  setFieldValidityDict,
                )
              }}
              onBlur={_ev =>
                calculateAndSetValidity(
                  paymentMethodData,
                  "bic",
                  fieldValidityDict,
                  setFieldValidityDict,
                )}
            />
          </React.Fragment>
        }}
      </div>
    | Wallet(walletType) =>
      <div className="collect-wallet">
        {switch walletType {
        | Paypal | Venmo =>
          <React.Fragment>
            <InputField
              id="email"
              fieldName="Registered email ID"
              placeholder="paypal@gmail.com"
              value={getValueFromDict(paymentMethodData, "email")}
              paymentType={PaymentMethodCollectElement}
              inputRef={sortCodeRef}
              isFocus={true}
              isValid={fieldValidityDict->Dict.get("email")->Option.getOr(None)}
              onChange={event => inputHandler(event, pmt, "email")}
              setIsValid={updatedValidityFn => {
                setFieldValidity(
                  "email",
                  updatedValidityFn(),
                  fieldValidityDict,
                  setFieldValidityDict,
                )
              }}
              onBlur={_ev =>
                calculateAndSetValidity(
                  paymentMethodData,
                  "email",
                  fieldValidityDict,
                  setFieldValidityDict,
                )}
            />
            <InputField
              id="mobileNumber"
              fieldName="Registered Mobile Number (Optional)"
              placeholder="(555) 555-1234"
              value={getValueFromDict(paymentMethodData, "mobileNumber")}
              paymentType={PaymentMethodCollectElement}
              inputRef={accountNumberRef}
              isFocus={true}
              isValid={fieldValidityDict->Dict.get("mobileNumber")->Option.getOr(None)}
              onChange={event => inputHandler(event, pmt, "mobileNumber")}
              setIsValid={updatedValidityFn => {
                setFieldValidity(
                  "mobileNumber",
                  updatedValidityFn(),
                  fieldValidityDict,
                  setFieldValidityDict,
                )
              }}
              onBlur={_ev =>
                calculateAndSetValidity(
                  paymentMethodData,
                  "mobileNumber",
                  fieldValidityDict,
                  setFieldValidityDict,
                )}
            />
          </React.Fragment>
        | Pix =>
          <InputField
            id="pixId"
            fieldName="Pix ID"
            placeholder="paypal@gmail.com"
            value={getValueFromDict(paymentMethodData, "pixId")}
            paymentType={PaymentMethodCollectElement}
            inputRef={sortCodeRef}
            isFocus={true}
            isValid={fieldValidityDict->Dict.get("pixId")->Option.getOr(None)}
            onChange={event => inputHandler(event, pmt, "pixId")}
            setIsValid={updatedValidityFn => {
              setFieldValidity(
                "pixId",
                updatedValidityFn(),
                fieldValidityDict,
                setFieldValidityDict,
              )
            }}
            onBlur={_ev =>
              calculateAndSetValidity(
                paymentMethodData,
                "pixId",
                fieldValidityDict,
                setFieldValidityDict,
              )}
          />
        }}
      </div>
    }
  }

  let handleSubmit = _ev => {
    let pmdBody = formCreatePaymentMethodRequestBody(
      selectedPaymentMethodType,
      paymentMethodData,
      fieldValidityDict,
    )

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
          Js.Console.log2("DEBUG RES", res)
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
      <div className="flex flex-col merchant-header w-3/10">
        <div className="flex flex-row">
          <img className="h-8 w-auto merchant-logo" src={merchantLogo} alt="O" />
          <div className="merchant-title"> {React.string(merchantName)} </div>
        </div>
      </div>
      // Collect widget
      <div className="flex flex-row w-7/10">
        <div className="collect-sidebar">
          {availablePaymentMethods
          ->Array.mapWithIndex((pm, i) => {
            <button key={Int.toString(i)} onClick={_e => setSelectedPaymentMethod(_ => pm)}>
              {React.string(pm->String.make)}
            </button>
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
