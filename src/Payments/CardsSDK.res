// CardsSDK
// Reads the vaultCredentials Recoil atom (set by PaymentMethodsSDK after decoding
// the vaultConfig blob) and dispatches to the right vault-specific card component.
//
// Extending for a new vault:
//   1. Add the vault component (e.g., VGSCardPayment)
//   2. Add a branch here — no other files need to change

// `cvcOnly` is set for the saved-card (return user) flow: the card is already
// saved, so the inner iframe only needs to collect + tokenise the CVC. It is
// always false for the new-card flow (full card fields).
@react.component
let make = (~cvcOnly=false) => {
  let loggerState = Recoil.useRecoilValueFromAtom(RecoilAtoms.loggerAtom)
  let vaultCredentials = Recoil.useRecoilValueFromAtom(RecoilAtoms.vaultCredentials)

  let {cardProps, expiryProps, cvcProps} = CommonCardProps.useCardForm(
    ~logger=loggerState,
    ~paymentType=Payment,
  )

  switch vaultCredentials {
  | HyperswitchVault(_) =>
    // Saved-card (return user) flow renders the CVC-only widget, which tokenises the
    // CVC via the payment-method-session update call; the new-card flow renders the
    // full card form. CardCVCElement is reused here in its vault-tokenise mode.
    cvcOnly
      ? <CardCVCElement cvcProps paymentType=CardThemeType.CardCVCElement isVaultCvcFlow=true />
      : <CardPayment cardProps expiryProps cvcProps isInsideCardSDK=true />
  | VGS(_) => <VGSVault cvcOnly />
  | NoVault =>
    // Vault details not yet loaded. For the new-card flow render the form so the
    // UI is visible; for the saved-card CVC-only flow render nothing until the
    // vault resolves, so the tiny CVC slot never briefly shows a full card form.
    cvcOnly ? React.null : <CardPayment cardProps expiryProps cvcProps isInsideCardSDK=true />
  }
}
