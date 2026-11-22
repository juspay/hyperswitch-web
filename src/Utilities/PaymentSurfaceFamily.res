type surfaceFamily =
  | VaultFamily
  | PaymentsFamily
  | OtherFamily

let classifyFromUrlParams = (~componentName: string, ~surfaceFamily: option<string>): surfaceFamily =>
  switch (componentName, surfaceFamily) {
  | ("paymentMethodsSDK", Some("vault")) => VaultFamily
  | ("paymentMethodsSDK", Some("payments")) => PaymentsFamily
  | _ => OtherFamily
  }

type coordinatorFamily =
  | VaultCoordinator
  | PaymentsCoordinator
  | OtherCoordinatorFamily

let classifyCoordinatorFromUrl = (~componentName: string, ~surfaceFamily: option<string>): coordinatorFamily =>
  switch (componentName, surfaceFamily) {
  | ("cardFormCoordinator", Some("vault")) => VaultCoordinator
  | ("cardFormCoordinator", Some("payments")) => PaymentsCoordinator
  | _ => OtherCoordinatorFamily
  }
