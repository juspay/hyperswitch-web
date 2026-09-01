// PaymentMethodsSDK
// Rendered inside the innermost iframe (componentName=paymentMethodsSDK), wrapped by
// <LoaderController> (see App.res). LoaderController owns the standard handshake —
// it posts `iframeMounted`, runs `setConfigs` (theme/locale/constants → configAtom),
// sets `keys`, reports height, and populates the `sessions` atom from the `sessions`
// message ParentCardComponent forwards. So this component just derives the vault
// credentials from `sessions` and renders the right payment UI.
//
// Surface-family dispatch via URL params. This single component
// serves THREE surfaces, discriminated by the iframe's URL:
//
//   componentName=paymentMethodsSDK       → BUNDLED vault card surface (no
//   &surfaceFamily=vault                    fieldName). Existing behavior:
//                                            renders <CardsSDK> which fans out
//                                            on cardCollectionMode /
//                                            vaultCredentials / cvcOnly.
//
//   componentName=paymentMethodsSDK       → VAULT PER-FIELD surface. Renders
//   &surfaceFamily=vault                    one of
//   &fieldName=cardNumber |                 <SecureCard{Number|Expiry|Cvc}Field />.
//             cardExpiry |
//             cardCvc
//
//   componentName=paymentMethodsSDK       → PAYMENTS card surface.
//   &surfaceFamily=payments                 Merchant-facing factory is
//   &fieldName=cardNumber |                 `hyper.widgets(opts).cardForm()`
//             cardExpiry |                  `.create("cardNumber"|"cardExpiry"
//             cardCvc                       |"cardCvc")` — bare vocabulary.
//                                            Renders the SAME shared shells
//                                            as the vault surface; confirm
//                                            belongs to
//                                            the hidden `cardFormCoordinator`
//                                            iframe (MessageChannel Card
//                                            Relay), not to any per-field
//                                            dispatcher.
//
// LOUD-FAIL CONTRACT: if `surfaceFamily` is missing/empty/unknown, the
// dispatcher does NOT guess a default — it raises `InvalidSurfaceFamilyParams`
// which is caught by the `ErrorBoundary` at `src/Index.res:13-15` and surfaced
// as the ghost error card with details. This is by design: a missing
// surfaceFamily is always a bug in OUR code (we control both ends of the
// iframe URL), and swallowing it silently would make future regressions
// undetectable.
//
// Single-iframe topology: for the payments CardForm surface, the payments
// CardForm group (`PaymentsGroup.makeCardForm`) mounts ONE iframe per field via
// `LoaderPaymentElement.make("paymentMethodsSDK", ..., ~fieldName=Some(<bare>),
// ~surfaceFamily=Some("payments"))`.

// Raised when the iframe is mounted with a missing or unknown `surfaceFamily`.
// Caught by `ErrorBoundary level=ErrorBoundary.Top` in `src/Index.res:13-15`.
exception InvalidSurfaceFamilyParams({
  componentName: string,
  surfaceFamily: string,
  fieldName: string,
})

