open SuperpositionHelper
open SuperpositionTypes

type fieldProps = {
  field: fieldConfig,
  fieldIndex: string,
  localeString: LocaleStringTypes.localeStrings,
  dummyRef: React.ref<Nullable.t<Dom.element>>,
}

let getErrorString = (meta: ReactFinalForm.fieldRenderPropsMeta) =>
  meta.error->Nullable.toOption->Option.getOr("")

let getStringValue = (input: ReactFinalForm.fieldRenderPropsInput, key, default) =>
  input.value->Utils.getDictFromJson->Utils.getString(key, default)

let getDecodedStringValue = (input: ReactFinalForm.fieldRenderPropsInput) =>
  input.value->JSON.Decode.string->Option.getOr("")

let buildFieldName = (parentPath, fieldName) =>
  parentPath != "" ? parentPath ++ "." ++ fieldName : fieldName

let getCardBrandFromForm = (form: ReactFinalForm.formApi, fieldName) => {
  let formState = form.getState()
  let cardData =
    formState.values
    ->Utils.getDictFromJson
    ->Utils.getJsonObjectFromDict(fieldName)
  cardData->Utils.getDictFromJson->Utils.getString("card_brand", "")
}

let getCVCFromForm = (form: ReactFinalForm.formApi, fieldName) => {
  let formState = form.getState()
  formState.values->Utils.getDictFromJson->Utils.getString(fieldName, "")
}

let validateCardField = (value, _) => {
  switch value {
  | Some(val) =>
    let cardData = val->Identity.anyTypeToJson->Utils.getDictFromJson

    let cardNumber = cardData->Utils.getString("card_number", "")
    let cardBrand = cardData->Utils.getString("card_brand", "")
    Console.log2("Validating card number:", cardData)

    if cardNumber->String.length == 0 {
      Promise.resolve(Nullable.null)
    } else {
      let clearValue = cardNumber->CardValidations.clearSpaces
      let isValid = CardUtils.cardValid(clearValue, cardBrand)
      if isValid {
        Promise.resolve(Nullable.null)
      } else {
        Promise.resolve(Nullable.make("invalid card number"))
      }
    }
  | None => Promise.resolve(Nullable.null)
  }
}

let validateExpiryField = (value, _) => {
  switch value {
  | Some(val) =>
    if val->String.length == 0 {
      Promise.resolve(Nullable.null)
    } else {
      let isValid = CardUtils.isExipryValid(val)
      if isValid {
        Promise.resolve(Nullable.null)
      } else {
        Promise.resolve(Nullable.make("invalid expiry date"))
      }
    }
  | None => Promise.resolve(Nullable.null)
  }
}

let validateCVCField = (value, formValues, cardFieldName) => {
  switch value {
  | Some(val) =>
    if val->String.length == 0 {
      Promise.resolve(Nullable.null)
    } else {
      // Get card brand from form values
      let cardData = formValues->Utils.getDictFromJson->Utils.getJsonObjectFromDict(cardFieldName)
      let cardBrand = cardData->Utils.getDictFromJson->Utils.getString("card_brand", "")

      let isValid = if (
        val->String.length > 0 && CardUtils.cvcNumberInRange(val, cardBrand)->Array.includes(true)
      ) {
        true
      } else {
        false
      }
      if isValid {
        Promise.resolve(Nullable.null)
      } else {
        Promise.resolve(Nullable.make("invalid cvc"))
      }
    }
  | None => Promise.resolve(Nullable.null)
  }
}

module CardNumberField = {
  let handleChange = (originalOnChange, ev) => {
    let val = ReactEvent.Form.target(ev)["value"]
    let formattedCard = val->CardUtils.formatCardNumber(CardUtils.NOTFOUND)
    let detectedBrand = formattedCard->CardUtils.getCardBrand

    originalOnChange({
      "card_number": formattedCard,
      "card_brand": detectedBrand,
    })
  }

  let getDynamicIcon = cardBrand => {
    let cardType = cardBrand->CardUtils.getCardType
    CardUtils.getCardBrandIcon(cardType, CardThemeType.Payment)
  }

  let getDynamicMaxLength = cardBrand => CardUtils.getMaxLength(cardBrand)

  let renderField = (fieldProps, fieldName, key) => {
    <ReactFinalForm.Field
      name=fieldName key validate={(v, formValues) => validateCardField(v, formValues)}>
      {({input, meta}) => {
        let typedInput = ReactFinalForm.toTypedField(input)

        let cardBrand = getStringValue(input, "card_brand", "")
        let cardNumber = getStringValue(input, "card_number", "")
        Console.log2("Card brand in render:", cardBrand)

        let errorString = switch (meta.touched, meta.error->Nullable.toOption) {
        | (true, Some(err)) => err
        | _ => ""
        }

        <PaymentInputField
          fieldName=fieldProps.localeString.cardNumberLabel
          isValid={errorString == "" ? None : Some(false)}
          setIsValid={_ => ()}
          value=cardNumber
          onChange={ev => handleChange(typedInput.onChange, ev)}
          onBlur=input.onBlur
          rightIcon={getDynamicIcon(cardBrand)}
          errorString
          type_="tel"
          maxLength={getDynamicMaxLength(cardBrand)}
          inputRef=fieldProps.dummyRef
          placeholder="1234 1234 1234 1234"
          autocomplete="cc-number"
        />
      }}
    </ReactFinalForm.Field>
  }
}

