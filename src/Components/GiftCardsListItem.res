open RecoilAtoms

@react.component
let make = (~displayName, ~balanceText, ~giftCardType, ~removeGiftCard, ~id) => {
  let {themeObj} = Recoil.useRecoilValueFromAtom(configAtom)
  <div
    className="flex items-center justify-between p-4 mb-3 rounded-lg border"
    style={
      borderColor: themeObj.borderColor,
      backgroundColor: themeObj.colorBackground,
    }>
    <div className="flex items-center gap-3">
      <div className="w-8 h-8 flex items-center justify-center">
        {switch giftCardType->String.toLowerCase {
        | "givex" => <Icon name="givex" size=19 width=25 />
        | _ => <Icon name="gift-cards" size=16 />
        }}
      </div>
      <div className="flex flex-col">
        <span className="text-sm font-medium" style={color: themeObj.colorText}>
          {displayName->React.string}
        </span>
      </div>
    </div>
    <div className="flex items-center gap-3">
      <span className="text-sm font-medium text-green-850"> {balanceText->React.string} </span>
      <button
        className="w-5 h-5 flex items-center justify-center"
        onClick={_ => removeGiftCard(id)->ignore}>
        <Icon name="cross" size=16 />
      </button>
    </div>
  </div>
}
