// CardsSDK
// Reads the vaultCredentials Recoil atom (set by PaymentMethodsSDK after decoding
// the vaultConfig blob) and dispatches to the right vault-specific card component.
//
// Extending for a new vault:
//   1. Add the vault component (e.g., VGSCardPayment)
//   2. Add a branch here — no other files need to change

@react.component
let make = () => {
  let loggerState = Recoil.useRecoilValueFromAtom(RecoilAtoms.loggerAtom)
  let vaultCredentials = Recoil.useRecoilValueFromAtom(RecoilAtoms.vaultCredentials)

  let {cardProps, expiryProps, cvcProps} = CommonCardProps.useCardForm(
    ~logger=loggerState,
    ~paymentType=Payment,
  )

  switch vaultCredentials {
  | HyperswitchVault(_) => <CardPayment cardProps expiryProps cvcProps isInsideCardSDK=true />
  | VGS(_) =>
    // TODO: render VGSCardPayment when VGS iframe integration is implemented
    // React.null
    <VGSVault />
  | NoVault =>
    // Fallback: vault details not yet loaded — render form so UI is visible
    <CardPayment cardProps expiryProps cvcProps isInsideCardSDK=true />
  }
}
