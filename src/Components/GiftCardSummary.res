open RecoilAtoms

@react.component
let make = (~giftCardPaymentInfoMessage, ~giftCardDiscountMessage) => {
  let {themeObj} = Recoil.useRecoilValueFromAtom(configAtom)
  <div
    className="w-full p-4 mb-3 rounded-lg bg-blue-100"
    style={
      borderColor: themeObj.borderColor,
    }>
    <div className="text-sm text-black">
      <span className="font-medium"> {giftCardDiscountMessage->React.string} </span>
      <span> {giftCardPaymentInfoMessage->React.string} </span>
    </div>
  </div>
}