module ExpiryField = {
  let handleChange = (originalOnChange, ev) => {
    let val = ReactEvent.Form.target(ev)["value"]
    let formattedExpiry = val->CardValidations.formatCardExpiryNumber
    originalOnChange(formattedExpiry)
  }

  let renderField = (fieldProps, fieldName, key) => {
    <ReactFinalForm.Field
      name=fieldName key validate={(v, formValues) => validateExpiryField(v, formValues)}>
      {({input, meta}) => {
        let typedInput = ReactFinalForm.toTypedField(input)
        let expiryValue = getDecodedStringValue(input)

        <PaymentInputField
          fieldName=fieldProps.localeString.validThruText
          isValid={meta.error->Nullable.toOption->Option.isNone ? None : Some(false)}
          setIsValid={_ => ()}
          value=expiryValue
          onChange={ev => handleChange(typedInput.onChange, ev)}
          onBlur=input.onBlur
          errorString={getErrorString(meta)}
          type_="tel"
          maxLength=7
          inputRef=fieldProps.dummyRef
          placeholder=fieldProps.localeString.expiryPlaceholder
          autocomplete="cc-exp"
        />
      }}
    </ReactFinalForm.Field>
  }
}

module CVCField = {
  let handleChange = (originalOnChange, cardBrand, ev) => {
    let val = ReactEvent.Form.target(ev)["value"]
    let formattedCVC = val->CardValidations.formatCVCNumber(cardBrand)
    originalOnChange(formattedCVC)
  }

  let getDynamicIcon = (currentCVC, cardBrand, isCVCValid) => {
    let isCvcValidValue = CardUtils.getBoolOptionVal(isCVCValid)
    let (cardEmpty, cardComplete, cardInvalid) = CardUtils.useCardDetails(
      ~cvcNumber=currentCVC,
      ~isCvcValidValue,
      ~isCVCValid,
    )
    CardUtils.setRightIconForCvc(~cardEmpty, ~cardInvalid, ~color="#ff0000", ~cardComplete)
  }

  let renderField = (
    fieldProps,
    fieldName,
    cardFieldName,
    key,
    ~className="tracking-widest w-full",
  ) => {
    <ReactFinalForm.Field
      name=fieldName
      key
      validate={(v, formValues) => validateCVCField(v, formValues, cardFieldName)}>
      {({input, meta}) => {
        let form = ReactFinalForm.useForm()
        let typedInput = ReactFinalForm.toTypedField(input)
        let cvcValue = getDecodedStringValue(input)
        let cardBrand = getCardBrandFromForm(form, cardFieldName)

        <PaymentInputField
          fieldName=fieldProps.localeString.cvcTextLabel
          isValid={meta.error->Nullable.toOption->Option.isNone ? None : Some(false)}
          setIsValid={_ => ()}
          value=cvcValue
          onChange={ev => handleChange(typedInput.onChange, cardBrand, ev)}
          onBlur=input.onBlur
          rightIcon={getDynamicIcon(
            cvcValue,
            cardBrand,
            meta.error->Nullable.toOption->Option.isNone ? None : Some(false),
          )}
          errorString={getErrorString(meta)}
          type_="tel"
          className
          maxLength=4
          inputRef=fieldProps.dummyRef
          placeholder="123"
          autocomplete="cc-csc"
        />
      }}
    </ReactFinalForm.Field>
  }
}

@react.component
let make = (~field: fieldConfig, ~fieldIndex: string) => {
  let {localeString} = Recoil.useRecoilValueFromAtom(RecoilAtoms.configAtom)
  let dummyRef = React.useRef(Nullable.null)

  let fieldProps = {
    field,
    fieldIndex,
    localeString,
    dummyRef,
  }

  let name = getFieldNameFromPath(field.outputPath)
  let parentPath = field.name->getParentPathFromOutputPath
  let cardFieldName = SuperpositionTypes.stringToFieldName(name)

  switch cardFieldName {
  | CardNumber => CardNumberField.renderField(fieldProps, field.name, fieldIndex)

  | CardNumberNetworkMerged => CardNumberField.renderField(fieldProps, parentPath, fieldIndex)

  | CardExpMonth => ExpiryField.renderField(fieldProps, field.name, fieldIndex)

  | CardExpiryCvcMerged =>
    <div className="flex gap-4 w-full">
      {ExpiryField.renderField(fieldProps, buildFieldName(parentPath, "card_expiry"), fieldIndex)}
      {CVCField.renderField(
        fieldProps,
        buildFieldName(parentPath, "card_cvc"),
        parentPath,
        fieldIndex ++ "_cvc",
      )}
    </div>

  | CardCvc => CVCField.renderField(fieldProps, field.name, parentPath, fieldIndex)

  | _ => React.null
  }
}
