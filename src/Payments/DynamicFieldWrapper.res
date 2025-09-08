open SuperpositionHelper
open SuperpositionTypes

@react.component
let make = (
  ~eligibleConnectors: array<string>,
  ~paymentMethod,
  ~paymentMethodType,
  ~setRequiredFieldsBody,
  ~cardProps=None,
  ~expiryProps=None,
  ~cvcProps=None,
  ~isBancontact=false,
  ~isSaveDetailsWithClickToPay=false,
  ~isSavedCardFlow=false,
  ~savedMethod=PaymentType.defaultCustomerMethods,
) => {
  let (componentWiseRequiredFields, setComponentWiseRequiredFields) = React.useState(() => None)
  let contextWithConnectorArray: SuperpositionTypes.connectorArrayContext = {
    eligibleConnectors: eligibleConnectors->Array.map(value =>
      value->CommonUtils.snakeToPascalCase
    ),
    payment_method: paymentMethod->CommonUtils.snakeToPascalCase,
    payment_method_type: paymentMethodType->CommonUtils.snakeToPascalCase,
    country: "US",
    mandate_type: Some("non_mandate"),
    collect_shipping_details_from_wallet_connector: false,
    collect_billing_details_from_wallet_connector: false,
  }

  let processCardComponentFields = componentWiseFields => {
    componentWiseFields->Array.map(((componentName, fields)) => {
      switch componentName {
      | "card" => {
          let sortedFields =
            fields
            ->mergeFields([CardNumber, CardNetwork], CardNumberNetworkMerged, "Card Number")
            ->mergeFields(
              [CardExpMonth, CardExpYear, CardCvc],
              CardExpiryCvcMerged,
              "Expiry Date and CVC",
            )
            ->sortFields(SuperpositionTypes.stringToComponentType(componentName))
          (componentName, sortedFields)
        }
      | "shipping"
      | "billing" => {
          let sortedFields =
            fields
            ->mergeFields([FirstName, LastName], FullName, "Full Name")
            ->mergeFields(
              [Number, CountryCode],
              PhoneNumberWithCountryCode,
              "Phone Number",
              ~parent="phone",
            )
            ->mergeFields([City, State], CityStateMerged, "City and State")
            ->mergeFields([Zip, Country], ZipCountryMerged, "Zip and Country")
            ->sortFields(SuperpositionTypes.stringToComponentType(componentName))
          (componentName, sortedFields)
        }

      | _ => (componentName, fields)
      }
    })
  }

  let initSuperposition = async () => {
    let componentRequiredFields = await SuperpositionHelper.initSuperpositionAndGetRequiredFields(
      ~contextWithConnectorArray,
    )
    let processedFields = switch componentRequiredFields {
    | Some(fields) => Some(processCardComponentFields(fields))
    | None => None
    }
    Console.log2("Processed Fields:", processedFields)
    setComponentWiseRequiredFields(_ => processedFields)
  }

  React.useEffect0(() => {
    initSuperposition()->ignore
    None
  })

  switch componentWiseRequiredFields {
  | Some(fields) if fields->Array.length > 0 =>
    <DynamicFieldsSuperposition componentWiseRequiredFields=fields />
  | None
  | _ =>
    <DynamicFields
      paymentMethod
      paymentMethodType
      setRequiredFieldsBody
      cardProps={cardProps}
      expiryProps={expiryProps}
      cvcProps={cvcProps}
      isBancontact
      isSaveDetailsWithClickToPay
    />
  }
}