@react.component
let make = () => {
  let url = RescriptReactRouter.useUrl()
  let sessions = Jotai.useAtomValue(JotaiAtoms.sessions)
  let setVaultCredentials = Jotai.useSetAtom(JotaiAtoms.vaultCredentials)
  let isConfigReady = Jotai.useAtomValue(JotaiAtoms.isConfigReady)
  // When the iframe was mounted for the saved-card (return user) flow, only the
  // vault CVC field is collected here — the card number / expiry live on the
  // already-saved card. CardsSDK renders the vault-appropriate CVC-only component.
  let isSavedCardCvcFlow = Jotai.useAtomValue(JotaiAtoms.isSavedCardCvcFlow)
  let {themeObj, localeString} = Jotai.useAtomValue(JotaiAtoms.configAtom)

  // URL-param surface dispatch.
  let componentName = CardUtils.getQueryParamsDictforKey(url.search, "componentName")
  let fieldNameStr = CardUtils.getQueryParamsDictforKey(url.search, "fieldName")
  let surfaceFamilyStr = CardUtils.getQueryParamsDictforKey(url.search, "surfaceFamily")

  let fieldName = fieldNameStr == "" ? None : Some(fieldNameStr)
  let surfaceFamily = surfaceFamilyStr == "" ? None : Some(surfaceFamilyStr)
  let family = PaymentSurfaceFamily.classifyFromUrlParams(~componentName, ~surfaceFamily)

  // Only the vault surface consumes `vaultCredentials` today. Gate the
  // effect on vault-only to avoid unnecessary downstream atom churn; the
  // payments family drives its confirm through the `cardFormCoordinator`
  // iframe (MessageChannel Card Relay) and needs no vault credentials here.
  React.useEffect(() => {
    if family === PaymentSurfaceFamily.VaultFamily {
      setVaultCredentials(_ => VaultHelpers.getVaultCredentialsFromSessions(sessions))
    }
    None
  }, (family, sessions))

  <RenderIf condition=isConfigReady>
    <div
      className="font-medium p-0.5"
      style={
        color: themeObj.colorText,
        fontFamily: themeObj.fontFamily,
        fontSize: themeObj.fontSizeBase,
      }
      dir=localeString.localeDirection
    >
      {switch (family, fieldName) {
      // P1 convergence: ONE route for both families. The three shared
      // shells (`SecureCard{Number,Expiry,Cvc}Field`) serve vault AND
      // payments per-field iframes alike — per-family differences lived
      // exclusively in the confirm relay, whose ownership moved to the
      // hidden `cardFormCoordinator` iframe (MessageChannel Card Relay).
      // The surfaces differ only in the outer group that mounts them.
      | (PaymentSurfaceFamily.VaultFamily, Some("cardNumber"))
      | (PaymentSurfaceFamily.PaymentsFamilyV2, Some("cardNumber")) =>
        <SecureCardNumberField />
      | (PaymentSurfaceFamily.VaultFamily, Some("cardExpiry"))
      | (PaymentSurfaceFamily.PaymentsFamilyV2, Some("cardExpiry")) =>
        <SecureCardExpiryField />
      | (PaymentSurfaceFamily.VaultFamily, Some("cardCvc"))
      | (PaymentSurfaceFamily.PaymentsFamilyV2, Some("cardCvc")) =>
        <SecureCardCvcField />
      | (PaymentSurfaceFamily.VaultFamily, None) => <CardsSDK cvcOnly=isSavedCardCvcFlow />

      | (PaymentSurfaceFamily.VaultFamily, Some(unknownField))
      | (PaymentSurfaceFamily.PaymentsFamilyV2, Some(unknownField)) =>
        // Recognized family with an unrecognized fieldName — this is a bug
        // in OUR code (never merchant-reachable). Loud-fail.
        throw(
          InvalidSurfaceFamilyParams({
            componentName,
            surfaceFamily: surfaceFamily->Option.getOr("MISSING"),
            fieldName: `UNKNOWN_FIELD:${unknownField}`,
          }),
        )

      | (PaymentSurfaceFamily.PaymentsFamilyV2, None) =>
        // A bundled payments surface is not scoped — no merchant-facing API
        // manufactures a bundled payments mount today (every payments mount
        // arrives with `fieldName` populated). Loud-warn so any future
        // regression that reaches this branch is visible in devtools.
        Console.warn(
          "[PaymentMethodsSDK] PaymentsFamilyV2 with no fieldName — " ++
          "bundled payments surface is not wired. Treat as a bug.",
        )
        React.null

      | (PaymentSurfaceFamily.OtherFamily, _) =>
        // Loud-fail: missing/invalid surfaceFamily is a bug in our own code.
        // Throw so the ErrorBoundary at Index.res:13-15 catches and renders
        // the ghost error card with the URL params for diagnosis.
        throw(
          InvalidSurfaceFamilyParams({
            componentName,
            surfaceFamily: surfaceFamily->Option.getOr("MISSING"),
            fieldName: fieldName->Option.getOr("MISSING"),
          }),
        )
      }}
    </div>
  </RenderIf>
}
