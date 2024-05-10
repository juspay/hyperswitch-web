@react.component
let make = () => {
  let {themeObj, localeString} = Recoil.useRecoilValueFromAtom(RecoilAtoms.configAtom)
  let selectedOption =
    Recoil.useRecoilValueFromAtom(RecoilAtoms.selectedOptionAtom)->PaymentModeType.paymentMode
  <div className="flex flex-row w-full pr-3 gap-3" style={color: themeObj.colorText}>
    <div>
      <Icon name="redirect" size=55 shouldMirrorIcon={localeString.localeDirection === "rtl"} />
    </div>
    <div
      className="self-center"
      style={
        fontSize: themeObj.fontSizeLg,
        opacity: "60%",
        fontWeight: themeObj.fontWeightLight,
      }>
      {switch selectedOption {
      | ACHTransfer
      | BacsTransfer
      | SepaTransfer
      | Boleto =>
        localeString.bankDetailsText
      | _ => localeString.redirectText
      }->React.string}
    </div>
  </div>
}
