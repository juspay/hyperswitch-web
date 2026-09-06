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
      | (PaymentSurfaceFamily.VaultFamily, Some("cardNumber"))
      | (PaymentSurfaceFamily.PaymentsFamily, Some("cardNumber")) =>
        <SecureCardNumberField />
      | (PaymentSurfaceFamily.VaultFamily, Some("cardExpiry"))
      | (PaymentSurfaceFamily.PaymentsFamily, Some("cardExpiry")) =>
        <SecureCardExpiryField />
      | (PaymentSurfaceFamily.VaultFamily, Some("cardCvc"))
      | (PaymentSurfaceFamily.PaymentsFamily, Some("cardCvc")) =>
        <SecureCardCvcField />
      | (PaymentSurfaceFamily.VaultFamily, None) => <CardsSDK cvcOnly=isSavedCardCvcFlow />

      | (PaymentSurfaceFamily.VaultFamily, Some(unknownField))
      | (PaymentSurfaceFamily.PaymentsFamily, Some(unknownField)) =>
        throw(
          InvalidSurfaceFamilyParams({
            componentName,
            surfaceFamily: surfaceFamily->Option.getOr("MISSING"),
            fieldName: `UNKNOWN_FIELD:${unknownField}`,
          }),
        )

      | (PaymentSurfaceFamily.PaymentsFamily, None) =>
        Console.warn(
          "[PaymentMethodsSDK] PaymentsFamily with no fieldName — " ++
          "bundled payments surface is not wired. Treat as a bug.",
        )
        React.null

      | (PaymentSurfaceFamily.OtherFamily, _) =>
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
