// PaymentMethodsSDK
// Rendered inside the innermost iframe (componentName=paymentMethodsSDK), wrapped by
// <LoaderController> (see App.res). LoaderController owns the standard handshake —
// it posts `iframeMounted`, runs `setConfigs` (theme/locale/constants → configAtom),
// sets `keys`, reports height, and populates the `sessions` atom from the `sessions`
// message ParentCardComponent forwards. So this component just derives the vault
// credentials from `sessions` and renders the right payment UI.
@react.component
let make = () => {
  let sessions = Jotai.useAtomValue(JotaiAtoms.sessions)
  let setVaultCredentials = Jotai.useSetAtom(JotaiAtoms.vaultCredentials)
  let isConfigReady = Jotai.useAtomValue(JotaiAtoms.isConfigReady)
  // When the iframe was mounted for the saved-card (return user) flow, only the
  // vault CVC field is collected here — the card number / expiry live on the
  // already-saved card. CardsSDK renders the vault-appropriate CVC-only component.
  let isSavedCardCvcFlow = Jotai.useAtomValue(JotaiAtoms.isSavedCardCvcFlow)
  let {themeObj, localeString} = Jotai.useAtomValue(JotaiAtoms.configAtom)

  React.useEffect(() => {
    setVaultCredentials(_ => VaultHelpers.getVaultCredentialsFromSessions(sessions))
    None
  }, [sessions])

  // Only card today; future payment methods would branch here.
  <RenderIf condition=isConfigReady>
    <div
      className="w-full font-medium"
      style={
        padding: "2px",
        boxSizing: "border-box",
        color: themeObj.colorText,
        background: "transparent",
        fontFamily: themeObj.fontFamily,
        fontSize: themeObj.fontSizeBase,
      }
      dir=localeString.localeDirection
    >
      <CardsSDK cvcOnly=isSavedCardCvcFlow />
    </div>
  </RenderIf>
}
