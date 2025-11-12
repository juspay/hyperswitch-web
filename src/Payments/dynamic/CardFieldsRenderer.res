open SuperpositionTypes
module CardFields = {
  @react.component
  let make = (
    ~cardNumberConfig,
    ~expMonthConfig,
    ~expYearConfig,
    ~cvcConfig,
    ~cardNetworkConfig,
  ) => {
    //TODO: checkIsCardSupported

    let {localeString, themeObj} = Recoil.useRecoilValueFromAtom(RecoilAtoms.configAtom)
    let (cardExp, setCardExp) = React.useState(_ => "")
    let isCoBadgedCardDetectedOnce = React.useRef(false)
    let paymentMethodListValue = Recoil.useRecoilValueFromAtom(PaymentUtils.paymentMethodListValue)

    let enabledCardSchemes =
      paymentMethodListValue->PaymentUtils.getSupportedCardBrands->Option.getOr([])
    let createFieldValidator = rule =>
      Validation.createFieldValidator(
        rule,
        ~enabledCardSchemes,
        ~localeObject=LocaleDataType.defaultLocale,
      )

    let cardNumberRef = React.useRef(Nullable.null)
    let expiryRef = React.useRef(Nullable.null)
    let cvcRef = React.useRef(Nullable.null)

    let {input: cardNumberInput, meta: cardNumberMeta} = ReactFinalForm.useField(
      cardNumberConfig.outputPath,
      ~config={
        validate: createFieldValidator(CardNumber),
        format: (value, _name) => {
          value->Option.map(v => {
            let cleanValue = v->String.trim->String.replaceAll(" ", "")
            let detectedBrand = cleanValue->CardUtils.getCardBrand
            let cardType = detectedBrand->CardUtils.getCardType
            cleanValue->CardUtils.formatCardNumber(cardType)
          })
        },
      },
    )
    let {input: expMonthInput, meta: expMonthMeta} = ReactFinalForm.useField(
      expMonthConfig.outputPath,
      ~config={
        validate: val =>
          createFieldValidator(CardExpiry(Some(val)->Option.getOr("99") ++ "/90"))(Some(val)),
      },
    )
    let {input: expYearInput, meta: expYearMeta} = ReactFinalForm.useField(
      expYearConfig.outputPath,
      ~config={
        validate: val =>
          createFieldValidator(
            CardExpiry("01/" ++ Some(val)->Option.getOr("2011")->String.slice(~start=2, ~end=4)),
          )(Some(val)),
      },
    )

    let {input: cardNetworkInput, meta: cardNetworkMeta} = ReactFinalForm.useField(
      cardNetworkConfig.outputPath,
      ~config={},
    )
    let getCardNetworkValue = React.useMemo(
      () => cardNetworkInput.value->Option.getOr(""),
      [cardNetworkInput.value],
    )

    let {input: cvcInput, meta: cvcMeta} = ReactFinalForm.useField(
      cvcConfig.outputPath,
      ~config={
        validate: createFieldValidator(CardCVC(getCardNetworkValue)),
      },
    )

    let getCvcValue = () => cvcInput.value->Option.getOr("")

    let handleCardNumberChange = ev => {
      let val: string = ReactEvent.Form.target(ev)["value"]
      let clearCardNumber = val->String.trim->String.replaceAll(" ", "")
      let detectedBrand = clearCardNumber->CardUtils.getCardBrand

      if clearCardNumber == "" {
        setCardExp(_ => "")
        expMonthInput.onChange("")
        expYearInput.onChange("")
        cvcInput.onChange("")
        cardNetworkInput.onChange("")
      }

      cardNumberInput.onChange(clearCardNumber)
      cardNetworkInput.onChange(detectedBrand)

      if (
        CardUtils.focusCardValid(clearCardNumber, detectedBrand) &&
        clearCardNumber->String.length >= 13
      ) {
        expiryRef.current
        ->Nullable.toOption
        ->Option.forEach(input => input->CardUtils.focus)
        ->ignore
      }
    }

    let handleExpiryChange = ev => {
      let val = ReactEvent.Form.target(ev)["value"]
      let formattedExpiry = val->CardValidations.formatCardExpiryNumber
      let (month, year) = formattedExpiry->Validation.getExpiryDates
      setCardExp(_ => formattedExpiry)

      if formattedExpiry == "" {
        expMonthInput.onChange("")
        expYearInput.onChange("")
      } else {
        expMonthInput.onChange(month)
        expYearInput.onChange(year)

        if CardUtils.isExipryValid(formattedExpiry) {
          cvcRef.current->Nullable.toOption->Option.forEach(input => input->CardUtils.focus)->ignore
        }
      }
    }

    let handleCvcChange = ev => {
      let val = ReactEvent.Form.target(ev)["value"]
      let formattedCVC = val->CardValidations.formatCVCNumber(getCardNetworkValue)
      cvcInput.onChange(formattedCVC)
    }

    let getCvcDynamicIcon = () => {
      let cvcValue = getCvcValue()
      let cardNetworkValue = getCardNetworkValue

      let isValid =
        cvcValue->String.length > 0 &&
          CardUtils.cvcNumberInRange(cvcValue, cardNetworkValue)->Array.includes(true)

      let isCvcValidValue = CardUtils.getBoolOptionVal(Some(isValid))
      let (cardEmpty, cardComplete, cardInvalid) = CardUtils.useCardDetails(
        ~cvcNumber=cvcValue,
        ~isCvcValidValue,
        ~isCVCValid=isValid,
      )

      CardUtils.setRightIconForCvc(
        ~cardEmpty,
        ~cardInvalid,
        ~color=themeObj.colorIconCardCvcError,
        ~cardComplete,
      )
    }

    let getCardNumberIcon = () => {
      let cardNumber = cardNumberInput.value->Option.getOr("")
      let cardBrand = getCardNetworkValue
      <CardSchemeComponent
        cardNumber
        paymentType=CardThemeType.Payment
        cardBrand
        setCardBrand={fn => cardNetworkInput.onChange(fn())}
        isCoBadgedCardDetectedOnce
      />
    }

    let getCardMaxLength = cardBrand => CardUtils.getMaxLength(cardBrand)
    let cardNetworkValue = getCardNetworkValue

    let isFieldValid = (fieldMeta: ReactFinalForm.fieldState) =>
      fieldMeta.error->Option.isNone || !fieldMeta.touched || fieldMeta.active

    let isCardNumberValid = isFieldValid(cardNumberMeta)
    let isExpMonthValid = isFieldValid(expMonthMeta)
    let isExpYearValid = isFieldValid(expYearMeta)
    let isCvcValid = isFieldValid(cvcMeta)
    let isExipryValid = isExpMonthValid && isExpYearValid

    <>
      <PaymentInputField
        fieldName=localeString.cardNumberLabel
        isValid={Some(isCardNumberValid)}
        setIsValid={_ => ()}
        value={cardNumberInput.value->Option.getOr("")}
        onChange={handleCardNumberChange}
        onBlur={cardNumberInput.onBlur}
        onFocus={cardNumberInput.onFocus}
        rightIcon={getCardNumberIcon()}
        errorString={!isCardNumberValid ? cardNumberMeta.error->Option.getOr("") : ""}
        type_="tel"
        maxLength={getCardMaxLength(cardNetworkValue)}
        inputRef=cardNumberRef
        placeholder="1234 1234 1234 1234"
        autocomplete="cc-number"
      />
      <div className="flex gap-10">
        <PaymentInputField
          fieldName=localeString.validThruText
          isValid=Some(isExipryValid)
          setIsValid={_ => ()}
          value=cardExp
          onChange={handleExpiryChange}
          onBlur={_ => {
            expMonthInput.onBlur()
            expYearInput.onBlur()
          }}
          onFocus={_ => {
            expMonthInput.onFocus()
            expYearInput.onFocus()
          }}
          errorString={!isExipryValid
            ? expMonthMeta.error->Option.getOr(expYearMeta.error->Option.getOr(""))
            : ""}
          type_="tel"
          maxLength=7
          inputRef=expiryRef
          placeholder=localeString.expiryPlaceholder
          autocomplete="cc-exp"
        />
        <PaymentInputField
          fieldName=localeString.cvcTextLabel
          isValid={Some(isCvcValid)}
          setIsValid={_ => ()}
          value={getCvcValue()}
          onChange={handleCvcChange}
          onBlur={cvcInput.onBlur}
          onFocus={cvcInput.onFocus}
          errorString={!isCvcValid ? cvcMeta.error->Option.getOr("") : ""}
          rightIcon={getCvcDynamicIcon()}
          type_="tel"
          className="tracking-widest w-full"
          maxLength=4
          inputRef=cvcRef
          placeholder="123"
          autocomplete="cc-csc"
        />
      </div>
    </>
  }
}

@react.component
let make = (~fields: array<fieldConfig>) => {
  if fields->Array.length == 6 {
    switch fields {
    | [cardNumberConfig, expMonthConfig, expYearConfig, cvcConfig, cardNetworkConfig] =>
      <CardFields cardNumberConfig expMonthConfig expYearConfig cvcConfig cardNetworkConfig />
    | _ => React.null
    }
  } else {
    fields
    ->Array.map(field => {
      <DynamicInputFields key={field.outputPath} field />
    })
    ->React.array
  }
}
