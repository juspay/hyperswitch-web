open SuperpositionHelper
open ConfigurationService

@react.component
let make = (
  ~paymentMethod,
  ~paymentMethodType,
  ~setRequiredFieldsBody,
  ~cardProps,
  ~expiryProps,
  ~cvcProps,
  ~isBancontact,
  ~isSaveDetailsWithClickToPay,
) => {
  let (isSuperpositionInitialized, setIsSuperpositionInitialized) = React.useState(() => false)
  let (componentWiseRequiredFields, setComponentWiseRequiredFields) = React.useState(() => None)

  let initSuperposition = async () => {
    let componentRequiredFields = await SuperpositionHelper.initSuperpositionAndGetRequiredFields()
    setComponentWiseRequiredFields(_ => componentRequiredFields)
    setIsSuperpositionInitialized(_ => true)
    Console.log2("Component required fields:", componentRequiredFields)
  }

  React.useEffect0(() => {
    initSuperposition()->ignore
    None
  })

  switch componentWiseRequiredFields {
  | Some(fields) if fields->Array.length > 0 =>
    <DynamicFieldsSuperposition componentWiseRequiredFields=fields cardProps={Some(cardProps)} />
  | None
  | _ =>
    <DynamicFields
      paymentMethod
      paymentMethodType
      setRequiredFieldsBody
      cardProps={Some(cardProps)}
      expiryProps={Some(expiryProps)}
      cvcProps={Some(cvcProps)}
      isBancontact
      isSaveDetailsWithClickToPay
    />
  }
}
