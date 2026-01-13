@react.component
let make = (
  ~savedMethods: array<PaymentType.customerMethods>,
  ~setSavedMethods,
  ~cvcProps: CardUtils.cvcProps,
) => {
  switch GlobalVars.sdkVersion {
  | V1 => <SavedMethodsV1 savedMethods setSavedMethods />
  | V2 => <SavedMethodsV2 cvcProps />
  }
}
