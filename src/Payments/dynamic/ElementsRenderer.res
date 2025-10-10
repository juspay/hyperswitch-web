@react.component
let make = (~elements: SuperpositionTypes.elementType) => {
  switch elements {
  | CARD(fields) if fields->Array.length > 0 => <CardFieldsRenderer fields />
  | CRYPTO(fields) if fields->Array.length > 0 => <CryptoElement fields />
  | FULLNAME(fields) if fields->Array.length > 0 => <FullNameElement fields />
  | PHONE(fields) if fields->Array.length > 0 => <PhoneElement fields />
  | EMAIL(fields) if fields->Array.length > 0 => <EmailElement fields />
  | GENERIC(fields) if fields->Array.length > 0 => fields
    ->Array.map(field => {
      <DynamicInputFields key={field.outputPath} field />
    })
    ->React.array
  | _ => React.null
  }
}
