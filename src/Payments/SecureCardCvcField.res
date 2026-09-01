// Phase 1a Task 3: standalone card-CVC field for the VaultSDK surface.
//
// Rendered inside the per-field iframe (v18 URL: `componentName=paymentMethodsSDK&fieldName=cardCvc&surfaceFamily=vault`).
// Reads the merchant-supplied `savedCard.brand` from the Jotai `savedCardBrand`
// atom (populated by `LoaderController` from the `paymentElementCreate` mount
// message in `PaymentMethodsSessionGroup`). This drives 3-vs-4 digit CVC
// validation — when the merchant swaps saved cards in-place, they call
// `fieldHandle.update({savedCard: {brand: "amex"}})` and the group posts an
// updated `savedCardBrand` into this iframe; no remount required.
//
// MessageChannel Card Relay: PURE EMITTER — the confirm owns in the hidden
// `cardFormCoordinator` iframe; this shell no longer runs the
// `update-saved-payment-method` POST nor responds to the retired
// `initiate-confirm-cvc` trigger.
open Utils
open JotaiAtoms

@react.component
let make = () => {
  let loggerState = Jotai.useAtomValue(loggerAtom)
  let savedCardBrand = Jotai.useAtomValue(savedCardBrand)
  let keys = Jotai.useAtomValue(keys)

  // v20 Chunk 2 follow-up — brand-aware CVC maxLength. The outer group
  // (PaymentMethodsSessionGroup) detects the live card brand from the
  // cardNumber iframe's `cardStateUpdate` stream and posts
  // `[("detectedCardBrand", "<normalized-brand>")]` into this iframe on
  // every brand change. We lift that into a React state and prefer it over
  // the (empty) local derived brand. Saved-card flow B is untouched: when
  // `savedCardBrand` is non-empty it wins over the live-detected brand,
  // matching the behaviour of `CardsSDK.cvcOnly` on the bundled surface.
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
    // Precedence: explicit merchant-supplied `savedCard.brand` (Flow B) >
    // live-detected brand from the group (Flow A) > `useCardForm` default.
    // Both map into `CommonCardProps.useCardForm`'s `cardBrandForCvc` and
    // thence `maxCVCLength` / `formatCVCNumber` / `cvcNumberInRange`.
    ~cardBrandOverride=if savedCardBrand !== "" { savedCardBrand } else { detectedBrand },
    ~onInitiateConfirm=_ => (),
    ~dualPlane=true,
    (),
  )

  <CommonCardFieldHooks.RenderCardCvc state />
}
