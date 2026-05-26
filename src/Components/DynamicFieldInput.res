open SuperpositionTypes

// Groups an array of fieldConfig by layoutRowId.
// Fields with no layoutRowId each form their own singleton row.
let groupFieldsByRow = (fields: array<fieldConfig>): array<array<fieldConfig>> => {
  let rows: array<array<fieldConfig>> = []
  let rowMap: Dict.t<array<fieldConfig>> = Dict.make()

  fields->Array.forEach(field => {
    switch field.layoutRowId {
    | None => rows->Array.push([field])
    | Some(rowId) =>
      switch rowMap->Dict.get(rowId) {
      | Some(row) => row->Array.push(field)
      | None =>
        let row = [field]
        rowMap->Dict.set(rowId, row)
        rows->Array.push(row)
      }
    }
  })

  rows
}

// Renders a single fieldConfig entry as a RFF-connected input.
let renderSingleField = (
  field: fieldConfig,
  ~allFields: array<fieldConfig>,
  ~fieldRef: React.ref<Nullable.t<'a>>,
  ~globalEmailPaths: option<array<string>>=?,
) => {
  switch field.fieldRenderType {
  | CardNumber
  | Cvc => React.null

  | CardHolderName =>
    // last_name is rendered as part of the first_name field — skip it here
    if field.confirmRequestWritePath->String.endsWith(".last_name") {
      React.null
    } else {
      let lastNameField =
        allFields->Array.find(f =>
          f.fieldRenderType === CardHolderName &&
            f.confirmRequestWritePath->String.endsWith(".last_name")
        )
      switch lastNameField {
      | Some(lastNameField) => <CardHolderNameField firstNameField=field lastNameField />
      | None =>
        // No separate last_name field — render as a plain Generic input
        let {localeString} = Recoil.useRecoilValueFromAtom(RecoilAtoms.configAtom)
        let {label, placeholder} = DynamicFieldsUtils.resolveFieldTexts(
          ~field,
          ~localeObject=localeString,
        )
        let autocomplete = field.htmlAutocompleteAttribute->Option.getOr("cc-name")
        let validate = DynamicFieldsUtils.resolveValidator(~field, ~localeObject=localeString)
        <ReactFinalForm.Field name={field.confirmRequestWritePath} validate={Some(validate)}>
          {(fieldProps: ReactFinalForm.Field.fieldProps) => {
            let {input, meta} = fieldProps
            let value = input.value->Option.getOr("")
            let isValid = if meta.touched {Some(meta.valid)} else {None}
            let errorString =
              if meta.touched && meta.invalid {meta.error->Option.getOr("")} else {""}
            <PaymentInputField
              fieldName={label}
              value
              onChange={ev => input.onChange(ReactEvent.Form.target(ev)["value"])}
              onBlur={_ev => input.onBlur()}
              isValid
              errorString
              placeholder
              inputRef={fieldRef}
              autocomplete
              maxLength=?{field.maxInputLength}
            />
          }}
        </ReactFinalForm.Field>
      }
    }

  | Email =>
    let allEmailPaths = switch globalEmailPaths {
    | Some(paths) => paths
    | None => []
    }
    let firstEmailPath = allEmailPaths->Array.get(0)
    if firstEmailPath !== Some(field.confirmRequestWritePath) {
      React.null
    } else {
      <EmailField fieldConfig=field paths=allEmailPaths />
    }

  | Date =>
    <DateOfBirth fieldConfig=field />

  | Generic =>
    let {localeString} = Recoil.useRecoilValueFromAtom(RecoilAtoms.configAtom)
    let {label, placeholder} = DynamicFieldsUtils.resolveFieldTexts(~field, ~localeObject=localeString)
    let autocomplete = field.htmlAutocompleteAttribute->Option.getOr("on")
    let validate = DynamicFieldsUtils.resolveValidator(~field, ~localeObject=localeString)

    <ReactFinalForm.Field name={field.confirmRequestWritePath} validate={Some(validate)}>
      {(fieldProps: ReactFinalForm.Field.fieldProps) => {
        let {input, meta} = fieldProps
        let value = input.value->Option.getOr("")
        let isValid = if meta.touched {
          Some(meta.valid)
        } else {
          None
        }
        let errorString = if meta.touched && meta.invalid {
          meta.error->Option.getOr("")
        } else {
          ""
        }
        <PaymentInputField
          fieldName={label}
          value
          onChange={ev => input.onChange(ReactEvent.Form.target(ev)["value"])}
          onBlur={_ev => input.onBlur()}
          isValid
          errorString
          placeholder
          inputRef={fieldRef}
          autocomplete
          maxLength=?{field.maxInputLength}
        />
      }}
    </ReactFinalForm.Field>

  | Dropdown =>
    if field.confirmRequestWritePath->String.endsWith(".state") {
      let countryFieldPath =
        field.confirmRequestWritePath->String.replace(".state", ".country")
      <StateDropdownField field countryFieldPath />
    } else if field.confirmRequestWritePath->String.endsWith(".country") {
      let isoCodes = field.dropdownOptions->Option.getOr([])
      let options =
        isoCodes
        ->Utils.isoOptionsToCountryNames
        ->DropdownField.updateArrayOfStringToOptionsTypeArray
      if options->Array.length === 0 {
        React.null
      } else {
        <CountryDropdownField fieldConfig=field options />
      }
    } else if field.confirmRequestWritePath->String.endsWith(".country_code") {
      <PhoneCountryCodeDropdownField fieldConfig=field />
    } else if field.confirmRequestWritePath->String.endsWith("crypto.network") {
      let currencyField =
        allFields->Array.find(f =>
          f.confirmRequestWritePath->String.endsWith("crypto.pay_currency")
        )
      switch currencyField {
      | None => React.null
      | Some(currencyField) =>
        <CryptoCurrencyNetworks networkField=field currencyField />
      }
    } else {
      let options =
        field.dropdownOptions->Option.getOr([])->DropdownField.updateArrayOfStringToOptionsTypeArray
      if options->Array.length === 0 {
        React.null
      } else {
        let initialValue = options->Array.get(0)->Option.map(o => o.value)->Option.getOr("")
        <GenericDropdownField fieldConfig=field options initialValue />
      }
    }

  | Phone =>
    <PhoneField fieldConfig=field />
  }
}

// Renders a row of fields side-by-side using flex layout.
@react.component
let makeRow = (
  ~fields: array<fieldConfig>,
  ~allFields: array<fieldConfig>,
  ~globalEmailPaths: option<array<string>>=?,
) => {
  let fieldRef = React.useRef(Nullable.null)

  switch fields->Array.length {
  | 0 => React.null
  | 1 =>
    switch fields->Array.get(0) {
    | None => React.null
    | Some(field) =>
      renderSingleField(
        field,
        ~allFields,
        ~fieldRef,
        ~globalEmailPaths?,
      )
    }
  | _ =>
    <div className="flex gap-4 w-full">
      {fields
      ->Array.mapWithIndex((field, i) => {
        let flex = field.layoutWidthRatio->Option.getOr(1.0)
        <div
          key={field.confirmRequestWritePath ++ "-" ++ i->Int.toString}
          style={flexGrow: flex->Float.toString, flexShrink: "1", flexBasis: "0%"}>
          {renderSingleField(
            field,
            ~allFields,
            ~fieldRef,
            ~globalEmailPaths?,
          )}
        </div>
      })
      ->React.array}
    </div>
  }
}
