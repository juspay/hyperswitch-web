/* Standalone card-CVC field for the VaultSDK surface, rendered inside the per-field iframe.
   `savedCard.brand` arrives on the Jotai `savedCardBrand` atom and drives 3-vs-4 digit CVC
   validation; an in-place saved-card swap needs no remount.
   PURE EMITTER — the hidden `cardFormCoordinator` iframe owns the confirm. */

open Utils
open JotaiAtoms

@react.component
let make = () => {
  let loggerState = Jotai.useAtomValue(loggerAtom)
  let savedCardBrand = Jotai.useAtomValue(savedCardBrand)
  let keys = Jotai.useAtomValue(keys)

  /* the group posts `detectedCardBrand` on every brand change; lifted into React state and
     preferred over the empty local brand. A non-empty `savedCardBrand` (Flow B) still wins. */
  let (detectedBrand, setDetectedBrand) = React.useState(_ => "")
  React.useEffect(() => {
    let handleBrandEvent = (ev: Window.event) => {
      if ev.source === iframeParent && (keys.parentURL === "*" || ev.origin === keys.parentURL) {
        let json = ev.data->safeParse
        let dict = json->getDictFromJson
        let brand = dict->getString("detectedCardBrand", "")
        if brand !== "" {
          setDetectedBrand(_ => brand->CardUtils.normalizeCardBrand)
        }
      }
    }
    handleMessage(handleBrandEvent, "")
  }, (keys.parentURL, setDetectedBrand))

  let state = CommonCardFieldHooks.useCardCvcField(
    ~logger=loggerState,
    // precedence: merchant `savedCard.brand` (Flow B) > live-detected brand > useCardForm default.
    ~cardBrandOverride=if savedCardBrand !== "" { savedCardBrand } else { detectedBrand },
    ~onInitiateConfirm=_ => (),
    ~dualPlane=true,
    (),
  )

  <CommonCardFieldHooks.RenderCardCvc state />
}
