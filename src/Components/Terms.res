@react.component
let make = (~mode: PaymentModeType.payment, ~styles: JsxDOMStyle.t={}) => {
  open RecoilAtoms
  let {localeString, themeObj} = Recoil.useRecoilValueFromAtom(configAtom)
  let {customMessageForCardTerms, business, terms} = Recoil.useRecoilValueFromAtom(optionAtom)
  let customConfigForSepaBankDebit = CustomPaymentMethodsConfig.useCustomPaymentMethodConfigs(
    "bank_debit",
    "sepa",
  )

  let customMessageConfigForSepaBankDebit =
    customConfigForSepaBankDebit
    ->Option.map(config => config.message)
    ->Option.getOr(PaymentType.defaultPaymentMethodMessage)

  let customMessageForSepaBankDebit = switch customMessageConfigForSepaBankDebit.displayMode {
  | DefaultSdkMessage => localeString.sepaDebitTerms(business.name)
  | CustomMessage => customMessageConfigForSepaBankDebit.value->Option.getOr("")->String.trim
  | Hidden => ""
  }
  let cardTermsValue =
    customMessageForCardTerms->String.length > 0
      ? customMessageForCardTerms
      : localeString.cardTerms(business.name)

  let conditionToShowSepaBankDebitMessage: PaymentType.showTerms = switch customMessageConfigForSepaBankDebit.displayMode {
  | DefaultSdkMessage =>
    switch terms.sepaDebit {
    | Never => Never
    | _ => Always
    }
  | CustomMessage => customMessageForSepaBankDebit->String.length > 0 ? Always : Never
  | Hidden => Never
  }

  let terms = switch mode {
  | ACHBankDebit => (localeString.achBankDebitTerms(business.name), terms.usBankAccount)
  | SepaBankDebit => (customMessageForSepaBankDebit, conditionToShowSepaBankDebitMessage)
  | BecsBankDebit => (localeString.becsDebitTerms, terms.auBecsDebit)
  | Card => (cardTermsValue, terms.card)
  | _ => ("", Auto)
  }
  let (termsText, showTerm) = terms

  <RenderIf condition={showTerm == Auto || showTerm == Always}>
    <div
      className="TermsTextLabel opacity-50 text-xs mb-2 text-left"
      style={...styles, color: themeObj.colorText}>
      {React.string(termsText)}
    </div>
  </RenderIf>
}
