@react.component
let make = () => {
  let {themeObj, config} = Jotai.useAtomValue(JotaiAtoms.configAtom)
  let inputClassStyles = config.appearance.innerLayout === Spaced ? "Input" : "Input-Compressed"

  <div
    className="absolute top-0 left-0 flex w-full p-0.5 pointer-events-none" ariaHidden=true>
    <div
      className={`${inputClassStyles} Input--empty w-full`}
      style={
        height: SavedCardCvcStyles.fieldHeight,
        padding: themeObj.spacingUnit,
        background: themeObj.colorBackground,
      }
    />
  </div>
}
