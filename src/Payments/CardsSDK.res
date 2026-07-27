// CardsSDK
// Reads the vaultCredentials Recoil atom (set by PaymentMethodsSDK after decoding
// the vaultConfig blob) and dispatches to the right vault-specific card component.
//
// Extending for a new vault:
//   1. Add the vault component (e.g., VGSCardPayment)
//   2. Add a branch here — no other files need to change

// `cvcOnly` is set for the saved-card (return user) flow: the card is already
// saved, so the inner iframe only needs to collect and return/tokenise the CVC. It is
// always false for the new-card flow (full card fields).
@react.component
let make = (~cvcOnly=false) => {
  let loggerState = Recoil.useRecoilValueFromAtom(RecoilAtoms.loggerAtom)
  let vaultCredentials = Recoil.useRecoilValueFromAtom(RecoilAtoms.vaultCredentials)
  let cardCollectionMode = Recoil.useRecoilValueFromAtom(RecoilAtoms.cardCollectionMode)
  let isBancontact = Recoil.useRecoilValueFromAtom(RecoilAtoms.isBancontactCardFlow)
  let cardFlowType = Recoil.useRecoilValueFromAtom(RecoilAtoms.cardFlowType)
  let savedCardBrand = Recoil.useRecoilValueFromAtom(RecoilAtoms.savedCardBrand)
  let setShowPaymentMethodsScreen = Recoil.useSetRecoilState(RecoilAtoms.showPaymentMethodsScreen)

  // A full new-card collector always represents the payment-method screen.
  // This was previously initialised by the Hyperswitch vault collector itself; keeping it at the
  // dispatcher makes the invariant hold for raw, Hyperswitch Vault and VGS.
  React.useEffect(() => {
    if !cvcOnly {
      setShowPaymentMethodsScreen(_ => true)
    }
    None
  }, [cvcOnly])

  let {cardProps, expiryProps, cvcProps} = CommonCardProps.useCardForm(
    ~logger=loggerState,
    ~paymentType=cardFlowType,
    ~runEligibility=cardCollectionMode !== RawEmit,
    ~logControlEvents=cardCollectionMode !== RawEmit,
    ~useExternalCardSupport=cardCollectionMode === RawEmit && !cvcOnly,
    ~cardBrandOverride=cvcOnly ? savedCardBrand : "",
  )

  switch (cardCollectionMode, vaultCredentials, cvcOnly) {
  | (RawEmit, _, true) =>
    <CardCVCElement
      cvcProps
      paymentType=CardThemeType.CardCVCElement
      isSavedCardCvcFlow=true
      savedCardBrand
    />
  | (RawEmit, _, false) => <RawCardCollector cardProps expiryProps cvcProps isBancontact />
  | (Tokenise, HyperswitchVault(_), _) =>
    // Saved-card (return user) flow renders the CVC-only widget, which tokenises the
    // CVC via the payment-method-session update call; the new-card flow renders the
    // full card form. CardCVCElement is reused here in its vault-tokenise mode.
    cvcOnly
      ? <CardCVCElement
          cvcProps
          paymentType=CardThemeType.CardCVCElement
          isSavedCardCvcFlow=true
          isVaultCvcFlow=true
          savedCardBrand
        />
      : <HyperswitchVaultCardCollector cardProps expiryProps cvcProps />
  | (Tokenise, VGS(_), _) => <VGSVault cvcOnly />
  | (Tokenise, NoVault, _) =>
    // Vault details not yet loaded. For the new-card flow render the form so the
    // UI is visible; for the saved-card CVC-only flow render nothing until the
    // vault resolves, so the tiny CVC slot never briefly shows a full card form.
    cvcOnly ? React.null : <HyperswitchVaultCardCollector cardProps expiryProps cvcProps />
  }
}
