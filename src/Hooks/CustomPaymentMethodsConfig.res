let useCustomPaymentMethodConfigs = (~paymentMethod, ~paymentMethodType=?) => {
  let {paymentMethodsConfig} = Jotai.useAtomValue(JotaiAtoms.optionAtom)
  let allowedPmTypeForCardPayment = ["debit", "credit"]

  React.useMemo3(() => {
    let methodLevelConfig =
      paymentMethodsConfig->Array.find(config => config.paymentMethod == paymentMethod)

    let methodLevelMessage =
      methodLevelConfig
      ->Option.map(config => config.message)
      ->Option.getOr(PaymentType.defaultPaymentMethodMessage)

    switch paymentMethodType {
    | None => methodLevelMessage
    | Some(pmType) =>
      let typeLevelMessage = methodLevelConfig->Option.flatMap(config =>
        config.paymentMethodTypes
        ->Array.filter(
          pmTypeConfig =>
            paymentMethod == "card"
              ? allowedPmTypeForCardPayment->Array.includes(pmTypeConfig.paymentMethodType)
              : pmTypeConfig.paymentMethodType == pmType,
        )
        ->Array.get(0)
        ->Option.map(pmTypeConfig => pmTypeConfig.message)
      )
      typeLevelMessage->Option.getOr(methodLevelMessage)
    }
  }, (paymentMethod, paymentMethodType, paymentMethodsConfig))
}

type saveCheckboxConfig = {
  displayCheckbox: bool,
  checkedByDefault: bool,
}

// PM/PMType granularity control for the "save payment details" checkbox.
// Resolution order: paymentMethodTypes[] level > paymentMethodsConfig[] level
// > the legacy global options.
let useSaveCheckboxConfig = (~paymentMethod, ~paymentMethodType): saveCheckboxConfig => {
  let {
    paymentMethodsConfig,
    displaySavedPaymentMethodsCheckbox,
    savedPaymentMethodsCheckboxCheckedByDefault,
  } = Jotai.useAtomValue(JotaiAtoms.optionAtom)

  React.useMemo5(() => {
    let methodLevelConfig =
      paymentMethodsConfig->Array.find(config => config.paymentMethod == paymentMethod)

    let typeLevelConfig =
      methodLevelConfig->Option.flatMap(config =>
        config.paymentMethodTypes->Array.find(
          typeConfig => typeConfig.paymentMethodType == paymentMethodType,
        )
      )

    {
      displayCheckbox: typeLevelConfig
      ->Option.flatMap(config => config.displaySavedPaymentMethodsCheckbox)
      ->Option.orElse(
        methodLevelConfig->Option.flatMap(config => config.displaySavedPaymentMethodsCheckbox),
      )
      ->Option.getOr(displaySavedPaymentMethodsCheckbox),
      checkedByDefault: typeLevelConfig
      ->Option.flatMap(config => config.savedPaymentMethodsCheckboxCheckedByDefault)
      ->Option.orElse(
        methodLevelConfig->Option.flatMap(config =>
          config.savedPaymentMethodsCheckboxCheckedByDefault
        ),
      )
      ->Option.getOr(savedPaymentMethodsCheckboxCheckedByDefault),
    }
  }, (
    paymentMethod,
    paymentMethodType,
    paymentMethodsConfig,
    displaySavedPaymentMethodsCheckbox,
    savedPaymentMethodsCheckboxCheckedByDefault,
  ))
}

type saveDetailsCheckboxState = {
  isShow: bool,
  acceptance: option<PaymentMethodsRecord.customerAcceptanceSupport>,
  isChecked: bool,
  setIsChecked: (bool => bool) => unit,
  alwaysSendCustomerAcceptance: bool,
}

// Single source of truth for the save-details checkbox: the visibility rule,
// the backend acceptance requirement, and the shared checked state (atom).
// Consumed by both PaymentMethodsWrapper (customer_acceptance body) and
// DynamicFields (placement) so no element/state drilling is needed.
let useSaveDetailsCheckbox = (~paymentMethod, ~paymentMethodType): saveDetailsCheckboxState => {
  let {alwaysSendCustomerAcceptance} = Jotai.useAtomValue(JotaiAtoms.optionAtom)
  let paymentMethodListValue = Jotai.useAtomValue(PaymentUtils.paymentMethodListValue)
  let checkboxConfig = useSaveCheckboxConfig(~paymentMethod, ~paymentMethodType)
  let (isChecked, setIsChecked) = Jotai.useAtom(JotaiAtoms.saveDetailsCheckedAtom)

  // Re-seed the shared state from the resolved config on payment method switch.
  React.useEffect2(() => {
    setIsChecked(_ => checkboxConfig.checkedByDefault)
    None
  }, (paymentMethodType, checkboxConfig.checkedByDefault))

  // The backend reports `customer_acceptance_support` for card payment-method
  // types too, but the SDK does not consume it for cards: the card save
  // checkbox has its own dedicated components and visibility rules, so the
  // acceptance-driven checkbox must never activate for card.
  let acceptance = React.useMemo3(() => {
    paymentMethod == "card"
      ? None
      : paymentMethodListValue
        ->PaymentMethodsRecord.buildFromPaymentList
        ->Array.find(x =>
          x.paymentMethodName ===
            PaymentUtils.getPaymentMethodName(
              ~paymentMethodType=x.methodType,
              ~paymentMethodName=paymentMethodType,
            )
        )
        ->Option.flatMap(details => details.customerAcceptanceSupport)
  }, (paymentMethod, paymentMethodListValue, paymentMethodType))

  {
    isShow: switch acceptance {
    | Some(Supported) | Some(PartiallySupported) =>
      checkboxConfig.displayCheckbox && !alwaysSendCustomerAcceptance
    | Some(Unsupported) | None => false
    },
    acceptance,
    isChecked,
    setIsChecked,
    alwaysSendCustomerAcceptance,
  }
}
