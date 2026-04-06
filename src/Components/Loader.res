@react.component
let make = (~branding="auto", ~showText=true) => {
  let {localeString} = Recoil.useRecoilValueFromAtom(RecoilAtoms.configAtom)
  let arr = ["hyperswitch-triangle", "hyperswitch-square", "hyperswitch-circle"]

  <div className="flex flex-col gap-10 justify-center items-center">
    <div className="flex flex-row gap-10">
      <RenderIf condition={branding === "auto"}>
        {arr
        ->Array.mapWithIndex((item, i) => {
          <Icon
            size=52
            style={
              animation: "slowShow 1.5s ease-in-out infinite",
              animationDelay: {((i + 1) * 180)->Int.toString ++ "ms"},
            }
            name=item
            key={i->Int.toString}
          />
        })
        ->React.array}
      </RenderIf>
      <RenderIf condition={branding === "never"}>
        <div
          className="inline-block h-8 w-8 animate-spin rounded-full border-4 border-solid border-[#0069FD] border-r-transparent align-[-0.125em] motion-reduce:animate-[spin_1.5s_linear_infinite]"
          role="status">
          <span
            className="!absolute !-m-px !h-px !w-px !overflow-hidden !whitespace-nowrap !border-0 !p-0 ![clip:rect(0,0,0,0)]">
            {localeString.loadingText->React.string}
          </span>
        </div>
      </RenderIf>
    </div>
    <RenderIf condition={showText}>
      <div className="flex flex-col gap-5">
        <div className="font-semibold text-sm text-gray-200 self-center ">
          {React.string(localeString.processingPaymentText)}
        </div>
        <div className="font-medium text-xs text-gray-400 self-center text-center w-3/4 ">
          {React.string(localeString.redirectedToNewTabText)}
        </div>
      </div>
    </RenderIf>
  </div>
}
