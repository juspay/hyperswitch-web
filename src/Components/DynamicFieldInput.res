open SuperpositionTypes

type fieldItem =
  | SingleField(fieldConfig)
  | CombinedName(fieldConfig, fieldConfig)

let toFieldItems = (fields: array<fieldConfig>): array<fieldItem> => {
  let firstNameField = fields->Array.find(f => f.fieldRenderType === FirstName)
  let lastNameField = fields->Array.find(f => f.fieldRenderType === LastName)
  switch (firstNameField, lastNameField) {
  | (Some(first), Some(last)) =>
    fields->Array.filterMap(field =>
      if field === first {
        Some(CombinedName(first, last))
      } else if field === last {
        None
      } else {
        Some(SingleField(field))
      }
    )
  | _ => fields->Array.map(field => SingleField(field))
  }
}

let itemLayoutRowId = (item: fieldItem): option<string> =>
  switch item {
  | SingleField(field) => field.layoutRowId
  | CombinedName(firstNameField, _) => firstNameField.layoutRowId
  }

let itemKey = (item: fieldItem): string =>
  switch item {
  | SingleField(field) => field.confirmRequestWritePath
  | CombinedName(firstNameField, _) => firstNameField.confirmRequestWritePath
  }

let itemWidthRatio = (item: fieldItem): float =>
  switch item {
  | SingleField(field) => field.layoutWidthRatio->Option.getOr(1.0)
  | CombinedName(firstNameField, _) => firstNameField.layoutWidthRatio->Option.getOr(1.0)
  }

// Groups items by layoutRowId.
// Items with no layoutRowId each form their own singleton row.
let groupItemsByRow = (items: array<fieldItem>): array<array<fieldItem>> => {
  let rows: array<array<fieldItem>> = []
  let rowMap: Dict.t<array<fieldItem>> = Dict.make()

  items->Array.forEach(item => {
    switch itemLayoutRowId(item) {
    | None => rows->Array.push([item])
    | Some(rowId) =>
      switch rowMap->Dict.get(rowId) {
      | Some(row) => row->Array.push(item)
      | None =>
        let row = [item]
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
  ~globalEmailPaths: option<array<string>>=?,
) => {
  switch field.fieldRenderType {
  | CardNumber
  | Cvc
  | CardExpiryMonth
  | CardExpiryYear
  | CardNetwork => React.null

  | Email =>
    let allEmailPaths = switch globalEmailPaths {
    | Some(paths) => paths
    | None => []
    }
    let firstEmailPath = allEmailPaths->Array.get(0)
    <RenderIf condition={firstEmailPath === Some(field.confirmRequestWritePath)}>
      <EmailField fieldConfig=field paths=allEmailPaths />
    </RenderIf>

  | Date
  | DateOfBirth =>
    <DateOfBirth fieldConfig=field />

  | Phone => <PhoneField fieldConfig=field />

  | PhoneCountryCode => <PhoneCountryCodeDropdownField fieldConfig=field />

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

  | CardHolderName
  | FirstName
  | LastName
  | Generic =>
    <GenericInputField fieldConfig=field />
  }
}

// Renders a single derived item: a combined full-name input, or a plain single field.
let renderItem = (
  item: fieldItem,
  ~allFields: array<fieldConfig>,
  ~globalEmailPaths: option<array<string>>=?,
) => {
  switch item {
  | CombinedName(firstNameField, lastNameField) =>
    <CardHolderNameField firstNameField lastNameField />
  | SingleField(field) => renderSingleField(field, ~allFields, ~globalEmailPaths?)
  }
}

// Renders a row of items side-by-side using flex layout.
@react.component
let makeRow = (
  ~items: array<fieldItem>,
  ~allFields: array<fieldConfig>,
  ~globalEmailPaths: option<array<string>>=?,
) => {
  switch items->Array.length {
  | 0 => React.null
  | 1 =>
    switch items->Array.get(0) {
    | None => React.null
    | Some(item) => renderItem(item, ~allFields, ~globalEmailPaths?)
    }
  | _ =>
    <div className="flex gap-4 w-full">
      {items
      ->Array.mapWithIndex((item, i) => {
        let flex = itemWidthRatio(item)
        <div
          key={itemKey(item) ++ "-" ++ i->Int.toString}
          style={flexGrow: flex->Float.toString, flexShrink: "1", flexBasis: "0%"}>
          {renderItem(item, ~allFields, ~globalEmailPaths?)}
        </div>
      })
      ->React.array}
    </div>
  }
}
