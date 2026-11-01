type cardFormScope = PaymentForm | VaultForm
type cardFormData = {scope: cardFormScope}
type cardFieldData = {scope: cardFormScope, field: string}
type cardFormCompletionData = {scope: cardFormScope, fields: array<string>}

type vaultFailure =
  | FieldBindingFailed
  | FieldMountFailed
  | FieldUpdateFailed
  | FieldUnmountFailed
  | FormCreationFailed
  | TokenizationFailed

type vaultFailureData = {reason: vaultFailure}

type stateEvent =
  | CardFormCreated(cardFormData)
  | CardFormDestroyed(cardFormData)
  | CardFieldCreated(cardFieldData)
  | CardFieldMounted(cardFieldData)
  | CardFieldRendered(cardFieldData)
  | CardFormCompleted(cardFormCompletionData)
  | CardFieldUnmounted(cardFieldData)

type lifecycleEvent = VaultFlowFailed(vaultFailureData)

let stateSeverity = (_: stateEvent) => LoggerTypes.Debug
let lifecycleSeverity = (_: lifecycleEvent) => LoggerTypes.Error

type functionEvent = VaultFormCreate
type resourceEvent = VaultScript

type vaultTokenizeScope = SaveCardCvc | FullCard
type vaultTokenizeData = {scope: vaultTokenizeScope}
type apiEvent = VaultTokenization(vaultTokenizeData)

let functionSeverity = (_: functionEvent) => LoggerTypes.quietSuccess
let resourceSeverity = (_: resourceEvent) => LoggerTypes.quietSuccess
let apiSeverity = (_: apiEvent) => LoggerTypes.defaultSeverity
