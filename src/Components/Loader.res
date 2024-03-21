@react.component
let make = (~showText=true) => {
  let arr = ["hyperswitch-triangle", "hyperswitch-square", "hyperswitch-circle"]

  <div className="flex flex-col gap-10 justify-center items-center">
    <div className="flex flex-row gap-10">
      {arr
      ->Array.mapWithIndex((item, i) => {
        <Icon
          size=52
          style={ReactDOMStyle.make(
            ~animation="slowShow 1.5s ease-in-out infinite",
            ~animationDelay={((i + 1) * 180)->Belt.Int.toString ++ "ms"},
            (),
          )}
          name=item
          key={i->Belt.Int.toString}
        />
      })
      ->React.array}
    </div>
    <RenderIf condition={showText}>
      <div className="flex flex-col gap-5">
        <div className="font-semibold text-sm text-gray-200 self-center ">
          {React.string("We are processing your payment...")}
        </div>
        <div className="font-medium text-xs text-gray-400 self-center text-center w-3/4 ">
          {React.string(
            "You have been redirected to new tab to complete your payments. Status will be updated automatically",
          )}
        </div>
      </div>
    </RenderIf>
  </div>
}
