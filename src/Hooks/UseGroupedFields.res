let useGroupedFieldsFromSuperposition = (
  ~paymentMethod,
  ~paymentMethodType,
  ~country=?,
  ~mandateType=?,
  ~collectShippingDetailsFromWalletConnector=?,
  ~collectBillingDetailsFromWalletConnector=?,
  ~connectors=?,
) => {
  let country = country->Option.getOr("US")
  let mandateType = mandateType->Option.getOr("")
  let collectShippingDetailsFromWalletConnector =
    collectShippingDetailsFromWalletConnector->Option.getOr("")
  let collectBillingDetailsFromWalletConnector =
    collectBillingDetailsFromWalletConnector->Option.getOr("")
  let connectors =
    connectors->Option.getOr(["Stripe"->JSON.Encode.string, "Airwallex"->JSON.Encode.string])

  let configurationService = ConfigurationService.useConfigurationService()
  let paymentMethodListValue = Recoil.useRecoilValueFromAtom(PaymentUtils.paymentMethodListValue)

  let paymentMethodTypes = PaymentUtils.usePaymentMethodTypeFromList(
    ~paymentMethodListValue,
    ~paymentMethod,
    ~paymentMethodType,
  )

  let requiredFieldsDict = React.useMemo1(() => {
    let dict = Dict.make()
    paymentMethodTypes.required_fields->Array.forEachWithIndex((field, index) => {
      let fieldJson = Dict.make()
      fieldJson->Dict.set("required_field", field.required_field->JSON.Encode.string)
      fieldJson->Dict.set("display_name", field.display_name->JSON.Encode.string)
      fieldJson->Dict.set("value", field.value->JSON.Encode.string)
      dict->Dict.set(index->Int.toString, fieldJson->JSON.Encode.object)
    })
    dict
  }, [paymentMethodTypes])

  let requiredFieldsFromPml = React.useMemo0(() => {
    requiredFieldsDict->SuperpositionHelper.extractFieldValuesFromPML
  })

  let superpositionContext: SuperpositionTypes.superpositionBaseContext = {
    payment_method: paymentMethod,
    payment_method_type: paymentMethodType,
    country,
    mandate_type: mandateType,
    collect_shipping_details_from_wallet_connector: collectShippingDetailsFromWalletConnector,
    collect_billing_details_from_wallet_connector: collectBillingDetailsFromWalletConnector,
  }

  let (missingRequiredFields, setMissingRequiredFields) = React.useState(() => [])
  let (initialValues, setInitialValues) = React.useState(() => Dict.make())

  React.useEffect0(() => {
    let loadConfiguration = async () => {
      let (_, missingReqFields, initValues) = await configurationService(
        connectors,
        superpositionContext,
        requiredFieldsFromPml,
      )
      setMissingRequiredFields(_ => missingReqFields)
      setInitialValues(_ => initValues)
    }
    loadConfiguration()->ignore
    None
  })

  let groupedFields = React.useMemo1(() => {
    missingRequiredFields->SuperpositionHelper.categorizedFields
  }, [missingRequiredFields])

  (groupedFields, initialValues)
}
