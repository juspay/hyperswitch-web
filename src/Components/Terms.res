@react.component
let make = (~mode: PaymentModeType.payment) => {
  open RecoilAtoms
  let {localeString, themeObj} = Recoil.useRecoilValueFromAtom(configAtom)
  let {customMessageForCardTerms, business, terms} = Recoil.useRecoilValueFromAtom(optionAtom)
  let cardTermsValue =
    customMessageForCardTerms->String.length > 0
      ? customMessageForCardTerms
      : LocaleStringHelper.getCardTerms(localeString, business.name)

  let terms = switch mode {
  | ACHBankDebit => (
      LocaleStringHelper.getAchBankDebitTerms(localeString, business.name),
      terms.usBankAccount,
    )
  | SepaBankDebit => (
      LocaleStringHelper.getSepaDebitTerms(localeString, business.name),
      terms.sepaDebit,
    )
  | BecsBankDebit => (localeString.becsDebitTermsWeb, terms.auBecsDebit)
  | Card => (cardTermsValue, terms.card)
  | _ => ("", Auto)
  }
  let (termsText, showTerm) = terms

  <RenderIf condition={showTerm == Auto || showTerm == Always}>
    <div className="opacity-50 text-xs mb-2 text-left" style={color: themeObj.colorText}>
      {React.string(termsText)}
    </div>
  </RenderIf>
}
