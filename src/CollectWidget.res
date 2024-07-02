open CardUtils
open PaymentMethodCollectTypes
open PaymentMethodCollectUtils

@react.component
let make = (
  ~availablePaymentMethods,
  ~availablePaymentMethodTypes,
  ~primaryTheme,
  ~handleSubmit,
  ~formLayout,
) => {
  // Component states
  let (selectedPaymentMethod, setSelectedPaymentMethod) = React.useState(_ =>
    defaultSelectedPaymentMethod
  )
  let (selectedPaymentMethodType, setSelectedPaymentMethodType) = React.useState(_ =>
    defaultSelectedPaymentMethodType
  )
  let (
    availablePaymentMethodTypesOrdered,
    setAvailablePaymentMethodTypesOrdered,
  ) = React.useState(_ => availablePaymentMethodTypes)
  let (fieldValidityDict, setFieldValidityDict): (
    Dict.t<option<bool>>,
    (Dict.t<option<bool>> => Dict.t<option<bool>>) => unit,
  ) = React.useState(_ => Dict.make())
  let (savedPMD, setSavedPMD): (
    option<paymentMethodData>,
    (option<paymentMethodData> => option<paymentMethodData>) => unit,
  ) = React.useState(_ => None)
  let (submitted, setSubmitted) = React.useState(_ => false)
  let (paymentMethodData, setPaymentMethodData) = React.useState(_ => Dict.make())

  // Input DOM references
  let inputRef = React.useRef(Nullable.null)
  let cardNumberRef = React.useRef(Nullable.null)
  let cardExpRef = React.useRef(Nullable.null)
  let cardHolderRef = React.useRef(Nullable.null)
  let routingNumberRef = React.useRef(Nullable.null)
  let achAccNumberRef = React.useRef(Nullable.null)
  let bacsSortCodeRef = React.useRef(Nullable.null)
  let bacsAccNumberRef = React.useRef(Nullable.null)
  let ibanRef = React.useRef(Nullable.null)
  let sepaBicRef = React.useRef(Nullable.null)
  let bankNameRef = React.useRef(Nullable.null)
  let bankCityRef = React.useRef(Nullable.null)
  let countryCodeRef = React.useRef(Nullable.null)

  // Update availablePaymentMethodTypesOrdered
  React.useEffect(() => {
    setAvailablePaymentMethodTypesOrdered(_ => availablePaymentMethodTypes)
    None
  }, [availablePaymentMethodTypes])

  // Reset payment method type
  React.useEffect(() => {
    switch selectedPaymentMethod {
    | Some(Card) => setSelectedPaymentMethodType(_ => Some(Card(Debit)))
    | _ => setSelectedPaymentMethodType(_ => None)
    }

    None
  }, [selectedPaymentMethod])

  // Init
  React.useEffect1(() => {
    switch formLayout {
    | Tabs => setSelectedPaymentMethodType(_ => availablePaymentMethodTypes->Array.get(0))
    | _ => ()
    }
    None
  }, [availablePaymentMethodTypes])

  // Helpers
  let resetForm = () => {
    setPaymentMethodData(_ => Dict.make())
    setFieldValidityDict(_ => Dict.make())
  }

  let handleBackClick = () => {
    switch savedPMD {
    | Some(_) => setSavedPMD(_ => None)
    | None =>
      switch selectedPaymentMethodType {
      | Some(Card(_)) => {
          setSelectedPaymentMethod(_ => None)
          setSelectedPaymentMethodType(_ => None)
          resetForm()
        }
      | Some(_) => setSelectedPaymentMethodType(_ => None)
      | None =>
        switch selectedPaymentMethod {
        | Some(_) => {
            setSelectedPaymentMethod(_ => None)
            resetForm()
            ()
          }
        | None => ()
        }
      }
    }
  }

  let getPaymentMethodDataValue = (key: paymentMethodDataField) =>
    paymentMethodData
    ->getValue(key->getPaymentMethodDataFieldKey)
    ->Option.getOr("")

  let setPaymentMethodDataValue = (key: paymentMethodDataField, value) =>
    setPaymentMethodData(_ => paymentMethodData->setValue(key->getPaymentMethodDataFieldKey, value))

  let validateAndSetPaymentMethodDataValue = (key: paymentMethodDataField, event) => {
    let ev = ReactEvent.Form.target(event)
    let value = ev["value"]
    let inputType = ev["type"]

    let (isValidChar, updatedValue) = switch value {
    // Empty string is valid
    | "" => (true, value)
    // Validate in case there's a value present
    | value => {
        // Validate based on input's type
        let (isValidChar, updatedValue, shouldContinue) = switch inputType {
        | "number" | "tel" =>
          switch key {
          | CardExpDate => {
              let formattedExpiry = value->formatCardExpiryNumber
              if formattedExpiry->isExipryValid {
                handleInputFocus(~currentRef=cardExpRef, ~destinationRef=cardHolderRef)
              }
              (true, formattedExpiry, false)
            }
          | CardNumber => {
              let cardType = CardBrand->getPaymentMethodDataValue->getCardType
              let formattedCardNumber = value->formatCardNumber(cardType)
              if cardValid(formattedCardNumber->clearSpaces, cardType->getCardStringFromType) {
                handleInputFocus(~currentRef=cardNumberRef, ~destinationRef=cardExpRef)
              }
              (true, formattedCardNumber, false)
            }
          | _ =>
            try {
              let value = value->Js.BigInt.fromStringExn->Js.BigInt.toString
              (true, value, true)
            } catch {
            | _ => (false, value, false)
            }
          }
        | "text" =>
          let value = switch key {
          | SepaBic
          | SepaIban =>
            value->String.toUpperCase
          | _ => value
          }
          (true, value, true)
        | _ => (true, value, false)
        }

        if shouldContinue {
          let regex = key->getPaymentMethodDataFieldCharacterPattern
          switch regex->RegExp.exec(updatedValue) {
          | Some(_) => (true, updatedValue)
          | None => (false, updatedValue)
          }
        } else {
          (isValidChar, updatedValue)
        }
      }
    }

    if isValidChar {
      switch key {
      | CardNumber => {
          CardBrand->setPaymentMethodDataValue(updatedValue->getCardBrand)
          key->setPaymentMethodDataValue(updatedValue)
        }
      | _ => key->setPaymentMethodDataValue(updatedValue)
      }
    }
  }

  let setFieldValidity = (key: paymentMethodDataField, value) => {
    let fieldValidityCopy = fieldValidityDict->Dict.copy
    fieldValidityCopy->Dict.set(key->getPaymentMethodDataFieldKey, value)
    setFieldValidityDict(_ => fieldValidityCopy)
  }

  let getFieldValidity = (key: paymentMethodDataField) =>
    fieldValidityDict->Dict.get(key->getPaymentMethodDataFieldKey)->Option.getOr(None)

  let calculateAndSetValidity = (key: paymentMethodDataField) => {
    let updatedValidity = paymentMethodData->calculateValidity(key)
    key->setFieldValidity(updatedValidity)
  }

  let handleSave = _ev => {
    let pmd = formPaymentMethodData(selectedPaymentMethodType, paymentMethodData, fieldValidityDict)
    setSavedPMD(_ => pmd)
  }

  // UI renders
  let renderBackButton = () => {
    switch (selectedPaymentMethod, selectedPaymentMethodType) {
    | (Some(_), _) =>
      <button
        className="bg-jp-gray-600 rounded-full h-7 w-7 self-center mr-[20px]"
        onClick={_ => handleBackClick()}>
        {React.string("←")}
      </button>
    | _ => React.null
    }
  }

  let renderContentHeader = () =>
    switch (savedPMD, selectedPaymentMethodType) {
    | (Some(_), _) => React.string("Review")
    | (None, Some(pmt)) =>
      switch pmt {
      | Card(_) => React.string("Enter card details")
      | BankTransfer(bankTransferType) =>
        React.string("Enter " ++ bankTransferType->String.make ++ " bank details ")
      | Wallet(walletTransferType) =>
        React.string("Enter " ++ walletTransferType->String.make ++ " wallet details ")
      }
    | (None, None) =>
      switch selectedPaymentMethod {
      | Some(Card) => React.string("Enter card details")
      | Some(BankTransfer) => React.string("Select a bank method")
      | Some(Wallet) => React.string("Select a wallet")
      | None => React.string("Select an account for payouts")
      }
    }

  let renderContentSubHeader = () =>
    switch savedPMD {
    | Some(pmd) =>
      switch pmd {
      | (Card, _, _) => React.string("Your card details")
      | (pm, pmt, _) =>
        React.string(
          `Your ${pmt->getPaymentMethodTypeLabel} ${pm
            ->getPaymentMethodLabel
            ->String.toLowerCase}`,
        )
      }
    | None =>
      switch selectedPaymentMethod {
      | Some(_) => React.null
      | None => React.string("Funds will be credited to this account")
      }
    }

  let renderInfoTemplate = (label, value, uniqueKey) => {
    let labelClasses = "w-4/10 text-jp-gray-800 text-[14px] min-w-40 text-end"
    let valueClasses = "w-6/10 text-[14px] min-w-40"
    <div key={uniqueKey} className="flex flex-row items-center">
      <div className={labelClasses}> {React.string(label)} </div>
      <div className="mx-[10px] h-[15px] w-[2px] bg-jp-gray-300"> {React.string("")} </div>
      <div className={valueClasses}> {React.string(value)} </div>
    </div>
  }

  let renderFinalizeScreen = (pmd: paymentMethodData) => {
    let (paymentMethod, paymentMethodType, fields) = pmd
    <div>
      <div className="flex flex-col">
        {switch formLayout {
        | Tabs =>
          <div className="flex flex-row items-center mb-[10px] text-[20px] font-semibold">
            <img src={"merchantLogo"} alt="" className="h-[25px] w-auto" />
            <div className="ml-[5px]">
              {React.string(`Review your ${paymentMethodType->getPaymentMethodTypeLabel} details`)}
            </div>
          </div>
        | Journey => React.null
        }}
        {fields
        ->Array.mapWithIndex((field, i) => {
          let (field, value) = field
          {renderInfoTemplate(field->getPaymentMethodDataFieldLabel, value, i->Int.toString)}
        })
        ->React.array}
      </div>
      <div
        className="flex flex-row items-center min-w-full mt-[20px] py-[5px] px-[10px] text-[13px] border border-solid border-blue-200 rounded bg-blue-50">
        <img src={"merchantLogo"} alt="" className="h-[12px] w-auto mr-[5px]" />
        {React.string(
          `Your funds will be deposited in the selected ${paymentMethod
            ->getPaymentMethodLabel
            ->String.toLowerCase}.`,
        )}
      </div>
      <div className="flex mt-[20px] text-[18px] font-semibold w-full">
        <button
          onClick={_ => setSavedPMD(_ => None)}
          disabled={submitted}
          className="w-full px-[10px] py-[5px] rounded border border-solid"
          style={color: primaryTheme, borderColor: primaryTheme}>
          {React.string("Edit")}
        </button>
        <button
          onClick={_ => {
            setSubmitted(_ => true)
            handleSubmit(pmd)
          }}
          disabled={submitted}
          className="w-full px-[10px] py-[5px] text-white rounded ml-[10px]"
          style={backgroundColor: primaryTheme}>
          {React.string(submitted ? "Submitting ..." : "Submit")}
        </button>
      </div>
    </div>
  }

  let renderInputTemplate = (field: paymentMethodDataField) => {
    let isValid = field->getFieldValidity
    let labelClasses = "text-[14px] mt-[10px] text-jp-gray-800"
    let inputClasses = "min-w-full border mt-[5px] px-[10px] py-[8px] rounded-md border-jp-gray-200"
    let inputRef = switch field {
    | CardNumber => cardNumberRef
    | CardExpDate => cardExpRef
    | CardHolderName => cardHolderRef
    | ACHRoutingNumber => routingNumberRef
    | ACHAccountNumber => achAccNumberRef
    | BacsSortCode => bacsSortCodeRef
    | BacsAccountNumber => bacsAccNumberRef
    | SepaIban => ibanRef
    | SepaBic => sepaBicRef
    // Union
    | BacsBankName
    | ACHBankName
    | SepaBankName => bankNameRef
    | BacsBankCity
    | ACHBankCity
    | SepaBankCity => bankCityRef
    | SepaCountryCode => countryCodeRef
    | _ => inputRef
    }
    let value = field->getPaymentMethodDataValue
    let (errorString, errorStringClasses) = switch isValid {
    | Some(false) => (field->getPaymentMethodDataErrorString(value), "text-[12px] text-red-950")
    | _ => ("", "")
    }
    <InputField
      id={field->getPaymentMethodDataFieldKey}
      className=inputClasses
      labelClassName=labelClasses
      paymentType={PaymentMethodCollectElement}
      inputRef
      isFocus={true}
      isValid={None}
      errorString
      errorStringClasses
      fieldName={field->getPaymentMethodDataFieldLabel}
      placeholder={field->getPaymentMethodDataFieldPlaceholder}
      maxLength={field->getPaymentMethodDataFieldMaxLength}
      value
      onChange={event => field->validateAndSetPaymentMethodDataValue(event)}
      setIsValid={updatedValidityFn => field->setFieldValidity(updatedValidityFn())}
      onBlur={_ev => field->calculateAndSetValidity}
      type_={field->getPaymentMethodDataFieldInputType}
      pattern={field->getPaymentMethodDataFieldCharacterPattern->Js.Re.source}
    />
  }

  let renderInputs = (pmt: paymentMethodType) => {
    <div>
      {switch pmt {
      | Card(_) =>
        <div className="collect-card">
          {CardNumber->renderInputTemplate}
          <div className="max-w-80"> {CardExpDate->renderInputTemplate} </div>
          {CardHolderName->renderInputTemplate}
        </div>
      | BankTransfer(bankTransferType) =>
        <div className="collect-bank">
          {switch bankTransferType {
          | ACH =>
            <React.Fragment>
              {ACHRoutingNumber->renderInputTemplate}
              {ACHAccountNumber->renderInputTemplate}
            </React.Fragment>
          | Bacs =>
            <React.Fragment>
              {BacsSortCode->renderInputTemplate}
              {BacsAccountNumber->renderInputTemplate}
            </React.Fragment>
          | Sepa =>
            <React.Fragment>
              {SepaIban->renderInputTemplate}
              {SepaBic->renderInputTemplate}
            </React.Fragment>
          }}
        </div>
      | Wallet(walletType) =>
        <div className="collect-wallet">
          {switch walletType {
          | Paypal =>
            <React.Fragment>
              {PaypalMail->renderInputTemplate}
              {PaypalMobNumber->renderInputTemplate}
            </React.Fragment>
          | Venmo => <React.Fragment> {VenmoMobNumber->renderInputTemplate} </React.Fragment>
          | Pix => PixId->renderInputTemplate
          }}
        </div>
      }}
      <button
        className="min-w-full mt-[40px] text-[18px] font-semibold px-[10px] py-[5px] text-white rounded"
        style={backgroundColor: primaryTheme}
        onClick={handleSave}>
        {React.string("Save")}
      </button>
    </div>
  }

  let renderPMOptions = () =>
    <div className="flex flex-col mt-[10px]">
      {availablePaymentMethods
      ->Array.mapWithIndex((pm, i) => {
        <button
          key={Int.toString(i)}
          onClick={_ => setSelectedPaymentMethod(_ => Some(pm))}
          className="flex flex-row items-center border border-solid border-jp-gray-200 px-[20px] py-[10px] rounded mt-[10px] hover:bg-jp-gray-50">
          {pm->getPaymentMethodIcon}
          <label className="text-start ml-[10px] cursor-pointer">
            {React.string(pm->String.make)}
          </label>
        </button>
      })
      ->React.array}
    </div>

  let renderPMTOptions = () => {
    let commonClasses = "flex flex-row items-center border border-solid border-jp-gray-200 px-[20px] py-[10px] rounded mt-[10px] hover:bg-jp-gray-50"
    let buttonTextClasses = "text-start ml-[10px]"
    <div className="flex flex-col">
      {switch selectedPaymentMethod {
      | Some(Card) => React.null
      | Some(BankTransfer) =>
        availablePaymentMethodTypes
        ->Array.filterMap(pmt =>
          switch pmt {
          | BankTransfer(bank) => Some(bank)
          | _ => None
          }
        )
        ->Array.mapWithIndex((pmt, i) =>
          <button
            key={Int.toString(i)}
            onClick={_ => setSelectedPaymentMethodType(_ => Some(BankTransfer(pmt)))}
            className=commonClasses>
            {pmt->getBankTransferIcon}
            <label className={buttonTextClasses}> {React.string(pmt->String.make)} </label>
          </button>
        )
        ->React.array
      | Some(Wallet) =>
        availablePaymentMethodTypes
        ->Array.filterMap(pmt =>
          switch pmt {
          | Wallet(wallet) => Some(wallet)
          | _ => None
          }
        )
        ->Array.mapWithIndex((pmt, i) =>
          <button
            key={Int.toString(i)}
            onClick={_ => setSelectedPaymentMethodType(_ => Some(Wallet(pmt)))}
            className=commonClasses>
            {pmt->getWalletIcon}
            <label className={buttonTextClasses}> {React.string(pmt->String.make)} </label>
          </button>
        )
        ->React.array
      | None => renderPMOptions()
      }}
    </div>
  }

  let renderJourneyScreen = () => {
    <React.Fragment>
      <div className="flex flex-row justify-start">
        <div className="flex justify-center items-center"> {renderBackButton()} </div>
        <div className="text-[20px] lg:text-[30px] font-semibold"> {renderContentHeader()} </div>
      </div>
      <div className="text-[16px] text-gray-500"> {renderContentSubHeader()} </div>
      <div className="mt-[10px]">
        {switch savedPMD {
        | Some(pmd) => renderFinalizeScreen(pmd)
        | None =>
          switch selectedPaymentMethodType {
          | Some(pmt) => renderInputs(pmt)
          | None => renderPMTOptions()
          }
        }}
      </div>
    </React.Fragment>
  }

  let handleTabSelection = selectedPMT => {
    if availablePaymentMethodTypes->Array.indexOf(selectedPMT) > 0 {
      // Insert the selected payment method at top, and
      // concat rest of the payment method types (removing itself from the array)
      let start = defaultOptionsLimitInTabLayout - 1
      let remove = availablePaymentMethodTypes->Array.length - start
      let insert =
        [selectedPMT]->Array.concat(
          availablePaymentMethodTypes->Array.filterWithIndex((pmt, i) =>
            !(i < start || pmt === selectedPMT)
          ),
        )
      availablePaymentMethodTypes->Array.splice(~start, ~remove, ~insert)
      setAvailablePaymentMethodTypesOrdered(_ => availablePaymentMethodTypes)
    }
    setSelectedPaymentMethodType(_ => Some(selectedPMT))
  }

  let renderTabScreen = (~limit=defaultOptionsLimitInTabLayout) => {
    let activeStyles: JsxDOM.style = {
      borderColor: primaryTheme,
      borderWidth: "2px",
      color: primaryTheme,
    }
    let defaultStyles: JsxDOM.style = {
      borderColor: "#9A9FA8",
      borderWidth: "1px",
      color: primaryTheme,
    }
    // tabs
    <div
      className="flex flex-col w-full min-w-[300px] max-w-[520px]
      lg:min-w-[400px]">
      <div>
        {switch savedPMD {
        | Some(pmd) => renderFinalizeScreen(pmd)
        | None =>
          <div>
            <div className="flex flex-row w-full">
              {availablePaymentMethodTypesOrdered
              ->Array.reduceWithIndex([], (items, pmt, i) => {
                if i < limit {
                  items->Array.push(
                    <div
                      key={i->Int.toString}
                      onClick={_ => setSelectedPaymentMethodType(_ => Some(pmt))}
                      className="flex w-full items-center rounded border border-solid border-jp-gray-700 px-[10px] py-[5px] mr-[10px] cursor-pointer hover:bg-jp-gray-50"
                      style={selectedPaymentMethodType === Some(pmt)
                        ? activeStyles
                        : defaultStyles}>
                      {pmt->getPaymentMethodTypeIcon}
                      <div className="ml-[10px]">
                        {React.string(pmt->getPaymentMethodTypeLabel)}
                      </div>
                    </div>,
                  )
                }
                items
              })
              ->React.array}
              {if availablePaymentMethodTypesOrdered->Array.length > limit {
                <div className="relative">
                  <Icon
                    className="absolute z-10 pointer translate-x-2.5 translate-y-3.5 pointer-events-none"
                    name="arrow-down"
                    size=10
                  />
                  <select
                    className="h-full relative rounded border border-solid border-jp-gray-700 py-[5px] cursor-pointer bg-white text-transparent w-[30px]
                    hover:bg-jp-gray-50 focus:border-[2px]">
                    {switch selectedPaymentMethodType {
                    | Some(selectedPaymentMethodType) =>
                      <option value="pmt->getPaymentMethodTypeLabel" disabled={true}>
                        {React.string(selectedPaymentMethodType->getPaymentMethodTypeLabel)}
                      </option>
                    | None => React.null
                    }}
                    {availablePaymentMethodTypesOrdered
                    ->Array.reduceWithIndex([], (options, pmt, i) => {
                      if i >= limit {
                        options->Array.push(
                          <option
                            key={i->Int.toString}
                            value={pmt->getPaymentMethodTypeLabel}
                            className="flex items-center px-[10px] py-[3px] cursor-pointer hover:bg-jp-gray-50"
                            onClick={_ => handleTabSelection(pmt)}>
                            <div className="ml-[10px]">
                              {React.string(pmt->getPaymentMethodTypeLabel)}
                            </div>
                          </option>,
                        )
                      }
                      options
                    })
                    ->React.array}
                  </select>
                </div>
              } else {
                React.null
              }}
            </div>
            <div className="mt-[20px]">
              {switch selectedPaymentMethodType {
              | Some(pmt) => renderInputs(pmt)
              | None => React.null
              }}
            </div>
          </div>
        }}
      </div>
    </div>
  }

  <div
    className="flex flex-col h-min p-[25px] items-center
      lg:rounded lg:shadow-lg lg:p-[40px] lg:min-w-[400px]">
    {switch formLayout {
    | Journey => renderJourneyScreen()
    | Tabs => renderTabScreen()
    }}
  </div>
}
let default = make
