@react.component
let make = (~paymentType) => {
  let {themeObj} = Recoil.useRecoilValueFromAtom(RecoilAtoms.configAtom)
  <div
    className="flex flex-col gap-2 p-2"
    style={ReactDOMStyle.make(
      ~border=`1px solid ${themeObj.borderColor}`,
      ~borderRadius=themeObj.borderRadius,
      ~margin=`10px 0`,
      (),
    )}>
    {React.string("Billing Address")}
    <AddressPaymentInput paymentType />
  </div>
}
