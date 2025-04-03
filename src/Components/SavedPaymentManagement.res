@react.component
let make = (~savedMethods: array<PaymentType.customerMethods>, ~setSavedMethods) => {
  switch GlobalVars.sdkVersionEnum {
  | V1 => <SavedMethodsV1 savedMethods setSavedMethods />
  | V2 => <SavedMethodsV2 />
  }
}
