/* PaymentMethodsSDK
   Rendered inside the innermost iframe (componentName=paymentMethodsSDK), wrapped by
   <LoaderController> (see App.res). LoaderController owns the standard handshake —
   it posts `iframeMounted`, runs `setConfigs` (theme/locale/constants → configAtom),
   sets `keys`, reports height, and populates the `sessions` atom from the `sessions`
   message ParentCardComponent forwards. So this component just derives the vault
   credentials from `sessions` and renders the right payment UI.
   Surface-family dispatch: `surfaceFamily=vault` with no `fieldName` renders the bundled
   <CardsSDK>; `surfaceFamily=vault` or `payments` plus a bare `fieldName` renders the SAME
   shared <SecureCard{Number,Expiry,Cvc}Field> shells.
   LOUD-FAIL: a missing or unknown `surfaceFamily` raises `InvalidSurfaceFamilyParams`
   rather than guessing a default — we control both ends of the iframe URL, so it is always
   our own bug and swallowing it would make regressions undetectable. */

// raised when the iframe is mounted with a missing or unknown `surfaceFamily`.
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

  let componentName = CardUtils.getQueryParamsDictforKey(url.search, "componentName")
  let fieldNameStr = CardUtils.getQueryParamsDictforKey(url.search, "fieldName")
  let surfaceFamilyStr = CardUtils.getQueryParamsDictforKey(url.search, "surfaceFamily")

  let fieldName = fieldNameStr == "" ? None : Some(fieldNameStr)
  let surfaceFamily = surfaceFamilyStr == "" ? None : Some(surfaceFamilyStr)
  let family = PaymentSurfaceFamily.classifyFromUrlParams(~componentName, ~surfaceFamily)

  // only the vault surface consumes `vaultCredentials`; payments confirms via the coordinator.
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
      // one route for both families — the shared shells serve vault and payments alike.
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
        // a recognized family with an unrecognized fieldName is a bug in our code — loud-fail.
        throw(
          InvalidSurfaceFamilyParams({
            componentName,
            surfaceFamily: surfaceFamily->Option.getOr("MISSING"),
            fieldName: `UNKNOWN_FIELD:${unknownField}`,
          }),
        )

      | (PaymentSurfaceFamily.PaymentsFamilyV2, None) =>
        // no merchant-facing API manufactures a bundled payments mount; loud-warn if one appears.
        Console.warn(
          "[PaymentMethodsSDK] PaymentsFamilyV2 with no fieldName — " ++
          "bundled payments surface is not wired. Treat as a bug.",
        )
        React.null

      | (PaymentSurfaceFamily.OtherFamily, _) =>
        /* loud-fail: a missing or invalid surfaceFamily is our own bug. Throwing lets the
           ErrorBoundary render the ghost error card with the URL params. */
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
