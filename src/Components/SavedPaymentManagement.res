@react.component
let make = (
  ~savedMethods: array<PaymentType.customerMethods>,
  ~setSavedMethods,
  ~cvcProps: CardUtils.cvcProps,
) => {
  <SavedMethodsV2 cvcProps />
}
