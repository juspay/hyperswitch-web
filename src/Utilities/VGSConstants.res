open VGSTypes

// Pinned VGS Collect.js version — must stay in sync with the script src + integrity
// hash below, and with the CSP allow-list in webpack.common.js.
//
// RELEASE CHECKLIST: when bumping `vgsScriptURL`, ALWAYS
// regenerate `vgsScriptIntegrity` from the new payload. One-liner:
//   curl -s <NEW_URL> | openssl dgst -sha384 -binary | openssl base64 -A
// SRI is enforced on both load paths (iframe `useScript` hook in VGSVault.res
// and direct-injection `loadVGSScript` in VGSVaultBroker.res), so a mismatch
// will break every VGS integration at page load.
let vgsScriptURL = `https://js.verygoodvault.com/vgs-collect/2.27.2/vgs-collect.js`

// Subresource-integrity (SRI-384) hash for the pinned vgs-collect 2.27.2 bundle.
// Fetched from https://js.verygoodvault.com/vgs-collect/2.27.2/vgs-collect.js on
// 2026-08-18. Co-located with `vgsScriptURL` so any version bump updates both
// in lockstep (see the release checklist comment above).
let vgsScriptIntegrity = "sha384-ddxU1XAc77oB4EIpKOgJQ3FN2a6STYPK0JipRqg1x/eW+n5MFn1XbbZa7+KRjkqc"

let cardNumberOptions = {
  \"type": "card-number",
  name: "card_number",
  placeholder: "1234 1234 1234 1234",
  validations: ["required", "validCardNumber"],
  showCardIcon: true,
}

let cardExpiryOptions = expiryPlaceholder => {
  \"type": "card-expiration-date",
  name: "card_exp",
  placeholder: expiryPlaceholder,
  validations: ["required", "validCardExpirationDate"],
  showCardIcon: false,
  yearLength: 2,
}

let cardCvcOptions = {
  \"type": "card-security-code",
  name: "card_cvc",
  placeholder: "123",
  validations: ["required", "validCardSecurityCode"],
  showCardIcon: true,
}

// CSS for the secure CVC field in the saved-card (return user) flow. Keeps the
// VGS input compact (≈ the native 1.8rem cvc input) so it matches the non-vault
// saved-card cvc field rather than the taller new-card field.
let savedCardCvcCss =
  [
    ("padding", "0px"),
    ("margin", "0px"),
    ("line-height", SavedCardCvcStyles.fieldHeight),
    ("height", SavedCardCvcStyles.fieldHeight),
    ("box-sizing", "border-box"),
  ]
  ->Array.map(((key, value)) => (key, value->JSON.Encode.string))
  ->Dict.fromArray
  ->JSON.Encode.object

let savedCardCvcValidations = savedCardBrand => {
  let exactLengthPatterns =
    CardValidations.getobjFromCardPattern(savedCardBrand).cvcLength
    ->Array.map(length => `\\d{${length->Int.toString}}`)
    ->Array.join("|")
  ["required", `/^(?:${exactLengthPatterns})$/`]
}

// Without a card-number field VGS cannot infer the card brand, so use the saved
// card's exact legacy CVC lengths instead of generic validCardSecurityCode.
let savedCardCvcOptions = savedCardBrand => {
  ...cardCvcOptions,
  validations: savedCardCvcValidations(savedCardBrand),
  showCardIcon: false,
  css: savedCardCvcCss,
}
