// Static stand-in for the saved-card (return user) CVC field, held over the nested
// iframe's container while that iframe boots so the row never grows around it.
//
// Mirrors how PaymentInputField styles the CVC input inside that iframe: the compressed
// layout drops the rounded corners, and the background follows the Payment payment-type
// (the iframe renders without a PaymentTypeContext provider, so it takes the context
// default). Geometry comes from SavedCardCvcStyles, which both frames share.
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
