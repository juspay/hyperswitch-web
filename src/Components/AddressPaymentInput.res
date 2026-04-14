open RecoilAtoms
open PaymentType
open Utils
open PaymentTypeContext

type addressType = Line1 | Line2 | City | Postal | State | Country

let getShowType = str => {
  switch str {
  | "auto" => Auto
  | "never" => Never
  | _ => Auto
  }
}

let showField = (val: PaymentType.addressType, type_: addressType) => {
  switch val {
  | JSONString(str) => getShowType(str)
  | JSONObject(address) =>
    switch type_ {
    | Line1 => address.line1
    | Line2 => address.line2
    | City => address.city
    | Postal => address.postal_code
    | State => address.state
    | Country => address.country
    }
  }
}

@react.component
let make = (
  ~line1Path: string,
  ~line2Path: string,
  ~cityPath: string,
  ~statePath: string,
  ~countryPath: string,
  ~postalPath: string,
  ~className: string="",
  ~paymentType: option<CardThemeType.mode>=?,
) => {
  let {localeString, themeObj} = Recoil.useRecoilValueFromAtom(configAtom)
  let {fields} = Recoil.useRecoilValueFromAtom(optionAtom)
  let showDetails = getShowDetails(~billingDetails=fields.billingDetails)
  let contextPaymentType = usePaymentType()
  let paymentType = paymentType->Option.getOr(contextPaymentType)
  let formState = ReactFinalForm.useFormState()
  let submitFailed = formState.submitFailed

  let (showOtherFields, setShowOtherFields) = React.useState(_ => false)

  let countryData = CountryStateDataRefs.countryDataRef.contents
  let countryNames = getCountryNames(countryData)

  let createValidator = rule =>
    Validation.createFieldValidator(
      rule,
      ~enabledCardSchemes=[],
      ~localeObject=localeString->Obj.magic,
    )

  let line1Field = ReactFinalForm.useField(
    line1Path,
    ~config={validate: createValidator(Validation.Required)},
  )
  let line2Field = ReactFinalForm.useField(line2Path)
  let cityField = ReactFinalForm.useField(
    cityPath,
    ~config={validate: createValidator(Validation.Required)},
  )
  let stateField = ReactFinalForm.useField(
    statePath,
    ~config={validate: createValidator(Validation.Required)},
  )
  let countryField = ReactFinalForm.useField(countryPath)
  let postalField = ReactFinalForm.useField(
    postalPath,
    ~config={
      validate: createValidator(Validation.PostalCode(countryField.input.value->Option.getOr(""))),
    },
  )

  let stateNames = Utils.getStateNames({
    value: countryField.input.value->Option.getOr(""),
    isValid: Some(true),
    errorString: "",
  })

  let line1Ref = React.useRef(Nullable.null)
  let line2Ref = React.useRef(Nullable.null)
  let cityRef = React.useRef(Nullable.null)
  let postalRef = React.useRef(Nullable.null)

  let hasDefaultValues =
    line2Field.input.value->Option.getOr("") !== "" ||
    cityField.input.value->Option.getOr("") !== "" ||
    postalField.input.value->Option.getOr("") !== "" ||
    stateField.input.value->Option.getOr("") !== ""

  let getErrorString = (field: ReactFinalForm.Field.fieldProps) => {
    if (field.meta.touched && !field.meta.active) || submitFailed {
      field.meta.error->Option.getOr("")
    } else {
      ""
    }
  }

  React.useEffect(() => {
    stateField.input.onChange("")
    None
  }, [countryField.input.value])

  <div className="flex flex-col" style={gridGap: themeObj.spacingGridColumn}>
    <RenderIf condition={showField(showDetails.address, Line1) == Auto}>
      <PaymentField
        fieldName=localeString.line1Label
        value={
          value: line1Field.input.value->Option.getOr(""),
          isValid: Some(line1Field.meta.valid),
          errorString: getErrorString(line1Field),
        }
        onChange={ev => {
          setShowOtherFields(_ => true)
          line1Field.input.onChange(ReactEvent.Form.target(ev)["value"])
        }}
        onBlur={_ev => line1Field.input.onBlur()}
        type_="text"
        name="line1"
        className
        inputRef=line1Ref
        placeholder=localeString.line1Placeholder
        paymentType
      />
    </RenderIf>
    <RenderIf condition={showOtherFields || hasDefaultValues}>
      <div className="flex flex-col animate-slowShow" style={gridGap: themeObj.spacingGridColumn}>
        <RenderIf condition={showField(showDetails.address, Line2) == Auto}>
          <PaymentField
            fieldName=localeString.line2Label
            value={
              value: line2Field.input.value->Option.getOr(""),
              isValid: Some(line2Field.meta.valid),
              errorString: getErrorString(line2Field),
            }
            onChange={ev => {
              line2Field.input.onChange(ReactEvent.Form.target(ev)["value"])
            }}
            onBlur={_ev => line2Field.input.onBlur()}
            type_="text"
            name="line2"
            className
            inputRef=line2Ref
            placeholder=localeString.line2Placeholder
            paymentType
          />
        </RenderIf>
        <div className="flex flex-row" style={gridGap: themeObj.spacingGridRow}>
          <RenderIf condition={showField(showDetails.address, Country) == Auto}>
            <PaymentDropDownField
              fieldName=localeString.countryLabel
              value={
                value: countryField.input.value->Option.getOr(""),
                isValid: Some(countryField.meta.valid),
                errorString: getErrorString(countryField),
              }
              className
              setValue={setter => {
                let newVal = setter({
                  value: countryField.input.value->Option.getOr(""),
                  isValid: Some(true),
                  errorString: "",
                })
                countryField.input.onChange(newVal.value)
              }}
              options={countryNames}
            />
          </RenderIf>
          <RenderIf
            condition={showField(showDetails.address, State) == Auto &&
              stateNames->Array.length > 0}>
            <PaymentDropDownField
              fieldName=localeString.stateLabel
              value={
                value: stateField.input.value->Option.getOr(""),
                isValid: Some(stateField.meta.valid),
                errorString: getErrorString(stateField),
              }
              className
              setValue={setter => {
                let newVal = setter({
                  value: stateField.input.value->Option.getOr(""),
                  isValid: Some(true),
                  errorString: "",
                })
                stateField.input.onChange(newVal.value)
              }}
              options={stateNames}
            />
          </RenderIf>
        </div>
        <div className="flex flex-row" style={gridGap: themeObj.spacingGridRow}>
          <RenderIf condition={showField(showDetails.address, City) == Auto}>
            <PaymentField
              fieldName=localeString.cityLabel
              className
              value={
                value: cityField.input.value->Option.getOr(""),
                isValid: Some(cityField.meta.valid),
                errorString: getErrorString(cityField),
              }
              onChange={ev => {
                cityField.input.onChange(ReactEvent.Form.target(ev)["value"])
              }}
              onBlur={_ev => cityField.input.onBlur()}
              type_="text"
              name="city"
              inputRef=cityRef
              placeholder=localeString.cityLabel
              paymentType
            />
          </RenderIf>
          <RenderIf condition={showField(showDetails.address, Postal) == Auto}>
            <PaymentField
              fieldName=localeString.postalCodeLabel
              value={
                value: postalField.input.value->Option.getOr(""),
                isValid: Some(postalField.meta.valid),
                errorString: getErrorString(postalField),
              }
              onBlur={_ev => postalField.input.onBlur()}
              onChange={ev => {
                postalField.input.onChange(ReactEvent.Form.target(ev)["value"])
              }}
              className
              name="postal"
              inputRef=postalRef
              placeholder=localeString.postalCodeLabel
              paymentType
            />
          </RenderIf>
        </div>
      </div>
    </RenderIf>
  </div>
}
