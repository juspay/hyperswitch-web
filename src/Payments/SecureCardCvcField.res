open Utils
open JotaiAtoms

@react.component
let make = () => {
  let loggerState = Jotai.useAtomValue(loggerAtom)
  let savedCardBrand = Jotai.useAtomValue(savedCardBrand)
  let keys = Jotai.useAtomValue(keys)

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
    ~cardBrandOverride=if savedCardBrand !== "" { savedCardBrand } else { detectedBrand },
    ~onInitiateConfirm=_ => (),
    ~dualPlane=true,
    (),
  )

  <CommonCardFieldHooks.RenderCardCvc state />
}
