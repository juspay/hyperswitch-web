@react.component
let make = (~mode: PaymentModeType.payment, ~styles: JsxDOMStyle.t={}) => {
  open RecoilAtoms
  let {localeString, themeObj} = Recoil.useRecoilValueFromAtom(configAtom)
  let {customMessageForCardTerms, business, terms} = Recoil.useRecoilValueFromAtom(optionAtom)
  let cardTermsValue =
    customMessageForCardTerms->String.length > 0
      ? customMessageForCardTerms
      : localeString.cardTerms(business.name)

  let terms = switch mode {
  | ACHBankDebit => (localeString.achBankDebitTerms(business.name), terms.usBankAccount)
  | SepaBankDebit => (localeString.sepaDebitTerms(business.name), terms.sepaDebit)
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
