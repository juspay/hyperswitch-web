@react.component
let make = (
  ~paymentMethodType,
  ~setRequiredFieldsBody,
  ~savedMethod: PaymentType.customerMethods,
  ~cvcNumber,
) => {
  open DynamicFieldsUtils

  // Create required fields array based on saved method
  let requiredFields = React.useMemo(() => {
    open PaymentMethodsRecord
    let fields = []

    // Add CVC field if required
    if savedMethod.requiresCvv {
      fields
      ->Array.push({
        required_field: "card_cvc",
        display_name: "card_cvc",
        field_type: CardCvc,
        value: cvcNumber,
      })
      ->ignore
    }

    // Add cardholder name field if card doesn't have one
    let isAllStoredCardsHaveName = PaymentType.getIsStoredPaymentMethodHasName(savedMethod)
    if !isAllStoredCardsHaveName {
      fields
      ->Array.push({
        required_field: "payment_method_data.card.card_holder_name",
        display_name: "card_holder_name",
        field_type: BillingName,
        value: "",
      })
      ->ignore
    }

    fields
  }, (savedMethod, cvcNumber))

  // Use the shared hook for consistency
  useRequiredFieldsBody(
    ~requiredFields,
    ~paymentMethodType,
    ~cardNumber="",
    ~cardExpiry="",
    ~cvcNumber,
    ~isSavedCardFlow=true,
    ~isAllStoredCardsHaveName=PaymentType.getIsStoredPaymentMethodHasName(savedMethod),
    ~setRequiredFieldsBody,
  )

  // Handle saved billing address separately since it's not part of dynamic fields
  React.useEffect(() => {
    setRequiredFieldsBody(prev => {
      let updatedBody = Dict.copy(prev)
      let savedBillingAddress = savedMethod.billing.address

      // Set billing address fields directly as flat keys if they exist
      savedBillingAddress.line1->Option.mapOr(
        (),
        line1 =>
          updatedBody->Dict.set(
            "payment_method_data.billing.address.line1",
            line1->JSON.Encode.string,
          ),
      )
      savedBillingAddress.line2->Option.mapOr(
        (),
        line2 =>
          updatedBody->Dict.set(
            "payment_method_data.billing.address.line2",
            line2->JSON.Encode.string,
          ),
      )
      savedBillingAddress.city->Option.mapOr(
        (),
        city =>
          updatedBody->Dict.set(
            "payment_method_data.billing.address.city",
            city->JSON.Encode.string,
          ),
      )
      savedBillingAddress.state->Option.mapOr(
        (),
        state =>
          updatedBody->Dict.set(
            "payment_method_data.billing.address.state",
            state->JSON.Encode.string,
          ),
      )
      savedBillingAddress.country->Option.mapOr(
        (),
        country =>
          updatedBody->Dict.set(
            "payment_method_data.billing.address.country",
            country->JSON.Encode.string,
          ),
      )
      savedBillingAddress.zip->Option.mapOr(
        (),
        zip =>
          updatedBody->Dict.set("payment_method_data.billing.address.zip", zip->JSON.Encode.string),
      )

      updatedBody
    })
    None
  }, savedMethod)

  React.null
}
