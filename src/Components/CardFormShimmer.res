module Block = {
  @react.component
  let make = (~height="2rem", ~width="100%", ~borderRadius="") => {
    let {themeObj} = Jotai.useAtomValue(JotaiAtoms.configAtom)
    let backgroundColor =
      themeObj.borderColor === "" ? "rgba(148, 163, 184, 0.35)" : themeObj.borderColor

    <div
      className="relative overflow-hidden"
      style={
        height,
        width,
        borderRadius: borderRadius === "" ? themeObj.borderRadius : borderRadius,
        backgroundColor,
      }
    >
      <div
        className="absolute inset-0 -translate-x-full animate-[shimmer_1.2s_ease_infinite]"
        style={
          background: `linear-gradient(90deg, transparent, ${themeObj.colorBackground}, transparent)`,
          opacity: "0.7",
        }
      />
    </div>
  }
}

@react.component
let make = (~compact=false) => {
  let {config, themeObj} = Jotai.useAtomValue(JotaiAtoms.configAtom)
  let {innerLayout, labels} = config.appearance
  let showFieldLabels = labels === Above && innerLayout === Spaced
  let labelHeight = themeObj.fontSizeLg === "" ? "0.875rem" : themeObj.fontSizeLg

  if compact {
    <div role="status" ariaLabel="Loading card security field" ariaLive=#polite>
      <div ariaHidden=true>
        <Block height="1.8rem" />
      </div>
    </div>
  } else {
    <div
      className="flex flex-col w-full"
      style={gridGap: themeObj.spacingGridColumn}
      role="status"
      ariaLabel="Loading card form"
      ariaLive=#polite
    >
      <RenderIf condition={innerLayout === Compressed}>
        <div style={marginBottom: "5px"} ariaHidden=true>
          <Block height=labelHeight width="28%" borderRadius="9999px" />
        </div>
      </RenderIf>
      <div className="flex flex-col w-full" ariaHidden=true>
        <RenderIf condition=showFieldLabels>
          <div style={marginBottom: "5px"}>
            <Block height=labelHeight width="34%" borderRadius="9999px" />
          </div>
        </RenderIf>
        <Block />
      </div>
      <div
        className="flex flex-row w-full place-content-between"
        style={gridColumnGap: innerLayout === Spaced ? themeObj.spacingGridRow : ""}
        ariaHidden=true
      >
        {Array.make(~length=2, "")
        ->Array.mapWithIndex((_, index) =>
          <div key={index->Int.toString} className={innerLayout === Spaced ? "w-[47%]" : "w-[50%]"}>
            <RenderIf condition=showFieldLabels>
              <div style={marginBottom: "5px"}>
                <Block height=labelHeight width="55%" borderRadius="9999px" />
              </div>
            </RenderIf>
            <Block />
          </div>
        )
        ->React.array}
      </div>
    </div>
  }
}
