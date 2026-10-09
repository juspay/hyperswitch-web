@react.component
let make = (~styles: JsxDOMStyle.t={}, ~paymentMethod, ~paymentMethodType) => {
  open JotaiAtoms
  let {localeString, themeObj} = Jotai.useAtomValue(configAtom)
  let {
    customMessageForCardTerms,
    business,
    terms,
    alwaysSendCustomerAcceptance,
  } = Jotai.useAtomValue(optionAtom)
  let {payment_type: paymentType} = Jotai.useAtomValue(PaymentUtils.paymentMethodListValue)
  let cardTermsValue =
    customMessageForCardTerms != ""
      ? customMessageForCardTerms
      : localeString.cardTerms(business.name)

  let paymentMethodTermsDefaults = switch paymentMethod {
  | "bank_debit" =>
    switch paymentMethodType {
    | "sepa" => (localeString.sepaDebitTerms(business.name), terms.sepaDebit)
    | "becs" => (localeString.becsDebitTerms, terms.auBecsDebit)
    | "ach" => (localeString.achBankDebitTerms(business.name), terms.usBankAccount)
    | _ => ("", Never)
    }
  | "card" =>
    switch paymentType {
    | NEW_MANDATE | SETUP_MANDATE => (cardTermsValue, terms.card)
    | _ => alwaysSendCustomerAcceptance ? (cardTermsValue, terms.card) : ("", Never)
    }
  | _ => ("", Never)
  }

  let customMessageConfig = CustomPaymentMethodsConfig.useCustomPaymentMethodConfigs(
    ~paymentMethod,
    ~paymentMethodType,
  )
  let customMessageSegments = CustomMessageText.useSegments(~message=customMessageConfig)

  let (termsText, showTerm) = switch customMessageConfig.displayMode {
  | DefaultSdkMessage => paymentMethodTermsDefaults
  | CustomMessage => {
      let customMessage = customMessageSegments->CustomMessageUtils.segmentsToPlainText
      (customMessage, customMessage->String.length > 0 ? Always : Never)
    }
  | Hidden => ("", Never)
  }

  // A dimmed container would also dim nested links (contrast risk on an
  // interactive element), so when links are present the dimming moves from
  // the container onto the plain-text runs only.
  let hasLinks =
    customMessageConfig.displayMode == CustomMessage &&
      customMessageSegments->CustomMessageText.hasElementSegment
  let containerClassName = hasLinks
    ? "TermsTextLabel text-xs mb-2 text-left"
    : "TermsTextLabel opacity-50 text-xs mb-2 text-left"

  <RenderIf condition={showTerm == Auto || showTerm == Always}>
    <div className=containerClassName style={...styles, color: themeObj.colorText}>
      {switch customMessageConfig.displayMode {
      | CustomMessage =>
        <CustomMessageText
          message=customMessageConfig
          paymentMethod
          paymentMethodType
          textClassName={hasLinks ? "opacity-50" : ""}
        />
      | DefaultSdkMessage | Hidden => React.string(termsText)
      }}
    </div>
  </RenderIf>
}
