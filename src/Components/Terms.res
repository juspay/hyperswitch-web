@react.component
let make = (~styles: JsxDOMStyle.t={}, ~paymentMethod, ~paymentMethodType) => {
  open RecoilAtoms
  let {localeString, themeObj} = Recoil.useRecoilValueFromAtom(configAtom)
  let {
    customMessageForCardTerms,
    business,
    terms,
    alwaysSendCustomerAcceptance,
  } = Recoil.useRecoilValueFromAtom(optionAtom)
  let {payment_type: paymentType} = Recoil.useRecoilValueFromAtom(
    PaymentUtils.paymentMethodListValue,
  )
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

  let (termsText, showTerm) = switch customMessageConfig.displayMode {
  | DefaultSdkMessage => paymentMethodTermsDefaults
  | CustomMessage => {
      let customMessage = customMessageConfig.value->Option.getOr("")->String.trim
      (customMessage, customMessage->String.length > 0 ? Always : Never)
    }
  | Hidden => ("", Never)
  }

  <RenderIf condition={showTerm == Auto || showTerm == Always}>
    <div
      className="TermsTextLabel opacity-50 text-xs mb-2 text-left"
      style={...styles, color: themeObj.colorText}>
      {React.string(termsText)}
    </div>
  </RenderIf>
}
