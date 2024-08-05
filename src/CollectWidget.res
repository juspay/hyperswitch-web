open CardUtils
open PaymentMethodCollectTypes
open PaymentMethodCollectUtils
open RecoilAtoms

@react.component
let make = (
  ~availablePaymentMethods,
  ~availablePaymentMethodTypes,
  ~primaryTheme,
  ~handleSubmit,
  ~formLayout,
) => {
  let {constantString, localeString} = Recoil.useRecoilValueFromAtom(configAtom)
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

  // Update formLayout and availablePaymentMethodTypesOrdered
  React.useEffect1(() => {
    switch formLayout {
    | Tabs => setSelectedPaymentMethodType(_ => availablePaymentMethodTypes->Array.get(0))
    | _ => ()
    }
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

  // Helpers
  let resetForm = () => {
    setPaymentMethodData(_ => Dict.make())
    setFieldValidityDict(_ => Dict.make())
  }

  // Reset form on PMT updation
  React.useEffect(() => {
    resetForm()
    None
  }, [selectedPaymentMethodType])

  let handleBackClick = () => {
    switch savedPMD {
    | Some(_) => setSavedPMD(_ => None)
    | None =>
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
  }

  let getPaymentMethodDataValue = (key: paymentMethodDataField) =>
    paymentMethodData
    ->getValue(key->getPaymentMethodDataFieldKey)
    ->Option.getOr("")

  let setPaymentMethodDataValue = (key: paymentMethodDataField, value) =>
    setPaymentMethodData(_ => paymentMethodData->setValue(key->getPaymentMethodDataFieldKey, value))

  let validateAndSetPaymentMethodDataValue = (key: paymentMethodDataField, event) => {
    let value = ReactEvent.Form.target(event)["value"]
    let inputType = ReactEvent.Form.target(event)["type"]

    let (isValid, updatedValue) = switch (key, inputType, value) {
    // Empty string is valid (no error)
    | (_, _, "") => (true, "")
    | (CardExpDate, "number" | "tel", _) => {
        let formattedExpiry = formatCardExpiryNumber(value)
        if isExipryValid(formattedExpiry) {
          handleInputFocus(~currentRef=cardExpRef, ~destinationRef=cardHolderRef)
        }
        (true, formattedExpiry)
      }
    | (CardNumber, "number" | "tel", _) => {
        let cardType = getCardType(getPaymentMethodDataValue(CardBrand))
        let formattedCardNumber = formatCardNumber(value, cardType)
        if cardValid(clearSpaces(formattedCardNumber), getCardStringFromType(cardType)) {
          handleInputFocus(~currentRef=cardNumberRef, ~destinationRef=cardExpRef)
        }
        (true, formattedCardNumber)
      }
    | (SepaBic | SepaIban, "text", _) => (true, String.toUpperCase(value))

    // Default number validation
    | (_, "number" | "tel", _) =>
      try {
        let bigIntValue = Js.BigInt.fromStringExn(value)
        (true, Js.BigInt.toString(bigIntValue))
      } catch {
      | _ => (false, value)
      }

    // Default validation
    | (_, _, _) =>
      getPaymentMethodDataFieldCharacterPattern(key)
      // valid; in case there is no pattern setup
      ->Option.mapOr((true, value), regex =>
        regex->RegExp.test(value) ? (true, value) : (false, value)
      )
    }

    if isValid {
      switch key {
      | CardNumber => setPaymentMethodDataValue(CardBrand, getCardBrand(updatedValue))
      | _ => ()
      }
      setPaymentMethodDataValue(key, updatedValue)
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
    switch selectedPaymentMethod {
    | Some(_) =>
      <button
        className="bg-jp-gray-600 rounded-full h-7 w-7 self-center mr-5"
        onClick={_ => handleBackClick()}>
        {React.string("←")}
      </button>
    | None => React.null
    }
  }

  let renderContentHeader = () =>
    switch (savedPMD, selectedPaymentMethodType) {
    | (Some(_), _) => React.string(localeString.formHeaderReviewText)
    | (None, Some(pmt)) =>
      switch pmt {
      | Card(_) => React.string(localeString.formHeaderEnterCardText)
      | BankTransfer(bankTransferType) =>
        React.string(bankTransferType->String.make->localeString.formHeaderBankText)
      | Wallet(walletTransferType) =>
        React.string(walletTransferType->String.make->localeString.formHeaderWalletText)
      }
    | (None, None) =>
      switch selectedPaymentMethod {
      | Some(Card) => React.string(localeString.formHeaderEnterCardText)
      | Some(BankTransfer) => React.string(localeString.formHeaderSelectBankText)
      | Some(Wallet) => React.string(localeString.formHeaderSelectWalletText)
      | None => React.string(localeString.formHeaderSelectAccountText)
      }
    }

  let renderContentSubHeader = () =>
    switch savedPMD {
    | Some(pmd) =>
      switch pmd {
      | (Card, _, _) => React.string(localeString.formSubheaderCardText)
      | (pm, pmt, _) =>
        let pmtLabelString =
          pmt->getPaymentMethodTypeLabel ++ " " ++ pm->getPaymentMethodLabel->String.toLowerCase
        React.string(pmtLabelString->localeString.formSubheaderAccountText)
      }
    | None =>
      switch selectedPaymentMethod {
      | Some(_) => React.null
      | None => React.string(localeString.formFundsInfoText)
      }
    }

  let renderInfoTemplate = (label, value, uniqueKey) => {
    let labelClasses = "w-4/10 text-jp-gray-800 text-sm min-w-40 text-end"
    let valueClasses = "w-6/10 text-sm min-w-40"
    <div key={uniqueKey} className="flex flex-row items-center">
      <div className={labelClasses}> {React.string(label)} </div>
      <div className="mx-2.5 h-4 w-0.5 bg-jp-gray-300"> {React.string("")} </div>
      <div className={valueClasses}> {React.string(value)} </div>
    </div>
  }

  let renderFinalizeScreen = (pmd: paymentMethodData) => {
    let (paymentMethod, paymentMethodType, fields) = pmd
    <div>
      <div className="flex flex-col">
        {switch formLayout {
        | Tabs =>
          <div className="flex flex-row items-center mb-2.5 text-xl font-semibold">
            <img src={"merchantLogo"} alt="" className="h-6 w-auto" />
            <div className="ml-1.5">
              {React.string(
                paymentMethodType
                ->getPaymentMethodTypeLabel
                ->localeString.formHeaderReviewTabLayoutText,
              )}
            </div>
          </div>
        | Journey => React.null
        }}
        {fields
        ->Array.mapWithIndex((field, i) => {
          let (field, value) = field

          {
            renderInfoTemplate(
              field->getPaymentMethodDataFieldLabel(localeString),
              value,
              i->Int.toString,
            )
          }
        })
        ->React.array}
      </div>
      <div
        className="flex flex-row items-center min-w-full my-5 px-2.5 py-1.5 text-xs border border-solid border-blue-200 rounded bg-blue-50">
        <img src={"merchantLogo"} alt="" className="h-3 w-auto mr-1.5" />
        {React.string(
          paymentMethod
          ->getPaymentMethodLabel
          ->String.toLowerCase
          ->localeString.formFundsCreditInfoText,
        )}
      </div>
      <div className="flex my-5 text-lg font-semibold w-full">
        <button
          onClick={_ => setSavedPMD(_ => None)}
          disabled={submitted}
          className="w-full px-2.5 py-1.5 rounded border border-solid"
          style={color: primaryTheme, borderColor: primaryTheme}>
          {React.string(localeString.formEditText)}
        </button>
        <button
          onClick={_ => {
            setSubmitted(_ => true)
            handleSubmit(pmd)
          }}
          disabled={submitted}
          className="w-full px-2.5 py-1.5 text-white rounded ml-2.5"
          style={backgroundColor: primaryTheme}>
          {React.string(submitted ? localeString.formSubmittingText : localeString.formSubmitText)}
        </button>
      </div>
    </div>
  }

  let renderInputTemplate = (field: paymentMethodDataField) => {
    let isValid = field->getFieldValidity
    let labelClasses = "text-sm mt-2.5 text-jp-gray-800"
    let inputClasses = "min-w-full border mt-1.5 px-2.5 py-2 rounded-md border-jp-gray-200"
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
    let pattern =
      field
      ->getPaymentMethodDataFieldCharacterPattern
      ->Option.getOr(%re("/.*/"))
      ->Js.Re.source
    let value = field->getPaymentMethodDataValue
    let (errorString, errorStringClasses) = switch isValid {
    | Some(false) => (
        field->getPaymentMethodDataErrorString(value, localeString),
        "text-xs text-red-950",
      )
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
      fieldName={field->getPaymentMethodDataFieldLabel(localeString)}
      placeholder={field->getPaymentMethodDataFieldPlaceholder(localeString, constantString)}
      maxLength={field->getPaymentMethodDataFieldMaxLength}
      value
      onChange={event => field->validateAndSetPaymentMethodDataValue(event)}
      setIsValid={updatedValidityFn => field->setFieldValidity(updatedValidityFn())}
      onBlur={_ev => field->calculateAndSetValidity}
      type_={field->getPaymentMethodDataFieldInputType}
      pattern
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
            <>
              {ACHRoutingNumber->renderInputTemplate}
              {ACHAccountNumber->renderInputTemplate}
            </>
          | Bacs =>
            <>
              {BacsSortCode->renderInputTemplate}
              {BacsAccountNumber->renderInputTemplate}
            </>
          | Sepa =>
            <>
              {SepaIban->renderInputTemplate}
              {SepaBic->renderInputTemplate}
            </>
          }}
        </div>
      | Wallet(walletType) =>
        <div className="collect-wallet">
          {switch walletType {
          | Paypal =>
            <>
              {PaypalMail->renderInputTemplate}
              {PaypalMobNumber->renderInputTemplate}
            </>
          | Venmo => VenmoMobNumber->renderInputTemplate
          | Pix => PixId->renderInputTemplate
          }}
        </div>
      }}
      <button
        className="min-w-full mt-10 text-lg font-semibold px-2.5 py-1.5 text-white rounded"
        style={backgroundColor: primaryTheme}
        onClick={handleSave}>
        {React.string(localeString.formSaveText)}
      </button>
    </div>
  }

  let renderPMOptions = () =>
    <div className="flex flex-col mt-2.5">
      {availablePaymentMethods
      ->Array.mapWithIndex((pm, i) => {
        <button
          key={Int.toString(i)}
          onClick={_ => setSelectedPaymentMethod(_ => Some(pm))}
          className="flex flex-row items-center border border-solid border-jp-gray-200 px-5 py-2.5 rounded mt-2.5 hover:bg-jp-gray-50">
          {pm->getPaymentMethodIcon}
          <label className="text-start ml-2.5 cursor-pointer">
            {React.string(pm->String.make)}
          </label>
        </button>
      })
      ->React.array}
    </div>

  let renderPMTOptions = () => {
    let commonClasses = "flex flex-row items-center border border-solid border-jp-gray-200 px-5 py-2.5 rounded mt-2.5 hover:bg-jp-gray-50"
    let buttonTextClasses = "text-start ml-2.5"
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
    <div className="w-full">
      <div className="flex flex-row justify-start">
        <div className="flex justify-center items-center"> {renderBackButton()} </div>
        <div className="text-xl lg:text-3xl font-semibold"> {renderContentHeader()} </div>
      </div>
      <div className="text-base text-gray-500"> {renderContentSubHeader()} </div>
      <div className="mt-2.5">
        {switch savedPMD {
        | Some(pmd) => renderFinalizeScreen(pmd)
        | None =>
          switch selectedPaymentMethodType {
          | Some(pmt) => renderInputs(pmt)
          | None => renderPMTOptions()
          }
        }}
      </div>
    </div>
  }

  let handleTabSelection = selectedPMT => {
    if (
      availablePaymentMethodTypesOrdered->Array.indexOf(selectedPMT) >=
        defaultOptionsLimitInTabLayout
    ) {
      // Move the selected payment method at the last tab position
      let ordList = availablePaymentMethodTypes->Array.reduceWithIndex([], (acc, pmt, i) => {
        if i === defaultOptionsLimitInTabLayout - 1 {
          acc->Array.push(selectedPMT)
        }
        if pmt !== selectedPMT {
          acc->Array.push(pmt)
        }
        acc
      })
      setAvailablePaymentMethodTypesOrdered(_ => ordList)
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
    <div className="flex flex-col w-full min-w-[300px] max-w-[520px] lg:min-w-[400px]">
      <div>
        {
          let hiddenTabs = availablePaymentMethodTypesOrdered->Array.reduceWithIndex([], (
            options,
            pmt,
            i,
          ) => {
            if i >= limit {
              options->Array.push(
                <option
                  key={i->Int.toString}
                  value={pmt->getPaymentMethodTypeLabel}
                  className="flex items-center px-2.5 py-0.5 cursor-pointer hover:bg-jp-gray-50"
                  onClick={_ => handleTabSelection(pmt)}>
                  <div className="ml-2.5"> {React.string(pmt->getPaymentMethodTypeLabel)} </div>
                </option>,
              )
            }
            options
          })
          let visibleTabs = availablePaymentMethodTypesOrdered->Array.reduceWithIndex([], (
            items,
            pmt,
            i,
          ) => {
            if i < limit {
              items->Array.push(
                <div
                  key={i->Int.toString}
                  onClick={_ => setSelectedPaymentMethodType(_ => Some(pmt))}
                  className="flex w-full items-center rounded border border-solid border-jp-gray-700 px-2.5 py-1.5 mr-2.5 cursor-pointer hover:bg-jp-gray-50"
                  style={selectedPaymentMethodType === Some(pmt) ? activeStyles : defaultStyles}>
                  {pmt->getPaymentMethodTypeIcon}
                  <div className="ml-2.5"> {React.string(pmt->getPaymentMethodTypeLabel)} </div>
                </div>,
              )
            }
            items
          })
          switch savedPMD {
          | Some(pmd) => renderFinalizeScreen(pmd)
          | None =>
            <div>
              <div className="flex flex-row w-full">
                {visibleTabs->React.array}
                {<RenderIf condition={availablePaymentMethodTypesOrdered->Array.length > limit}>
                  <div className="relative">
                    <Icon
                      className="absolute z-10 pointer translate-x-2.5 translate-y-3.5 pointer-events-none"
                      name="arrow-down"
                      size=10
                    />
                    <select
                      className="h-full relative rounded border border-solid border-jp-gray-700 py-1.5 cursor-pointer bg-white text-transparent w-8 hover:bg-jp-gray-50 focus:border-0.5">
                      {switch selectedPaymentMethodType {
                      | Some(selectedPaymentMethodType) =>
                        <option
                          value={selectedPaymentMethodType->getPaymentMethodTypeLabel}
                          disabled={true}>
                          {React.string(selectedPaymentMethodType->getPaymentMethodTypeLabel)}
                        </option>
                      | None => React.null
                      }}
                      {hiddenTabs->React.array}
                    </select>
                  </div>
                </RenderIf>}
              </div>
              <div className="mt-5">
                {switch selectedPaymentMethodType {
                | Some(pmt) => renderInputs(pmt)
                | None => React.null
                }}
              </div>
            </div>
          }
        }
      </div>
    </div>
  }

  <div
    className="flex flex-col h-min p-6 items-center lg:rounded lg:shadow-lg lg:p-10 lg:min-w-[400px]">
    {switch formLayout {
    | Journey => renderJourneyScreen()
    | Tabs => renderTabScreen()
    }}
  </div>
}
let default = make
