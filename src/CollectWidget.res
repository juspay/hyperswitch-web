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
  ~formLayout: formLayout,
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
  let (submitted, setSubmitted) = React.useState(_ => false)
  let (paymentMethodData, setPaymentMethodData) = React.useState(_ => Dict.make())
  let (currentView, setCurrentView) = React.useState(_ => defaultView)

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

  // Update widget screens and availablePaymentMethodTypesOrdered
  React.useEffect1(() => {
    switch formLayout {
    | Tabs => {
        setSelectedPaymentMethodType(_ => availablePaymentMethodTypes->Array.get(0))
        availablePaymentMethodTypes
        ->Array.get(0)
        ->Option.map(availablePMT => {
          Js.Console.log2("INIT WIDGET", availablePMT)
          switch availablePMT {
          | Card(info) => setCurrentView(_ => Tabs(DetailsForm(Card, Card(info))))
          | BankTransfer(info) =>
            setCurrentView(_ => Tabs(DetailsForm(BankTransfer, BankTransfer(info))))
          | Wallet(info) => setCurrentView(_ => Tabs(DetailsForm(Wallet, Wallet(info))))
          }
        })
        ->ignore
      }
    | Journey => setCurrentView(_ => Journey(defaultJourneyView))
    }
    setAvailablePaymentMethodTypesOrdered(_ => availablePaymentMethodTypes)
    None
  }, [availablePaymentMethodTypes])

  // Reset payment method type
  React.useEffect(() => {
    selectedPaymentMethod
    ->Option.map(selectedPaymentMethod =>
      switch selectedPaymentMethod {
      | Card =>
        setSelectedPaymentMethodType(
          _ =>
            availablePaymentMethodTypes->Array.find(
              pmt =>
                switch pmt {
                | Card((_, _)) => true
                | _ => false
                },
            ),
        )
      | _ => setSelectedPaymentMethodType(_ => None)
      }
    )
    ->ignore
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

  let updateScreenForRenderingForm = (pm, pmt) => {
    switch currentView {
    | Journey(_) =>
      switch pmt {
      | Card((_, requiredFields))
      | BankTransfer((_, requiredFields))
      | Wallet((_, requiredFields)) =>
        if requiredFields.address->Option.isSome {
          requiredFields.address
          ->Option.map(address => {
            setCurrentView(_ => Journey(AddressForm(pm, pmt, address)))
          })
          ->ignore
        } else if requiredFields.payoutMethodData->Option.isSome {
          requiredFields.payoutMethodData
          ->Option.map(payoutMethodData => {
            setCurrentView(_ => Journey(PMDForm(pm, pmt, payoutMethodData)))
          })
          ->ignore
        } else {
          ()
        }
      }
    | Tabs(_) => setCurrentView(_ => Tabs(DetailsForm(pm, pmt)))
    }
  }

  let getFieldTypeForFieldInfo = (key: requiredFieldInfo) => {
    switch key {
    | BillingAddress(fields) => BillingAddress(fields.fieldType)
    | PayoutMethodData(fields) => PayoutMethodData(fields.fieldType)
    }
  }

  let getPaymentMethodDataValue = (key: requiredFieldType) =>
    paymentMethodData
    ->getValue(key->getPaymentMethodDataFieldKey)
    ->Option.getOr("")

  let setPaymentMethodDataValue = (key: requiredFieldType, value) =>
    setPaymentMethodData(_ => paymentMethodData->setValue(key->getPaymentMethodDataFieldKey, value))

  let validateAndSetPaymentMethodDataValue = (key: requiredFieldType, event) => {
    let value = ReactEvent.Form.target(event)["value"]
    let inputType = ReactEvent.Form.target(event)["type"]

    let (isValid, updatedValue) = switch (key, inputType, value) {
    // Empty string is valid (no error)
    | (_, _, "") => (true, "")
    | (PayoutMethodData(CardExpDate(_)), "number" | "tel", _) => {
        let formattedExpiry = formatCardExpiryNumber(value)
        if isExipryValid(formattedExpiry) {
          handleInputFocus(~currentRef=cardExpRef, ~destinationRef=cardHolderRef)
        }
        (true, formattedExpiry)
      }
    | (PayoutMethodData(CardNumber), "number" | "tel", _) => {
        let cardType = getCardType(getPaymentMethodDataValue(PayoutMethodData(CardBrand)))
        let formattedCardNumber = formatCardNumber(value, cardType)
        if cardValid(clearSpaces(formattedCardNumber), getCardStringFromType(cardType)) {
          handleInputFocus(~currentRef=cardNumberRef, ~destinationRef=cardExpRef)
        }
        (true, formattedCardNumber)
      }
    | (PayoutMethodData(SepaBic) | PayoutMethodData(SepaIban), "text", _) => (
        true,
        String.toUpperCase(value),
      )

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
      | PayoutMethodData(CardNumber) =>
        setPaymentMethodDataValue(PayoutMethodData(CardBrand), getCardBrand(updatedValue))
      | _ => ()
      }
      setPaymentMethodDataValue(key, updatedValue)
    }
  }

  let setFieldValidity = (key: requiredFieldType, value) => {
    let fieldValidityCopy = fieldValidityDict->Dict.copy
    fieldValidityCopy->Dict.set(key->getPaymentMethodDataFieldKey, value)
    setFieldValidityDict(_ => fieldValidityCopy)
  }

  let getFieldValidity = (key: requiredFieldType) =>
    fieldValidityDict->Dict.get(key->getPaymentMethodDataFieldKey)->Option.getOr(None)

  let calculateAndSetValidity = (key: requiredFieldType) => {
    let updatedValidity = paymentMethodData->calculateValidity(key)
    key->setFieldValidity(updatedValidity)
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

  let renderFinalizeScreen = (
    _selectedPaymentMethod,
    selectedPaymentMethodType,
    pmd: paymentMethodData,
  ) => {
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
              field->getFieldTypeForFieldInfo->getPaymentMethodDataFieldLabel(localeString),
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
          onClick={_ => {
            switch selectedPaymentMethodType {
            | Card(info) => updateScreenForRenderingForm(Card, Card(info))
            | BankTransfer(info) => updateScreenForRenderingForm(BankTransfer, BankTransfer(info))
            | Wallet(info) => updateScreenForRenderingForm(Wallet, Wallet(info))
            }
          }}
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

  let renderInputTemplate = (field: requiredFieldType) => {
    let isValid = field->getFieldValidity
    let labelClasses = "text-sm mt-2.5 text-jp-gray-800"
    let inputClasses = "min-w-full border mt-1.5 px-2.5 py-2 rounded-md border-jp-gray-200"
    let inputRef = switch field {
    | PayoutMethodData(CardNumber) => cardNumberRef
    | PayoutMethodData(CardExpDate(_)) => cardExpRef
    | PayoutMethodData(CardHolderName) => cardHolderRef
    | PayoutMethodData(ACHRoutingNumber) => routingNumberRef
    | PayoutMethodData(ACHAccountNumber) => achAccNumberRef
    | PayoutMethodData(BacsSortCode) => bacsSortCodeRef
    | PayoutMethodData(BacsAccountNumber) => bacsAccNumberRef
    | PayoutMethodData(SepaIban) => ibanRef
    | PayoutMethodData(SepaBic) => sepaBicRef
    // Union
    | PayoutMethodData(BacsBankName)
    | PayoutMethodData(ACHBankName)
    | PayoutMethodData(SepaBankName) => bankNameRef
    | PayoutMethodData(BacsBankCity)
    | PayoutMethodData(ACHBankCity)
    | PayoutMethodData(SepaBankCity) => bankCityRef
    | PayoutMethodData(SepaCountryCode) => countryCodeRef
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

  let handleAddressSave = (selectedPaymentMethod, selectedPaymentMethodType) =>
    formPaymentMethodData(selectedPaymentMethodType, paymentMethodData, fieldValidityDict)
    ->Option.map(payoutMethodData => {
      switch currentView {
      | Journey(_) =>
        switch selectedPaymentMethodType {
        | Card((_, requiredFields))
        | BankTransfer((_, requiredFields))
        | Wallet((_, requiredFields)) =>
          requiredFields.payoutMethodData
          ->Option.map(payoutMethodFields => {
            setCurrentView(
              _ => Journey(
                PMDForm(selectedPaymentMethod, selectedPaymentMethodType, payoutMethodFields),
              ),
            )
          })
          ->ignore
        }
      | Tabs(_) =>
        setCurrentView(_ => Tabs(
          FinalizeView(selectedPaymentMethod, selectedPaymentMethodType, payoutMethodData),
        ))
      }
    })
    ->ignore

  let handlePayoutMethodDataSave = (selectedPaymentMethod, selectedPaymentMethodType) =>
    formPaymentMethodData(selectedPaymentMethodType, paymentMethodData, fieldValidityDict)
    ->Option.map(pmd => {
      switch currentView {
      | Journey(_) =>
        setCurrentView(_ => Journey(
          FinalizeView(selectedPaymentMethod, selectedPaymentMethodType, pmd),
        ))
      | Tabs(_) => ()
      }
    })
    ->ignore

  let renderAddressForm = (addressFields: array<requiredFieldsForAddress>) =>
    addressFields
    ->Array.map(addressRequiredField => {
      switch addressRequiredField.fieldType {
      | Email => BillingAddress(Email)->renderInputTemplate
      | FullName(FirstName) => BillingAddress(FullName(FirstName))->renderInputTemplate
      // first_name and last_name are stored in fullName
      | FullName(LastName) => React.null
      | CountryCode => BillingAddress(CountryCode)->renderInputTemplate
      | PhoneNumber => BillingAddress(PhoneNumber)->renderInputTemplate
      | PhoneCountryCode => BillingAddress(PhoneCountryCode)->renderInputTemplate
      | AddressLine1 => BillingAddress(AddressLine1)->renderInputTemplate
      | AddressLine2 => BillingAddress(AddressLine2)->renderInputTemplate
      | AddressCity => BillingAddress(AddressCity)->renderInputTemplate
      | AddressState => BillingAddress(AddressState)->renderInputTemplate
      | AddressPincode => BillingAddress(AddressPincode)->renderInputTemplate
      | AddressCountry => BillingAddress(AddressCountry)->renderInputTemplate
      }
    })
    ->React.array

  let renderPayoutMethodForm = (payoutMethodFields: array<requiredFieldsForPaymentMethodData>) =>
    payoutMethodFields
    ->Array.map(payoutMethodField => {
      switch payoutMethodField.fieldType {
      // Card
      | CardNumber => PayoutMethodData(CardNumber)->renderInputTemplate
      | CardExpDate(CardExpMonth) =>
        PayoutMethodData(CardExpDate(CardExpMonth))->renderInputTemplate
      // expiry_month and expiry_year are store in cardExp
      | CardExpDate(CardExpYear) => React.null
      | CardHolderName => PayoutMethodData(CardHolderName)->renderInputTemplate
      // ACH
      | ACHRoutingNumber => PayoutMethodData(ACHRoutingNumber)->renderInputTemplate
      | ACHAccountNumber => PayoutMethodData(ACHAccountNumber)->renderInputTemplate
      // Bacs
      | BacsSortCode => PayoutMethodData(BacsSortCode)->renderInputTemplate
      | BacsAccountNumber => PayoutMethodData(BacsAccountNumber)->renderInputTemplate
      // Sepa
      | SepaIban => PayoutMethodData(SepaIban)->renderInputTemplate
      | SepaBic => PayoutMethodData(SepaBic)->renderInputTemplate
      // Paypal
      | PaypalMail => PayoutMethodData(PaypalMail)->renderInputTemplate
      | PaypalMobNumber => PayoutMethodData(PaypalMobNumber)->renderInputTemplate
      // Venmo
      | VenmoMobNumber => PayoutMethodData(VenmoMobNumber)->renderInputTemplate
      // Pix
      | PixId => PayoutMethodData(PixId)->renderInputTemplate

      // TODO: Add these later
      | CardBrand
      | ACHBankName
      | ACHBankCity
      | BacsBankName
      | BacsBankCity
      | SepaBankName
      | SepaBankCity
      | SepaCountryCode
      | PixBankAccountNumber
      | PixBankName => React.null
      }
    })
    ->React.array

  let renderPMOptions = () =>
    <div className="flex flex-col mt-2.5">
      {availablePaymentMethods
      ->Array.mapWithIndex((pm, i) => {
        <button
          key={Int.toString(i)}
          onClick={_ => {
            setSelectedPaymentMethod(_ => Some(pm))

            // Update screen and payment method type, for cards
            switch pm {
            | Card => {
                let selectedPaymentMethodType = availablePaymentMethodTypes->Array.find(pmt => {
                  switch pmt {
                  | Card((_, _)) => true
                  | _ => false
                  }
                })

                selectedPaymentMethodType
                ->Option.map(selectedPaymentMethodType => {
                  switch selectedPaymentMethodType {
                  | Card(info) => updateScreenForRenderingForm(Card, Card(info))
                  | _ => setCurrentView(_ => Journey(SelectPMType(pm)))
                  }
                })
                ->ignore

                setSelectedPaymentMethodType(_ => selectedPaymentMethodType)
              }
            | _ => {
                setCurrentView(_ => Journey(SelectPMType(pm)))
                setSelectedPaymentMethodType(_ => None)
              }
            }
          }}
          className="flex flex-row items-center border border-solid border-jp-gray-200 px-5 py-2.5 rounded mt-2.5 hover:bg-jp-gray-50">
          {pm->getPaymentMethodIcon}
          <label className="text-start ml-2.5 cursor-pointer">
            {React.string(pm->String.make)}
          </label>
        </button>
      })
      ->React.array}
    </div>

  let renderPMTOptions = (selectedPaymentMethod: paymentMethod) => {
    let commonClasses = "flex flex-row items-center border border-solid border-jp-gray-200 px-5 py-2.5 rounded mt-2.5 hover:bg-jp-gray-50"
    let buttonTextClasses = "text-start ml-2.5 cursor-pointer"
    <div className="flex flex-col">
      {switch selectedPaymentMethod {
      | Card => React.null
      | BankTransfer =>
        availablePaymentMethodTypes
        ->Array.filterMap(pmt =>
          switch pmt {
          | BankTransfer(bank) => Some(bank)
          | _ => None
          }
        )
        ->Array.mapWithIndex(((pmt, requiredFields), i) =>
          <button
            key={Int.toString(i)}
            onClick={_ => {
              updateScreenForRenderingForm(BankTransfer, BankTransfer((pmt, requiredFields)))
              setSelectedPaymentMethodType(_ => Some(BankTransfer((pmt, requiredFields))))
            }}
            className=commonClasses>
            {pmt->getBankTransferIcon}
            <label className={buttonTextClasses}> {React.string(pmt->String.make)} </label>
          </button>
        )
        ->React.array
      | Wallet =>
        availablePaymentMethodTypes
        ->Array.filterMap(pmt =>
          switch pmt {
          | Wallet(wallet) => Some(wallet)
          | _ => None
          }
        )
        ->Array.mapWithIndex(((pmt, requiredFields), i) =>
          <button
            key={Int.toString(i)}
            onClick={_ => {
              setSelectedPaymentMethodType(_ => Some(Wallet((pmt, requiredFields))))
            }}
            className=commonClasses>
            {pmt->getWalletIcon}
            <label className={buttonTextClasses}> {React.string(pmt->String.make)} </label>
          </button>
        )
        ->React.array
      }}
    </div>
  }

  let renderJourneyScreen = journeyView => {
    let backButtonClasses = "flex justify-center items-center"
    let contentHeaderClasses = "text-xl lg:text-3xl font-semibold"
    let contentSubHeaderClasses = "text-base text-gray-500"
    let headerWrapperClasses = "flex flex-row justify-start"
    <div className="w-full">
      {switch journeyView {
      | SelectPM =>
        <React.Fragment>
          <div className={contentHeaderClasses}>
            {React.string(localeString.formHeaderSelectAccountText)}
          </div>
          <div className={contentSubHeaderClasses}>
            {React.string(localeString.formFundsInfoText)}
          </div>
          <div className="mt-2.5"> {renderPMOptions()} </div>
        </React.Fragment>
      | SelectPMType(selectedPaymentMethod) =>
        switch selectedPaymentMethod {
        | Card => {
            setCurrentView(_ => Journey(SelectPM))
            React.null
          }
        | BankTransfer | Wallet =>
          <React.Fragment>
            <div className={headerWrapperClasses}>
              <div className={backButtonClasses}>
                <button
                  className="bg-jp-gray-600 rounded-full h-7 w-7 self-center mr-5"
                  onClick={_ => setCurrentView(_ => Journey(SelectPM))}>
                  {React.string("←")}
                </button>
              </div>
              <div className={contentHeaderClasses}>
                {React.string(localeString.formHeaderSelectBankText)}
              </div>
            </div>
            <div className="mt-2.5"> {renderPMTOptions(selectedPaymentMethod)} </div>
          </React.Fragment>
        }

      | AddressForm(selectedPaymentMethod, selectedPaymentMethodType, addressFields) =>
        <React.Fragment>
          <div className={headerWrapperClasses}>
            <div className={backButtonClasses}>
              <div className={backButtonClasses}>
                <button
                  className="bg-jp-gray-600 rounded-full h-7 w-7 self-center mr-5"
                  onClick={_ =>
                    setCurrentView(_ =>
                      switch selectedPaymentMethod {
                      | Card => Journey(SelectPM)
                      | pmt => Journey(SelectPMType(pmt))
                      }
                    )}>
                  {React.string("←")}
                </button>
              </div>
            </div>
            <div className={contentHeaderClasses}>
              {React.string(localeString.billingDetailsText)}
            </div>
          </div>
          <div className={contentSubHeaderClasses}>
            {React.string(localeString.formSubheaderBillingDetailsText)}
          </div>
          <div className="mt-2.5">
            {renderAddressForm(addressFields)}
            <button
              className="min-w-full mt-10 text-lg font-semibold px-2.5 py-1.5 text-white rounded"
              style={backgroundColor: primaryTheme}
              onClick={_ => handleAddressSave(selectedPaymentMethod, selectedPaymentMethodType)}>
              {React.string(localeString.formSaveText)}
            </button>
          </div>
        </React.Fragment>
      | PMDForm(selectedPaymentMethod, selectedPaymentMethodType, payoutMethodFields) =>
        <React.Fragment>
          <div className={headerWrapperClasses}>
            <div className={backButtonClasses}>
              <div className={backButtonClasses}>
                <button
                  className="bg-jp-gray-600 rounded-full h-7 w-7 self-center mr-5"
                  onClick={_ =>
                    setCurrentView(_ =>
                      switch selectedPaymentMethodType {
                      | Card((_, requiredFields)) =>
                        switch requiredFields.address {
                        | Some(address) =>
                          Journey(
                            AddressForm(selectedPaymentMethod, selectedPaymentMethodType, address),
                          )
                        | None => Journey(SelectPM)
                        }
                      | BankTransfer((_, requiredFields))
                      | Wallet((_, requiredFields)) =>
                        switch requiredFields.address {
                        | Some(address) =>
                          Journey(
                            AddressForm(selectedPaymentMethod, selectedPaymentMethodType, address),
                          )
                        | None => Journey(SelectPMType(selectedPaymentMethod))
                        }
                      }
                    )}>
                  {React.string("←")}
                </button>
              </div>
            </div>
            <div className={contentHeaderClasses}>
              {switch selectedPaymentMethod {
              | Card => localeString.formHeaderEnterCardText
              | BankTransfer =>
                selectedPaymentMethodType
                ->getPaymentMethodTypeLabel
                ->localeString.formHeaderBankText
              | Wallet =>
                selectedPaymentMethodType
                ->getPaymentMethodTypeLabel
                ->localeString.formHeaderWalletText
              }->React.string}
            </div>
          </div>
          <div className="mt-2.5">
            {renderPayoutMethodForm(payoutMethodFields)}
            <button
              className="min-w-full mt-10 text-lg font-semibold px-2.5 py-1.5 text-white rounded"
              style={backgroundColor: primaryTheme}
              onClick={_ =>
                handlePayoutMethodDataSave(selectedPaymentMethod, selectedPaymentMethodType)}>
              {React.string(localeString.formSaveText)}
            </button>
          </div>
        </React.Fragment>
      | FinalizeView(selectedPaymentMethod, selectedPaymentMethodType, finalizedFields) =>
        <div className="mt-2.5">
          {renderFinalizeScreen(selectedPaymentMethod, selectedPaymentMethodType, finalizedFields)}
        </div>
      }}
    </div>
  }

  let handleTabSelection = selectedPMT => {
    availablePaymentMethodTypesOrdered
    ->Array.find(pmt => pmt->getPaymentMethodTypeLabel === selectedPMT)
    ->Option.map(selectedPaymentMethodType => {
      if (
        availablePaymentMethodTypesOrdered->Array.indexOf(selectedPaymentMethodType) >=
          defaultOptionsLimitInTabLayout
      ) {
        // Move the selected payment method at the last tab position
        let ordList = availablePaymentMethodTypes->Array.reduceWithIndex([], (acc, pmt, i) => {
          if i === defaultOptionsLimitInTabLayout - 1 {
            acc->Array.push(selectedPaymentMethodType)
          }
          if pmt !== selectedPaymentMethodType {
            acc->Array.push(pmt)
          }
          acc
        })
        setAvailablePaymentMethodTypesOrdered(_ => ordList)
      }
      setSelectedPaymentMethodType(_ => Some(selectedPaymentMethodType))
      switch selectedPaymentMethodType {
      | Card(info) => setCurrentView(_ => Tabs(DetailsForm(Card, Card(info))))
      | BankTransfer(info) =>
        setCurrentView(_ => Tabs(DetailsForm(BankTransfer, BankTransfer(info))))
      | Wallet(info) => setCurrentView(_ => Tabs(DetailsForm(Wallet, Wallet(info))))
      }
    })
    ->ignore
  }

  let renderTabScreen = (tabView, ~limit=defaultOptionsLimitInTabLayout) => {
    let contentHeaderClasses = "text-xl lg:text-2xl font-semibold mt-5"
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
      {switch tabView {
      | DetailsForm(selectedPaymentMethod, selectedPaymentMethodType) => {
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
                  className="text-black bg-white hover:bg-gray-100">
                  {React.string(pmt->getPaymentMethodTypeLabel)}
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
                  onClick={_ => handleTabSelection(pmt->getPaymentMethodTypeLabel)}
                  className="flex w-full items-center rounded border-0 px-2.5 py-1.5 mr-2.5 cursor-pointer hover:bg-jp-gray-50"
                  style={selectedPaymentMethodType->getPaymentMethodTypeLabel ===
                    pmt->getPaymentMethodTypeLabel
                    ? activeStyles
                    : defaultStyles}>
                  {pmt->getPaymentMethodTypeIcon}
                  <div className="ml-2.5"> {React.string(pmt->getPaymentMethodTypeLabel)} </div>
                </div>,
              )
            }
            items
          })
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
                    value={getPaymentMethodTypeLabel(selectedPaymentMethodType)}
                    onChange={ev => handleTabSelection(ReactEvent.Form.target(ev)["value"])}
                    className="h-full relative rounded border border-solid border-jp-gray-700 py-1.5 cursor-pointer bg-white text-transparent w-8 hover:bg-jp-gray-50">
                    {<option
                      key={selectedPaymentMethodType->getPaymentMethodTypeLabel}
                      value={selectedPaymentMethodType->getPaymentMethodTypeLabel}
                      disabled={true}>
                      {React.string(selectedPaymentMethodType->getPaymentMethodTypeLabel)}
                    </option>}
                    {hiddenTabs->React.array}
                  </select>
                </div>
              </RenderIf>}
            </div>
            <div className={contentHeaderClasses}>
              {switch selectedPaymentMethod {
              | Card => localeString.formHeaderEnterCardText
              | BankTransfer =>
                selectedPaymentMethodType
                ->getPaymentMethodTypeLabel
                ->localeString.formHeaderBankText
              | Wallet =>
                selectedPaymentMethodType
                ->getPaymentMethodTypeLabel
                ->localeString.formHeaderWalletText
              }->React.string}
            </div>
            {switch selectedPaymentMethodType {
            | Card((_, requiredFields))
            | BankTransfer((_, requiredFields))
            | Wallet((_, requiredFields)) =>
              <React.Fragment>
                {requiredFields.payoutMethodData
                ->Option.map(payoutMethodDataFields =>
                  renderPayoutMethodForm(payoutMethodDataFields)
                )
                ->Option.getOr(React.null)}
                {requiredFields.address
                ->Option.map(addressFields => {
                  <React.Fragment>
                    <div className={contentHeaderClasses}>
                      {React.string(localeString.billingDetailsText)}
                    </div>
                    {renderAddressForm(addressFields)}
                  </React.Fragment>
                })
                ->Option.getOr(React.null)}
              </React.Fragment>
            }}
            <button
              className="min-w-full mt-10 text-lg font-semibold px-2.5 py-1.5 text-white rounded"
              style={backgroundColor: primaryTheme}
              onClick={_ => {
                handleAddressSave(selectedPaymentMethod, selectedPaymentMethodType)
                handlePayoutMethodDataSave(selectedPaymentMethod, selectedPaymentMethodType)
              }}>
              {React.string(localeString.formSaveText)}
            </button>
          </div>
        }
      | FinalizeView(selectedPaymentMethod, selectedPaymentMethodType, paymentMethodData) =>
        renderFinalizeScreen(selectedPaymentMethod, selectedPaymentMethodType, paymentMethodData)
      }}
    </div>
  }

  <div
    className="flex flex-col h-min p-6 items-center lg:rounded lg:shadow-lg lg:p-10 lg:min-w-[400px]">
    {switch currentView {
    | Journey(journeyView) => renderJourneyScreen(journeyView)
    | Tabs(tabsView) => renderTabScreen(tabsView)
    }}
  </div>
}
let default = make
