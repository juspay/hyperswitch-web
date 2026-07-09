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
  // Recoil states
  let {config, constantString, localeString} = Recoil.useRecoilValueFromAtom(configAtom)
  let {enabledPaymentMethodsWithDynamicFields} = Recoil.useRecoilValueFromAtom(
    paymentMethodCollectOptionAtom,
  )
  let (_, setPayoutDynamicFields) = Recoil.useRecoilState(payoutDynamicFieldsAtom)
  let (formData, setFormData) = Recoil.useRecoilState(formDataAtom)
  let (activePmt, _) = Recoil.useRecoilState(paymentMethodTypeAtom)
  let (validityDict, setValidityDict) = Recoil.useRecoilState(validityDictAtom)
  let paymentMethodListValue = Recoil.useRecoilValueFromAtom(PaymentUtils.paymentMethodListValue)
  let supportedCardBrands = React.useMemo(() => {
    paymentMethodListValue->PaymentUtils.getSupportedCardBrands
  }, [paymentMethodListValue])

  // Component states
  let (currentView, setCurrentView) = React.useState(_ => formLayout->defaultView)

  // Hook for updating current view based on formLayout
  React.useEffect(() => {
    setCurrentView(_ => formLayout->defaultView)
    None
  }, [formLayout])

  // Hook for fetching dynamic fields, and default values and their validity for payment method type update
  React.useEffect(() => {
    getPayoutDynamicFields(enabledPaymentMethodsWithDynamicFields, activePmt)
    ->Option.flatMap(payoutDynamicFields => {
      setPayoutDynamicFields(_ => payoutDynamicFields)
      getDefaultsAndValidity(payoutDynamicFields, supportedCardBrands)
    })
    ->Option.map(((values, validity)) => {
      handleNameFieldNormalization(values, validity)

      setFormData(_ => values)
      setValidityDict(_ => validity)
    })
    ->ignore
    None
  }, [activePmt])

  // Custom state update fns
  let setFormData = (key, value) => {
    setFormData(prevDict => {
      let copy = prevDict->Dict.copy
      copy->Dict.set(key, value)
      copy
    })
  }

  let setValidityDictVal = (key, value) => {
    setValidityDict(prevDict => {
      let copy = prevDict->Dict.copy
      copy->Dict.set(key, value)
      copy
    })
  }

  // Some React references for input fields
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

  // UI renderers
  let validateAndSetPaymentMethodDataValue = (key: dynamicFieldType, event) => {
    let value = ReactEvent.Form.target(event)["value"]
    let inputType = ReactEvent.Form.target(event)["type"]

    let (isValid, updatedValue) = switch (key, inputType, value) {
    // Empty string is valid (no error)
    | (_, _, "") => (true, "")
    | (PayoutMethodData(CardExpDate(_)), "number" | "tel", _) => {
        let formattedExpiry = CardValidations.formatCardExpiryNumber(value)
        let isCardExpiryValid = isExipryValid(formattedExpiry)
        if isCardExpiryValid {
          handleInputFocus(~currentRef=cardExpRef, ~destinationRef=cardHolderRef)
        }
        if formattedExpiry->String.length == getPaymentMethodDataFieldMaxLength(key) {
          setValidityDictVal("card.cardExp", Some(isCardExpiryValid))
        } else {
          setValidityDictVal("card.cardExp", Some(true))
        }
        (true, formattedExpiry)
      }
    | (PayoutMethodData(CardNumber), "number" | "tel", _) => {
        let cardType = getCardType(
          formData
          ->Dict.get(PayoutMethodData(CardBrand)->getPaymentMethodDataFieldKey)
          ->Option.getOr(""),
        )
        let formattedCardNumber = formatCardNumber(value, cardType)
        let clearCardNumber = CardValidations.clearSpaces(formattedCardNumber)
        let cardTypeStr = getCardStringFromType(cardType)
        if focusCardValid(clearCardNumber, cardTypeStr) {
          handleInputFocus(~currentRef=cardNumberRef, ~destinationRef=cardExpRef)
        }

        if maxCardLength(cardTypeStr) == clearCardNumber->String.length {
          setValidityDictVal(
            "card.cardNumber",
            calculateValidity(key, value, cardTypeStr, ~default=None),
          )
        } else {
          setValidityDictVal("card.cardNumber", Some(true))
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
      | PayoutMethodData(CardNumber) => {
          let validCardBrand = getFirstValidCardSchemeFromPML(
            ~cardNumber=updatedValue,
            ~enabledCardSchemes=supportedCardBrands->Option.getOr([]),
          )
          let newCardBrand = switch validCardBrand {
          | Some(brand) => brand
          | None => updatedValue->CardUtils.getCardBrand
          }
          setFormData(PayoutMethodData(CardBrand)->getPaymentMethodDataFieldKey, newCardBrand)
        }
      | BillingAddress(FullName(FirstName)) => {
          let firstNameKey = BillingAddress(FullName(FirstName))->getPaymentMethodDataFieldKey
          let lastNameKey = BillingAddress(FullName(LastName))->getPaymentMethodDataFieldKey
          let nameSplits = value->String.trim->String.split(" ")

          // Only update name if there's actual input (nameSplits length > 0)
          if nameSplits->Array.length > 0 {
            let firstName = nameSplits->Array.get(0)->Option.getOr("")
            let lastName =
              nameSplits
              ->Array.slice(~start=1, ~end=nameSplits->Array.length)
              ->Array.join(" ")
            setFormData(firstNameKey, firstName)
            setFormData(lastNameKey, lastName)
          }
        }
      | _ => ()
      }
      setFormData(key->getPaymentMethodDataFieldKey, updatedValue)
    }
  }

  let renderDropdownTemplate = (field: dynamicFieldType) => {
    switch field {
    | BillingAddress(AddressCountry(countries)) => {
        let key = field->getPaymentMethodDataFieldKey
        let value = formData->Dict.get(key)->Option.getOr("")
        if countries->Array.length > 0 {
          <div key>
            <DropdownField
              appearance=config.appearance
              fieldName={field->getPaymentMethodDataFieldLabel(localeString)}
              value
              setValue={getVal => {
                let updatedValue = getVal()
                let validCardBrand = getFirstValidCardSchemeFromPML(
                  ~cardNumber=updatedValue,
                  ~enabledCardSchemes=supportedCardBrands->Option.getOr([]),
                )
                let newCardBrand = switch validCardBrand {
                | Some(brand) => brand
                | None => updatedValue->CardUtils.getCardBrand
                }

                let isValid = calculateValidity(
                  field,
                  updatedValue,
                  newCardBrand,
                  ~default=Some(false),
                )
                setValidityDictVal(key, isValid)
                if isValid->Option.getOr(false) {
                  setFormData(key, updatedValue)
                }
              }}
              options={countries->DropdownField.updateArrayOfStringToOptionsTypeArray}
              disabled=false
            />
          </div>
        } else {
          React.null
        }
      }
    | _ => React.null
    }
  }

  let renderInputTemplate = (field: dynamicFieldType) => {
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
    let key = field->getPaymentMethodDataFieldKey
    let value = formData->Dict.get(key)->Option.getOr("")
    let (errorString, errorStringClasses) = getErrorStringAndClasses(
      field,
      formData,
      validityDict,
      localeString,
    )
    <InputField
      id=key
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
      setIsValid={updatedValidityFn => key->setValidityDictVal(updatedValidityFn())}
      onBlur={ev => {
        let value = ReactEvent.Focus.target(ev)["value"]
        let validCardBrand = getFirstValidCardSchemeFromPML(
          ~cardNumber=value,
          ~enabledCardSchemes=supportedCardBrands->Option.getOr([]),
        )
        let newCardBrand = switch validCardBrand {
        | Some(brand) => brand
        | None => value->CardUtils.getCardBrand
        }

        let isValid = calculateValidity(field, value, newCardBrand, ~default=None)
        setValidityDictVal(key, isValid)
      }}
      type_={field->getPaymentMethodDataFieldInputType}
      pattern
    />
  }
  let checkIfNameRequired = (addressFields: array<dynamicFieldForAddress>) => {
    addressFields->Array.reduce(false, (acc, field) => {
      let condition = switch (field.fieldType, field.value) {
      | (FullName(LastName), None) => true
      | _ => false
      }
      acc || condition
    })
  }
  let renderAddressForm = (addressFields: array<dynamicFieldForAddress>) =>
    addressFields
    ->Array.mapWithIndex((field, index) =>
      <React.Fragment key={index->Int.toString}>
        {switch (field.fieldType, field.value) {
        | (Email, None) => BillingAddress(Email)->renderInputTemplate
        | (FullName(FirstName), None) => BillingAddress(FullName(FirstName))->renderInputTemplate
        | (FullName(FirstName), Some(_)) =>
          // If first_name exists, last_name is required and has null value, render first_name field to capture last_name
          <RenderIf condition={checkIfNameRequired(addressFields)}>
            {BillingAddress(FullName(FirstName))->renderInputTemplate}
          </RenderIf>
        // first_name and last_name are stored in fullName
        | (FullName(LastName), _) => React.null
        | (CountryCode, None) => BillingAddress(CountryCode)->renderInputTemplate
        | (PhoneNumber, None) => BillingAddress(PhoneNumber)->renderInputTemplate
        | (PhoneCountryCode, None) => BillingAddress(PhoneCountryCode)->renderInputTemplate
        | (AddressLine1, None) => BillingAddress(AddressLine1)->renderInputTemplate
        | (AddressLine2, None) => BillingAddress(AddressLine2)->renderInputTemplate
        | (AddressCity, None) => BillingAddress(AddressCity)->renderInputTemplate
        | (AddressState, None) => BillingAddress(AddressState)->renderInputTemplate
        | (AddressPincode, None) => BillingAddress(AddressPincode)->renderInputTemplate
        | (AddressCountry(countries), None) =>
          renderDropdownTemplate(BillingAddress(AddressCountry(countries)))
        | _ => React.null
        }}
      </React.Fragment>
    )
    ->Array.filter(ele => ele !== React.null)

  let renderPayoutMethodForm = (payoutMethodFields: array<dynamicFieldForPaymentMethodData>) =>
    payoutMethodFields
    ->Array.mapWithIndex((payoutMethodField, index) =>
      <React.Fragment key={index->Int.toString}>
        {switch (payoutMethodField.fieldType, payoutMethodField.value) {
        // Card
        | (CardNumber, _) => PayoutMethodData(CardNumber)->renderInputTemplate
        | (CardExpDate(CardExpMonth), _) =>
          PayoutMethodData(CardExpDate(CardExpMonth))->renderInputTemplate
        // expiry_month and expiry_year are store in cardExp
        | (CardExpDate(CardExpYear), _) => React.null
        | (CardHolderName, None) => PayoutMethodData(CardHolderName)->renderInputTemplate
        // ACH
        | (ACHRoutingNumber, _) => PayoutMethodData(ACHRoutingNumber)->renderInputTemplate
        | (ACHAccountNumber, _) => PayoutMethodData(ACHAccountNumber)->renderInputTemplate
        // Bacs
        | (BacsSortCode, _) => PayoutMethodData(BacsSortCode)->renderInputTemplate
        | (BacsAccountNumber, _) => PayoutMethodData(BacsAccountNumber)->renderInputTemplate
        // Sepa
        | (SepaIban, _) => PayoutMethodData(SepaIban)->renderInputTemplate
        | (SepaBic, _) => PayoutMethodData(SepaBic)->renderInputTemplate
        // Paypal
        | (PaypalMail, _) => PayoutMethodData(PaypalMail)->renderInputTemplate
        | (PaypalMobNumber, _) => PayoutMethodData(PaypalMobNumber)->renderInputTemplate
        // Venmo
        | (VenmoMobNumber, _) => PayoutMethodData(VenmoMobNumber)->renderInputTemplate
        // Pix
        | (PixKey, _) => PayoutMethodData(PixKey)->renderInputTemplate
        // Interac
        | (InteracEmail, _) => PayoutMethodData(InteracEmail)->renderInputTemplate

        // TODO: Add these later
        | (CardBrand, _)
        | (ACHBankName, _)
        | (ACHBankCity, _)
        | (BacsBankName, _)
        | (BacsBankCity, _)
        | (SepaBankName, _)
        | (SepaBankCity, _)
        | (SepaCountryCode, _)
        | (PixBankAccountNumber, _)
        | (PixBankName, _)
        | (CardHolderName, Some(_)) => React.null
        }}
      </React.Fragment>
    )
    ->Array.filter(ele => ele !== React.null)

  <div
    className="flex flex-col h-min p-6 items-center lg:rounded lg:shadow-lg lg:p-10 lg:min-w-[400px]">
    {switch currentView {
    // Render journey UI
    | Journey(journeyView) =>
      <FormViewJourney
        availablePaymentMethods
        availablePaymentMethodTypes
        primaryTheme
        handleSubmit
        enabledPaymentMethodsWithDynamicFields
        journeyView
        renderAddressForm
        renderPayoutMethodForm
      />
    // Render tabs UI
    | Tabs(tabsView) =>
      <FormViewTabs
        availablePaymentMethodTypes
        primaryTheme
        handleSubmit
        tabsView
        renderAddressForm
        renderPayoutMethodForm
      />
    }}
  </div>
}

let default = make
