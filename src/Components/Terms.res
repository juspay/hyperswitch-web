open PaymentModeType
open PaymentType

@react.component
let make = (~mode) => {
  let {localeString, themeObj} = Recoil.useRecoilValueFromAtom(RecoilAtoms.configAtom)
  let options = Recoil.useRecoilValueFromAtom(RecoilAtoms.optionAtom)
  let terms = switch mode {
  | ACHBankDebit => (
      localeString.achBankDebitTerms(options.business.name),
      options.terms.usBankAccount,
    )
  | SepaBankDebit => (localeString.sepaDebitTerms(options.business.name), options.terms.sepaDebit)
  | BecsBankDebit => (localeString.becsDebitTerms, options.terms.auBecsDebit)
  | Card => (localeString.cardTerms(options.business.name), options.terms.card)
  | _ => ("", Auto)
  }
  let (termsText, showTerm) = terms

  <RenderIf condition={showTerm == Auto || showTerm == Always}>
    <div className="opacity-50 text-xs mb-2 text-left" style={color: themeObj.colorText}>
      {React.string(termsText)}
    </div>
  </RenderIf>
}
