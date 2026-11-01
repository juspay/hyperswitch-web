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

type paymentMethodSaveOperation = Save | Update
type paymentMethodSaveData = {operation: paymentMethodSaveOperation}
type paymentMethodSaveOutcomeData = {operation: paymentMethodSaveOperation, status: string}

type lifecycleEvent =
  | VaultFlowFailed(vaultFailureData)
  | PaymentMethodSaveRejected(paymentMethodSaveData)
  | PaymentMethodSaveSucceeded(paymentMethodSaveOutcomeData)
  | PaymentMethodSaveFailed(paymentMethodSaveOutcomeData)

let stateSeverity = (_: stateEvent) => LoggerTypes.Debug
let lifecycleSeverity = event =>
  switch event {
  | VaultFlowFailed(_) | PaymentMethodSaveRejected(_) => LoggerTypes.Error
  | PaymentMethodSaveSucceeded(_) | PaymentMethodSaveFailed(_) => LoggerTypes.Info
  }

type functionEvent = VaultFormCreate
type resourceEvent = VaultScript

type vaultTokenizeScope = SaveCardCvc | FullCard
type vaultTokenizeData = {scope: vaultTokenizeScope}
type apiEvent = VaultTokenization(vaultTokenizeData)

let functionSeverity = (_: functionEvent) => LoggerTypes.quietSuccess
let resourceSeverity = (_: resourceEvent) => LoggerTypes.quietSuccess
let apiSeverity = (_: apiEvent) => LoggerTypes.defaultSeverity
