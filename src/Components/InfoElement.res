@react.component
let make = () => {
  let {themeObj, localeString} = Recoil.useRecoilValueFromAtom(RecoilAtoms.configAtom)
  let selectedOption =
    Recoil.useRecoilValueFromAtom(RecoilAtoms.selectedOptionAtom)->PaymentModeType.paymentMode
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
    <div className="self-center">
      {switch selectedOption {
      | ACHTransfer
      | BacsTransfer
      | SepaTransfer
      | InstantTransfer
      | Boleto =>
        localeString.bankDetailsText
      | _ => localeString.redirectText
      }->React.string}
    </div>
  </div>
}
