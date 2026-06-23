open SuperpositionTypes

// Groups fields by layoutRowId.
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
  ~paymentMethodType: string,
  ~hideLabel=false,
  ~globalEmailFields: option<array<fieldConfig>>=?,
  ~globalCardHolderNameFields: option<array<fieldConfig>>=?,
) => {
  switch field.fieldRenderType {
  | CardNumber
  | Cvc
  | CardExpiryMonth
  | CardExpiryYear
  | CardNetwork
  | LanguagePreference => React.null

  | Email =>
    let allEmailFields = globalEmailFields->Option.getOr([])
    let firstEmailPath = allEmailFields->Array.get(0)->Option.map(f => f.confirmRequestWritePath)
    <RenderIf condition={firstEmailPath === Some(field.confirmRequestWritePath)}>
      <EmailField fields=allEmailFields />
    </RenderIf>

  | CardHolderName =>
    let allCardHolderNameFields = switch globalCardHolderNameFields {
    | Some(nameFields) => nameFields
    | None => []
    }
    let firstCardHolderNamePath =
      allCardHolderNameFields->Array.get(0)->Option.map(field => field.confirmRequestWritePath)
    <RenderIf condition={firstCardHolderNamePath === Some(field.confirmRequestWritePath)}>
      <CardHolderNameField fields=allCardHolderNameFields />
    </RenderIf>

  | Date
  | DateOfBirth =>
    <DateOfBirth fieldConfig=field />

  | Phone => <PhoneField fieldConfig=field hideLabel />

  | PhoneCountryCode => <PhoneCountryCodeDropdownField fieldConfig=field hideLabel />

  | State => <StateDropdownField fieldConfig=field />

  | Country =>
    let isoCodes = field.dropdownOptions->Option.getOr([])
    let options =
      isoCodes
      ->Utils.isoOptionsToCountryNames
      ->DropdownField.updateArrayOfStringToOptionsTypeArray
    <RenderIf condition={options->Array.length > 0}>
      <CountryDropdownField fieldConfig=field options />
    </RenderIf>

  | CryptoNetwork =>
    switch DynamicFieldsUtils.findCryptoCurrencyField(~allFields) {
    | None => React.null
    | Some(currencyField) => <CryptoCurrencyNetworks networkField=field currencyField />
    }

  | CryptoCurrency
  | Dropdown =>
    let options =
      field.dropdownOptions->Option.getOr([])->DropdownField.updateArrayOfStringToOptionsTypeArray
    <RenderIf condition={options->Array.length > 0}>
      <GenericDropdownField fieldConfig=field options />
    </RenderIf>

  | BankNamesSelect =>
    let options = Bank.getBanks(paymentMethodType)->Array.map(bank => {
      DropdownField.value: bank.value,
      label: bank.displayName,
    })
    <RenderIf condition={options->Array.length > 0}>
      <BankNamesSelectField fieldConfig=field options />
    </RenderIf>

  | FirstName
  | LastName
  | Generic =>
    <GenericInputField fieldConfig=field />
  }
}

// Renders a single shared label above a combined row of fields.
let renderRowLabel = (~label: string, ~themeObj: CardThemeType.themeClass) =>
  <div
    className="Label"
    style={
      fontWeight: themeObj.fontWeightNormal,
      fontSize: themeObj.fontSizeLg,
      marginBottom: "5px",
      opacity: "0.6",
    }
    ariaHidden=true>
    {React.string(label)}
  </div>

// Renders a row of fields side-by-side using flex layout.
@react.component
let makeRow = (
  ~items: array<fieldConfig>,
  ~allFields: array<fieldConfig>,
  ~paymentMethodType: string,
  ~globalEmailFields: option<array<fieldConfig>>=?,
  ~globalCardHolderNameFields: option<array<fieldConfig>>=?,
) => {
  let {config, localeString, themeObj} = Recoil.useRecoilValueFromAtom(RecoilAtoms.configAtom)
  switch items->Array.length {
  | 0 => React.null
  | 1 =>
    switch items->Array.get(0) {
    | None => React.null
    | Some(field) =>
      renderSingleField(
        field,
        ~allFields,
        ~paymentMethodType,
        ~globalEmailFields?,
        ~globalCardHolderNameFields?,
      )
    }
  | _ =>
    let isCombinedPhoneRow = DynamicFieldsUtils.isCombinedPhoneRow(~items)

    let rowLabel = isCombinedPhoneRow
      ? DynamicFieldsUtils.getCombinedPhoneRowLabel(~items, ~localeObject=localeString)
      : ""

    let showRowLabel =
      isCombinedPhoneRow &&
      rowLabel->String.length > 0 &&
      config.appearance.labels === Above &&
      config.appearance.innerLayout === Spaced

    <>
      <RenderIf condition={showRowLabel}> {renderRowLabel(~label=rowLabel, ~themeObj)} </RenderIf>
      <div className="flex gap-4 w-full">
        {items
        ->Array.mapWithIndex((field, i) =>
          <div
            key={field.confirmRequestWritePath ++ "-" ++ i->Int.toString}
            style={
              flexGrow: field.layoutWidthRatio->Option.getOr(1.0)->Float.toString,
              flexShrink: "1",
              flexBasis: "0",
              minWidth: "0",
            }>
            {renderSingleField(
              field,
              ~allFields,
              ~paymentMethodType,
              ~hideLabel=showRowLabel,
              ~globalEmailFields?,
              ~globalCardHolderNameFields?,
            )}
          </div>
        )
        ->React.array}
      </div>
    </>
  }
}
