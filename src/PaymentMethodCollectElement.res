open PaymentMethodCollectUtils
open PaymentMethodCollectTypes
open RecoilAtoms

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
  let (collectError, setCollectError) = React.useState(_ => None)
  let (paymentMethodData, setPaymentMethodData) = React.useState(_ => Dict.make())
  let (amount, setAmount) = React.useState(_ => options.amount)
  let (currency, setCurrency) = React.useState(_ => options.currency)
  let (flow, setFlow) = React.useState(_ => options.flow)
  let (linkId, setLinkId) = React.useState(_ => options.linkId)
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

  // Update amount
  React.useEffect(() => {
    setAmount(_ => options.amount)
    None
  }, [options.amount])

  // Update currency
  React.useEffect(() => {
    setCurrency(_ => options.currency)
    None
  }, [options.currency])

  // Update flow
  React.useEffect(() => {
    setFlow(_ => options.flow)
    None
  }, [options.flow])

  // Update linkId
  React.useEffect(() => {
    setLinkId(_ => options.linkId)
    None
  }, [options.linkId])

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

  // Update merchant's primary theme
  React.useEffect(() => {
    setMerchantTheme(_ => options.theme)
    None
  }, [options.theme])

  // Reset payment method type
  React.useEffect(() => {
    switch selectedPaymentMethod {
    | Some(Card) => setSelectedPaymentMethodType(_ => Some(Card(Debit)))
    | _ => setSelectedPaymentMethodType(_ => None)
    }

    None
  }, [selectedPaymentMethod])

  let handleBackClick = () => {
    switch selectedPaymentMethodType {
    | Some(Card(_)) => {
        setSelectedPaymentMethod(_ => None)
        setSelectedPaymentMethodType(_ => None)
      }
    | Some(_) => setSelectedPaymentMethodType(_ => None)
    | None =>
      switch selectedPaymentMethod {
      | Some(_) => setSelectedPaymentMethod(_ => None)
      | None => ()
      }
    }
  }

  let renderBackButton = () => {
    switch (selectedPaymentMethod, selectedPaymentMethodType) {
    | (Some(_), _) =>
      <button
        className="bg-jp-gray-600 rounded-full h-7 w-7 self-center"
        onClick={_ => handleBackClick()}>
        {React.string("←")}
      </button>
    | (None, _) => React.null
    }
  }

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
    | None =>
      switch selectedPaymentMethod {
      | Some(Card) => React.string("Enter card details")
      | Some(BankTransfer) => React.string("Select a bank method")
      | Some(Wallet) => React.string("Select a wallet")
      | None => React.string("Select an account for payouts")
      }
    }

  let renderContentSubHeader = () =>
    switch selectedPaymentMethod {
    | Some(_) => React.null
    | None => React.string("Funds will be credited to this account")
    }

  let renderPMOptions = () => {
    <div className="flex flex-col mt-[10px]">
      {availablePaymentMethods
      ->Array.mapWithIndex((pm, i) => {
        <button
          key={Int.toString(i)}
          onClick={_ => setSelectedPaymentMethod(_ => Some(pm))}
          className="text-start border border-solid border-jp-gray-400 px-[20px] py-[10px] rounded mt-[10px] hover:bg-jp-gray-50">
          {React.string(pm->String.make)}
        </button>
      })
      ->React.array}
    </div>
  }

  let renderPMTOptions = () => {
    let commonClasses = "text-start border border-solid border-jp-gray-400 px-[20px] py-[10px] rounded mt-[10px] hover:bg-jp-gray-50"
    <div className="flex flex-col">
      {switch selectedPaymentMethod {
      | Some(Card) => React.null
      | Some(BankTransfer) =>
        availablePaymentMethodTypes.bankTransfer
        ->Array.mapWithIndex((pmt, i) =>
          <button
            key={Int.toString(i)}
            onClick={_ => setSelectedPaymentMethodType(_ => Some(BankTransfer(pmt)))}
            className=commonClasses>
            {React.string(pmt->String.make)}
          </button>
        )
        ->React.array
      | Some(Wallet) =>
        availablePaymentMethodTypes.wallet
        ->Array.mapWithIndex((pmt, i) =>
          <button
            key={Int.toString(i)}
            onClick={_ => setSelectedPaymentMethodType(_ => Some(Wallet(pmt)))}
            className=commonClasses>
            {React.string(pmt->String.make)}
          </button>
        )
        ->React.array
      | None => renderPMOptions()
      }}
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

  let handleSubmit = _ev => {
    let pmdBody = formCreatePaymentMethodRequestBody(
      selectedPaymentMethodType,
      paymentMethodData,
      fieldValidityDict,
    )

    switch pmdBody {
    | Some(pmd) => {
        let pmdBody =
          pmd->Array.map(((k, v)) => (k, v->JSON.Encode.string))->Dict.fromArray->Js.Json.object_
        let body: array<(string, Js.Json.t)> = [("customer_id", options.customerId->Js.Json.string)]
        switch selectedPaymentMethod {
        | Some(selectedPaymentMethod) => {
            let paymentMethod = selectedPaymentMethod->getPaymentMethod
            body->Array.push(("payment_method", paymentMethod->Js.Json.string))
            body->Array.push((paymentMethod, pmdBody))
          }
        | None => ()
        }
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
    | None => {
        Js.Console.log2("DEBUG", "Invalid data")
        setCollectError(_ => Some("Invalid Data"))
      }
    }
  }

  let renderInputs = (pmt: paymentMethodType) => {
    let labelClasses = "text-[14px] text-jp-gray-800 mt-[10px]"
    let inputClasses = "min-w-full border-2 border-jp-gray-200 mt-[5px] px-[10px] py-[8px] rounded-lg"
    <div>
      {switch pmt {
      | Card(_) =>
        <div className="collect-card">
          <div className="flex flex-row">
            <div className="w-5/10">
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
                labelClassName=labelClasses
                className={inputClasses}
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
            </div>
            <div className="w-3/10 ml-[30px]">
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
                labelClassName=labelClasses
                className={inputClasses}
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
          </div>
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
            labelClassName=labelClasses
            className=inputClasses
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
                labelClassName=labelClasses
                className=inputClasses
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
                labelClassName=labelClasses
                className=inputClasses
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
                labelClassName=labelClasses
                className=inputClasses
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
                labelClassName=labelClasses
                className=inputClasses
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
                labelClassName=labelClasses
                className=inputClasses
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
                labelClassName=labelClasses
                className=inputClasses
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
                labelClassName=labelClasses
                className=inputClasses
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
                labelClassName=labelClasses
                className=inputClasses
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
              labelClassName=labelClasses
              className=inputClasses
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
      }}
      <button
        className="min-w-full mt-[40px] text-[18px] font-semibold px-[10px] py-[5px] text-white rounded"
        style={backgroundColor: merchantTheme}
        onClick={handleSubmit}>
        {React.string("SAVE")}
      </button>
    </div>
  }

  if integrateError {
    <ErrorOccured />
  } else {
    <div className="flex h-screen">
      {switch flow {
      | PayoutLinkInitiate =>
        <React.Fragment>
          // Merchant's info
          <div className="flex flex-col w-4/10 p-[50px]" style={backgroundColor: merchantTheme}>
            <div
              className="flex flex-col self-end min-w-fit rounded-md shadow-lg min-w-96"
              style={backgroundColor: "#FEFEFE"}>
              <div className="mx-[20px] mt-[20px] flex flex-row justify-between">
                <div className="font-bold text-[35px]">
                  {React.string(`${currency} ${amount->Int.toString}`)}
                </div>
                <img className="h-12 w-auto" src={merchantLogo} alt="O" />
              </div>
              <div className="mx-[20px]">
                <div className="self-center text-[20px] font-semibold">
                  {React.string("Payout from ")}
                  {React.string(merchantName)}
                </div>
                <div className="flex flex-row mt-[5px]">
                  <div className="font-semibold text-[12px]"> {React.string("Ref Id")} </div>
                  <div className="ml-[5px] text-[12px] text-gray-800"> {React.string(linkId)} </div>
                </div>
              </div>
              <div className="mt-[10px] px-[20px] py-[5px] bg-gray-200 text-[13px] rounded-b-lg">
                {React.string(`Link expires on: `)}
              </div>
            </div>
          </div>
          // Collect widget
          <div className="flex flex-row w-6/10 p-[50px] shadow-lg">
            <div className="shadow-lg rounded p-[40px] h-min min-w-96">
              <div className="flex flex-row justify-start">
                <div className="flex justify-center items-center"> {renderBackButton()} </div>
                <div className="ml-[20px] text-[30px] font-semibold"> {renderContentHeader()} </div>
              </div>
              <div className="text-[16px] text-center text-gray-500">
                {renderContentSubHeader()}
              </div>
              <div className="mt-[10px]">
                {switch selectedPaymentMethodType {
                | Some(pmt) => renderInputs(pmt)
                | None => renderPMTOptions()
                }}
              </div>
            </div>
          </div>
        </React.Fragment>

      | PayoutMethodCollect =>
        <React.Fragment>
          // Merchant's info
          <div className="flex flex-col w-3/10 p-[50px]" style={backgroundColor: merchantTheme}>
            <div className="flex flex-row">
              <img className="h-12 w-auto" src={merchantLogo} alt="O" />
              <div className="ml-[15px] text-white self-center text-[25px] font-bold">
                {React.string(merchantName)}
              </div>
            </div>
          </div>
          // Collect widget
          <div className="flex flex-row w-7/10 p-[50px] ml-[30px]">
            <div
              className="flex flex-col rounded-[2px] h-min-content border-2 border-jp-gray-200 mt-[60px]">
              {availablePaymentMethods
              ->Array.mapWithIndex((pm, i) => {
                let border = availablePaymentMethods->Array.length - 1 === i ? "" : "border-b-2"
                let paymentMethod = pm->String.make
                let background =
                  selectedPaymentMethod->String.make === paymentMethod ? "bg-blue-200" : ""
                let classes = `p-[10px] text-start ${border} ${background} hover:bg-blue-200`
                <button
                  key={Int.toString(i)}
                  onClick={_e => setSelectedPaymentMethod(_ => Some(pm))}
                  className={classes}>
                  {React.string(paymentMethod)}
                </button>
              })
              ->React.array}
            </div>
            <div className="ml-[30px] min-h-[250px]">
              <div className="text-[40px] font-bold"> {renderContentHeader()} </div>
              <div>
                {switch selectedPaymentMethodType {
                | Some(pmt) => renderInputs(pmt)
                | None => renderPMTOptions()
                }}
              </div>
            </div>
          </div>
        </React.Fragment>
      }}
    </div>
  }
}

let default = make
