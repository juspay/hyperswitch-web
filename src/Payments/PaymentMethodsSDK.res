// PaymentMethodsSDK
// Rendered inside the innermost iframe (componentName=paymentMethodsSDK), wrapped by
// <LoaderController> (see App.res). LoaderController owns the standard handshake —
// it posts `iframeMounted`, runs `setConfigs` (theme/locale/constants → configAtom),
// sets `keys`, reports height, and populates the `sessions` atom from the `sessions`
// message ParentCardComponent forwards. So this component just derives the vault
// credentials from `sessions` and renders the right payment UI.
@react.component
let make = () => {
  let sessions = Recoil.useRecoilValueFromAtom(RecoilAtoms.sessions)
  let setVaultCredentials = Recoil.useSetRecoilState(RecoilAtoms.vaultCredentials)

  React.useEffect(() => {
    Console.log3(
      "PaymentMethodsSDK: deriving vault credentials from sessions",
      VaultHelpers.getVaultCredentialsFromSessions(sessions),
      sessions,
    )
    setVaultCredentials(_ => VaultHelpers.getVaultCredentialsFromSessions(sessions))
    None
  }, [sessions])

  // Only card today; future payment methods would branch here.
  <div style={padding: "2px"}>
    <CardsSDK />
  </div>
}
