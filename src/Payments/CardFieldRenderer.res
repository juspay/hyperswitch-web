open SuperpositionHelper

@react.component
let make = (
  ~field: fieldConfig,
  ~fieldIndex: string,
  ~cardBrand: string,
  ~setCardBrand: (string => string) => unit,
  ~isCardValid: option<bool>,
  ~setIsCardValid: (option<bool> => option<bool>) => unit,
  ~isExpiryValid: option<bool>,
  ~setIsExpiryValid: (option<bool> => option<bool>) => unit,
  ~isCVCValid: option<bool>,
  ~setIsCVCValid: (option<bool> => option<bool>) => unit,
  ~currentCVC: string,
  ~setCurrentCVC: (string => string) => unit,
) => {
  let {localeString} = Recoil.useRecoilValueFromAtom(RecoilAtoms.configAtom)
  let dummyRef = React.useRef(Nullable.null)

  let handleCardNumberChange = (originalOnChange, ev) => {
    let val = ReactEvent.Form.target(ev)["value"]
    let currentCardType = cardBrand->CardUtils.getCardType

    let formattedCard = val->CardUtils.formatCardNumber(currentCardType)
    let detectedBrand = formattedCard->CardUtils.getCardBrand

    setCardBrand(_ => detectedBrand)
    let clearValue = formattedCard->CardValidations.clearSpaces
    CardUtils.setCardValid(clearValue, detectedBrand, setIsCardValid)

    originalOnChange({
      "card_number": formattedCard,
      "card_brand": detectedBrand,
    })
  }

  let getDynamicCardIcon = () => {
    let cardType = cardBrand->CardUtils.getCardType
    CardUtils.getCardBrandIcon(cardType, CardThemeType.Payment)
  }

  let getDynamicMaxLength = () => {
    CardUtils.getMaxLength(cardBrand)
  }

  let handleExpiryChange = (originalOnChange, ev) => {
    let val = ReactEvent.Form.target(ev)["value"]
    let formattedExpiry = val->CardValidations.formatCardExpiryNumber
    CardUtils.setExpiryValid(formattedExpiry, setIsExpiryValid)

    originalOnChange(formattedExpiry)
  }

  let handleCVCChange = (originalOnChange, ev) => {
    let val = ReactEvent.Form.target(ev)["value"]

    let formattedCVC = val->CardValidations.formatCVCNumber(cardBrand)

    setCurrentCVC(_ => formattedCVC)

    if (
      formattedCVC->String.length > 0 &&
        CardUtils.cvcNumberInRange(formattedCVC, cardBrand)->Array.includes(true)
    ) {
      setIsCVCValid(_ => Some(true))
    } else {
      setIsCVCValid(_ => None)
    }

    originalOnChange(formattedCVC)
  }

  let getDynamicCVCIcon = () => {
    let isCvcValidValue = CardUtils.getBoolOptionVal(isCVCValid)
    let (cardEmpty, cardComplete, cardInvalid) = CardUtils.useCardDetails(
      ~cvcNumber=currentCVC,
      ~isCvcValidValue,
      ~isCVCValid,
    )
    CardUtils.setRightIconForCvc(~cardEmpty, ~cardInvalid, ~color="#ff0000", ~cardComplete)
  }

  let name = getFieldNameFromOutputPath(field.outputPath)
  let parentPath = field.name->getParentPathFromOutputPath

  switch name {
  | "card_number" =>
    <ReactFinalForm.Field name=field.name key={fieldIndex}>
      {({input, meta}) => {
        let typedInput = ReactFinalForm.toTypedField(input)
        <PaymentInputField
          fieldName=localeString.cardNumberLabel
          isValid=isCardValid
          setIsValid=setIsCardValid
          value={input.value
          ->Utils.getDictFromJson
          ->Utils.getString("card_number", "")}
          onChange={ev => handleCardNumberChange(typedInput.onChange, ev)}
          onBlur=input.onBlur
          rightIcon={getDynamicCardIcon()}
          errorString={meta.error
          ->Nullable.toOption
          ->Option.getOr("")}
          type_="tel"
          maxLength={getDynamicMaxLength()}
          inputRef=dummyRef
          placeholder="1234 1234 1234 1234"
          autocomplete="cc-number"
        />
      }}
    </ReactFinalForm.Field>
  | "card_number_network_merged" =>
    <ReactFinalForm.Field name={parentPath} key={fieldIndex}>
      {({input, meta}) => {
        let typedInput = ReactFinalForm.toTypedField(input)
        <PaymentInputField
          fieldName=localeString.cardNumberLabel
          isValid=isCardValid
          setIsValid=setIsCardValid
          value={input.value
          ->Utils.getDictFromJson
          ->Utils.getString("card_number", "")}
          onChange={ev => handleCardNumberChange(typedInput.onChange, ev)}
          onBlur=input.onBlur
          rightIcon={getDynamicCardIcon()}
          errorString={meta.error
          ->Nullable.toOption
          ->Option.getOr("")}
          type_="tel"
          maxLength={getDynamicMaxLength()}
          inputRef=dummyRef
          placeholder="1234 1234 1234 1234"
          autocomplete="cc-number"
        />
      }}
    </ReactFinalForm.Field>
  | "card_exp_month" =>
    <ReactFinalForm.Field name=field.name key={fieldIndex}>
      {({input, meta}) => {
        let typedInput = ReactFinalForm.toTypedField(input)
        <PaymentInputField
          fieldName=localeString.validThruText
          isValid=isExpiryValid
          setIsValid=setIsExpiryValid
          value={input.value->JSON.Decode.string->Option.getOr("")}
          onChange={ev => handleExpiryChange(typedInput.onChange, ev)}
          onBlur=input.onBlur
          errorString={meta.error
          ->Nullable.toOption
          ->Option.getOr("")}
          type_="tel"
          maxLength=7
          inputRef=dummyRef
          placeholder=localeString.expiryPlaceholder
          autocomplete="cc-exp"
        />
      }}
    </ReactFinalForm.Field>
  | "card_expiry_cvc_merged" =>
    <div className="flex gap-4 w-full">
      <ReactFinalForm.Field
        name={parentPath != "" ? parentPath ++ "." ++ "card_expiry" : "card_expiry"}
        key={fieldIndex}>
        {({input, meta}) => {
          let typedInput = ReactFinalForm.toTypedField(input)
          <PaymentInputField
            fieldName=localeString.validThruText
            isValid=isExpiryValid
            setIsValid=setIsExpiryValid
            value={input.value->JSON.Decode.string->Option.getOr("")}
            onChange={ev => handleExpiryChange(typedInput.onChange, ev)}
            onBlur=input.onBlur
            errorString={meta.error
            ->Nullable.toOption
            ->Option.getOr("")}
            type_="tel"
            maxLength=7
            inputRef=dummyRef
            placeholder=localeString.expiryPlaceholder
            autocomplete="cc-exp"
          />
        }}
      </ReactFinalForm.Field>
      <ReactFinalForm.Field
        name={parentPath != "" ? parentPath ++ "." ++ "card_cvc" : "card_cvc"}
        key={fieldIndex ++ "_cvc"}>
        {({input, meta}) => {
          let typedInput = ReactFinalForm.toTypedField(input)
          <PaymentInputField
            fieldName=localeString.cvcTextLabel
            isValid=isCVCValid
            setIsValid=setIsCVCValid
            value={input.value->JSON.Decode.string->Option.getOr("")}
            onChange={ev => handleCVCChange(typedInput.onChange, ev)}
            onBlur=input.onBlur
            rightIcon={getDynamicCVCIcon()}
            errorString={meta.error
            ->Nullable.toOption
            ->Option.getOr("")}
            type_="tel"
            className="tracking-widest w-full"
            maxLength=4
            inputRef=dummyRef
            placeholder="123"
            autocomplete="cc-csc"
          />
        }}
      </ReactFinalForm.Field>
    </div>
  | "card_cvc" =>
    <ReactFinalForm.Field name=field.name key={fieldIndex}>
      {({input, meta}) => {
        let typedInput = ReactFinalForm.toTypedField(input)
        <PaymentInputField
          fieldName=localeString.cvcTextLabel
          isValid=isCVCValid
          setIsValid=setIsCVCValid
          value={input.value->JSON.Decode.string->Option.getOr("")}
          onChange={ev => handleCVCChange(typedInput.onChange, ev)}
          onBlur=input.onBlur
          rightIcon={getDynamicCVCIcon()}
          errorString={meta.error
          ->Nullable.toOption
          ->Option.getOr("")}
          type_="tel"
          className="tracking-widest w-full"
          maxLength=4
          inputRef=dummyRef
          placeholder="123"
          autocomplete="cc-csc"
        />
      }}
    </ReactFinalForm.Field>
  | _ => React.null
  }
}
