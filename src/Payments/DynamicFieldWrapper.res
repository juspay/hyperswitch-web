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
  let (componentWiseRequiredFields, setComponentWiseRequiredFields) = React.useState(() => None)

  let processCardComponentFields = componentWiseFields => {
    componentWiseFields->Array.map(((componentName, fields)) => {
      switch componentName {
      | "card" => {
          let sortedFields =
            fields
            ->mergeFields(
              ["card_number", "card_network"],
              "card_number_network_merged",
              "Card Number",
            )
            ->mergeFields(
              ["card_exp_month", "card_exp_year", "card_cvc"],
              "card_expiry_cvc_merged",
              "Expiry Date and CVC",
            )
            ->sortFields(componentName)
          (componentName, sortedFields)
        }
      | "shipping"
      | "billing" => {
          let sortedFields =
            fields
            ->mergeFields(["first_name", "last_name"], "full_name", "Full Name")
            ->mergeFields(
              ["number", "country_code"],
              "phone_number_with_country_code",
              "Phone Number",
              ~parent="phone",
            )
            ->mergeFields(["city", "state"], "city_state_merged", "City and State")
            ->mergeFields(["zip", "country"], "zip_country_merged", "Zip and Country")
            ->sortFields(componentName)
          (componentName, sortedFields)
        }

      | _ => (componentName, fields)
      }
    })
  }

  let initSuperposition = async () => {
    let componentRequiredFields = await SuperpositionHelper.initSuperpositionAndGetRequiredFields()

    let processedFields = switch componentRequiredFields {
    | Some(fields) => Some(processCardComponentFields(fields))
    | None => None
    }

    setComponentWiseRequiredFields(_ => processedFields)
    Console.log2("Component required fields:", componentRequiredFields)
    Console.log2("Processed fields with merging:", processedFields)
  }

  React.useEffect0(() => {
    initSuperposition()->ignore
    None
  })

  switch componentWiseRequiredFields {
  | Some(fields) if fields->Array.length > 0 =>
    <DynamicFieldsSuperposition
      componentWiseRequiredFields=fields
      cardProps={Some(cardProps)}
      expiryProps={Some(expiryProps)}
      cvcProps={Some(cvcProps)}
    />
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
