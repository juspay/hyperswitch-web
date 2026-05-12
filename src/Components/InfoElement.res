@react.component
let make = () => {
  let {themeObj, localeString} = Recoil.useRecoilValueFromAtom(RecoilAtoms.configAtom)
  let {redirectionText} = Recoil.useRecoilValueFromAtom(RecoilAtoms.optionAtom)
  let selectedOption =
    Recoil.useRecoilValueFromAtom(RecoilAtoms.selectedOptionAtom)->PaymentModeType.paymentMode

  if redirectionText.hide {
    React.null
  } else {
    let defaultText = switch selectedOption {
    | ACHTransfer
    | BacsTransfer
    | SepaTransfer
    | InstantTransfer
    | InstantTransferFinland
    | InstantTransferPoland
    | Boleto =>
      localeString.bankDetailsText
    | _ => localeString.redirectText
    }

    let displayText = redirectionText.text->Option.getOr(defaultText)

    <div
      className="InfoElement flex flex-row w-full pr-3 gap-3"
      style={
        color: themeObj.colorText,
        fontSize: themeObj.fontSizeLg,
        opacity: "60%",
        fontWeight: themeObj.fontWeightLight,
      }>
      <div>
        <Icon name="redirect" size=55 shouldMirrorIcon={localeString.localeDirection === "rtl"} />
      </div>
      <div className="self-center"> {displayText->React.string} </div>
    </div>
  }
}
