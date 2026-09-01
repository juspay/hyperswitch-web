/* classifies which surface an iframe was mounted for, from its `componentName`, `fieldName`
   and `surfaceFamily` URL params. A missing or unknown `surfaceFamily` is a loud fail.
   Legacy payments strings route through App.res's catch-all and never reach this classifier. */

// `OtherFamily` is the loud-fail path (raises `InvalidSurfaceFamilyParams` upstream).
type surfaceFamily =
  | VaultFamily // `componentName=paymentMethodsSDK&surfaceFamily=vault`
  | PaymentsFamilyV2 // `componentName=paymentMethodsSDK&surfaceFamily=payments`
  | OtherFamily // Any other combination (missing surfaceFamily, unknown value, etc.)

/* `None` (param missing) and `Some("")` (present but empty) are treated identically
   upstream; anything but the two valid pairs is the raise path. */
let classifyFromUrlParams = (~componentName: string, ~surfaceFamily: option<string>): surfaceFamily =>
  switch (componentName, surfaceFamily) {
  | ("paymentMethodsSDK", Some("vault")) => VaultFamily
  | ("paymentMethodsSDK", Some("payments")) => PaymentsFamilyV2
  | _ => OtherFamily
  }

/* the coordinator derives its family from the same URL param and uses it to route confirm
   ownership: payments Flow A to `usePaymentIntent`, vault to `PaymentHelpersV2`. */
type coordinatorFamily =
  | VaultCoordinator // `componentName=cardFormCoordinator&surfaceFamily=vault`
  | PaymentsCoordinator // `componentName=cardFormCoordinator&surfaceFamily=payments`
  | OtherCoordinatorFamily // unknown/missing → loud-fail arm upstream

let classifyCoordinatorFromUrl = (~componentName: string, ~surfaceFamily: option<string>): coordinatorFamily =>
  switch (componentName, surfaceFamily) {
  | ("cardFormCoordinator", Some("vault")) => VaultCoordinator
  | ("cardFormCoordinator", Some("payments")) => PaymentsCoordinator
  | _ => OtherCoordinatorFamily
  }
