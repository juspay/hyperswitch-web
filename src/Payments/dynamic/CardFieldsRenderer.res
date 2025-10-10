open SuperpositionTypes
open Validation
module CardFields = {
  @react.component
  let make = (
    ~cardNumberConfig,
    ~expMonthConfig,
    ~expYearConfig,
    ~cvcConfig,
    ~cardNetworkConfig,
  ) => {
    let {localeString, themeObj} = Recoil.useRecoilValueFromAtom(RecoilAtoms.configAtom)
    let (cardExp, setCardExp) = React.useState(_ => "")
    let (cardNumber, setCardNumber) = React.useState(_ => "")

    let cardNumberRef = React.useRef(Nullable.null)
    let expiryRef = React.useRef(Nullable.null)
    let cvcRef = React.useRef(Nullable.null)

    let {input: cardNumberInput} = ReactFinalForm.useField(
      cardNumberConfig.name,
      ~config={
        initialValue: Some(""),
      },
    )
    let {input: expMonthInput} = ReactFinalForm.useField(
      expMonthConfig.name,
      ~config={
        initialValue: Some(""),
      },
    )
    let {input: expYearInput} = ReactFinalForm.useField(
      expYearConfig.name,
      ~config={
        initialValue: Some(""),
      },
    )
    let {input: cvcInput} = ReactFinalForm.useField(
      cvcConfig.name,
      ~config={
        initialValue: Some(""),
      },
    )
    let {input: cardNetworkInput} = ReactFinalForm.useField(
      cardNetworkConfig.name,
      ~config={
        initialValue: Some(""),
      },
    )

    let getCardNetworkValue = () => cardNetworkInput.value->Option.getOr("")
    let getCvcValue = () => cvcInput.value->Option.getOr("")

    let handleCardNumberChange = ev => {
      let val: string = ReactEvent.Form.target(ev)["value"]
      let detectedBrand = val->String.trim->CardUtils.getCardBrand
      let cardType = detectedBrand->CardUtils.getCardType
      let formattedCard = val->CardUtils.formatCardNumber(cardType)
      setCardNumber(_ => formattedCard)
      let clearCardNumber = formattedCard->String.replaceAll(" ", "")->String.trim
      if clearCardNumber == "" {
        setCardExp(_ => "")
        expMonthInput.onChange("")
        expYearInput.onChange("")
        cvcInput.onChange("")
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
      let formattedCVC = val->CardValidations.formatCVCNumber(getCardNetworkValue())
      cvcInput.onChange(formattedCVC)
    }

    let getCvcDynamicIcon = () => {
      let cvcValue = getCvcValue()
      let cardNetworkValue = getCardNetworkValue()

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

    let getCardNumberIcon = cardBrand => {
      let cardType = cardBrand->CardUtils.getCardType
      CardUtils.getCardBrandIcon(cardType, CardThemeType.Payment)
    }

    let getCardMaxLength = cardBrand => CardUtils.getMaxLength(cardBrand)
    let cardNetworkValue = getCardNetworkValue()

    <>
      <PaymentInputField
        fieldName=localeString.cardNumberLabel
        isValid={Some(true)}
        setIsValid={_ => ()}
        value={cardNumber}
        onChange={handleCardNumberChange}
        onBlur={cardNumberInput.onBlur}
        rightIcon={getCardNumberIcon(cardNetworkValue)}
        errorString=""
        type_="tel"
        maxLength={getCardMaxLength(cardNetworkValue)}
        inputRef=cardNumberRef
        placeholder="1234 1234 1234 1234"
        autocomplete="cc-number"
      />
      <div className="flex gap-10">
        <PaymentInputField
          fieldName=localeString.validThruText
          isValid=Some(true)
          setIsValid={_ => ()}
          value=cardExp
          onChange={handleExpiryChange}
          onBlur={_ => ()}
          errorString=""
          type_="tel"
          maxLength=7
          inputRef=expiryRef
          placeholder=localeString.expiryPlaceholder
          autocomplete="cc-exp"
        />
        <PaymentInputField
          fieldName=localeString.cvcTextLabel
          isValid={Some(true)}
          setIsValid={_ => ()}
          value={getCvcValue()}
          onChange={handleCvcChange}
          onBlur={cvcInput.onBlur}
          errorString=""
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
  if fields->Array.length == 5 {
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
