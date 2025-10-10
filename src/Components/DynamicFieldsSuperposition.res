open SuperpositionTypes
@react.component
let make = (
  ~groupedFields,
  ~paymentMethod,
  ~paymentMethodType,
  ~setRequiredFieldsBody,
  ~isSavedCardFlow=false,
  ~savedMethod=PaymentType.defaultCustomerMethods,
  ~cardProps=None,
  ~expiryProps=None,
  ~cvcProps=None,
  ~isBancontact=false,
  ~isSaveDetailsWithClickToPay=false,
) => {
  let (
    cardFields,
    emailFields,
    billingNameFields,
    billingPhoneFields,
    billingOtherFields,
    cryptoFields,
    otherFields,
  ) = groupedFields
  <>
    <ReactFinalForm.Form
      key="dynamic-fields-form"
      onSubmit={_ => ()}
      //   subscription={Dict.fromArray([("submitting", true), ("submitError", true)])}
      render={_ => {
        <>
          <ElementsRenderer elements=CARD(cardFields) />
          <ElementsRenderer elements=CRYPTO(cryptoFields) />
          <ElementsRenderer elements=FULLNAME(billingNameFields) />
          <ElementsRenderer elements=PHONE(billingPhoneFields) />
          <ElementsRenderer elements=EMAIL(emailFields) />
          <ElementsRenderer elements=GENERIC(billingOtherFields) />
          <ElementsRenderer elements=GENERIC(otherFields) />
          <ReactFinalForm.FormValuesSpy />
        </>
      }}
    />
  </>
}
