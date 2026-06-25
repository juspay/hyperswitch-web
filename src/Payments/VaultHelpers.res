// VaultHelpers
// Types and utilities for vault integrations.
//
// Design: ParentCardComponent stays vault-agnostic; all vault knowledge lives in
// the inner iframe.
//
//   ParentCardComponent (outer iframe)
//     • forwards the raw `sessions` atom to the inner iframe via the standard
//       `sessions` message (same channel the first iframe uses)
//     • never needs to know vault credential field names
//
//   PaymentMethodsSDK (inner iframe)
//     • reads its `sessions` atom (populated by LoaderController)
//     • calls getVaultCredentialsFromSessions(sessions) → typed vaultCredentials variant
//     • stores variant in vaultCredentials Recoil atom
//
//   CardsSDK / vault-specific card components
//     • read vaultCredentials atom
//     • pattern-match variant to pass typed struct to the right component
//
// Adding a new vault (e.g., VGS) requires:
//   1. Add branch to vaultCredentials variant + per-vault record type
//   2. Add branch to buildVaultConfig and decodeVaultCredentials in this file
//   3. Add branch to CardsSDK dispatch
//   → Zero changes to ParentCardComponent or PaymentMethodsSDK

open Utils

// ── Vault provider discriminant ───────────────────────────────────────────────

type vault =
  | VeryGoodSecurity
  | Hyperswitch
  | None

// ── Per-vault credential record types ────────────────────────────────────────

type hyperswitchVaultType = {
  // vault-specific sdkAuthorization token from vault_details.vault_data.sdk_authorization
  // in the sessions API response.  Distinct from the merchant-level sdkAuthorization.
  // This base64 token also embeds payment_method_session_id (decoded into pmSessionId).
  sdkAuthorization: string,
  pmSessionId: string,
}

type vgsVaultType = {
  vaultId: string,
  environment: string,
}

// ── Typed credentials variant (set in Recoil atom inside the inner iframe) ───

type vaultCredentials =
  | HyperswitchVault(hyperswitchVaultType)
  | VGS(vgsVaultType)
  | NoVault

let defaultVaultCredentials = NoVault

// ── Provider name ↔ discriminant ─────────────────────────────────────────────

let getVaultModeFromName = val => {
  switch val {
  | "vgs" => VeryGoodSecurity
  | "hyperswitch" => Hyperswitch
  | _ => None
  }
}

// ── Session-level helpers ────────────────────────────────────────────────────

// Returns the vault provider name from `vault_details.vault_type` or "".
let getVaultName = (sessionObj: PaymentType.loadType) => {
  switch sessionObj {
  | Loaded(session) =>
    let dict = session->getDictFromJson
    dict->getDictFromDict("vault_details")->getString("vault_type", "")
  | _ => ""
  }
}

// ── Opaque vaultConfig builders (called by ParentCardComponent) ──────────────
// Each builder reads vault-specific fields from the sessions response and packs
// them into a JSON object.  The field names are an implementation detail of each
// vault — ParentCardComponent never needs to reference them directly.

let buildHyperswitchVaultConfig = (sessionObj: PaymentType.loadType) => {
  switch sessionObj {
  | Loaded(session) =>
    let dict = session->getDictFromJson
    let vaultData = dict->getDictFromDict("vault_details")->getDictFromDict("vault_data")
    let sdkAuthorization = vaultData->getString("sdk_authorization", "")
    // payment_method_session_id is embedded (base64) inside sdk_authorization,
    // not sent as a separate field — decode it out.
    let authData = sdkAuthorization->getSdkAuthorizationData
    [
      ("sdkAuthorization", sdkAuthorization->JSON.Encode.string),
      ("pmSessionId", authData.pmSessionId->Option.getOr("")->JSON.Encode.string),
    ]
    ->Dict.fromArray
    ->JSON.Encode.object
  | _ => Dict.make()->JSON.Encode.object
  }
}

let buildVGSVaultConfig = (sessionObj: PaymentType.loadType) => {
  switch sessionObj {
  | Loaded(session) =>
    let dict = session->getDictFromJson
    let vaultData = dict->getDictFromDict("vault_details")->getDictFromDict("vault_data")
    [
      ("vaultId", vaultData->getString("vault_id", "")->JSON.Encode.string),
      ("environment", vaultData->getString("environment", "")->JSON.Encode.string),
    ]
    ->Dict.fromArray
    ->JSON.Encode.object
  | _ => Dict.make()->JSON.Encode.object
  }
}

// Dispatches to the right per-vault builder based on vaultMode.
// Returns an opaque JSON blob — ParentCardComponent forwards this verbatim.
let buildVaultConfig = (sessionObj: PaymentType.loadType, vaultMode: vault) => {
  switch vaultMode {
  | Hyperswitch => buildHyperswitchVaultConfig(sessionObj)
  | VeryGoodSecurity => buildVGSVaultConfig(sessionObj)
  | None => Dict.make()->JSON.Encode.object
  }
}

// ── Typed credential decoders (called by PaymentMethodsSDK) ──────────────────
// Each decoder parses the opaque JSON blob into a typed record.
// PaymentMethodsSDK calls decodeVaultCredentials once and stores the variant.

let decodeHyperswitchVaultConfig = (json: JSON.t) => {
  let dict = json->getDictFromJson
  HyperswitchVault({
    sdkAuthorization: dict->getString("sdkAuthorization", ""),
    pmSessionId: dict->getString("pmSessionId", ""),
  })
}

let decodeVGSVaultConfig = (json: JSON.t) => {
  let dict = json->getDictFromJson
  VGS({
    vaultId: dict->getString("vaultId", ""),
    environment: dict->getString("environment", ""),
  })
}

// Dispatches to the right per-vault decoder based on the vaultMode string
// received in the metadata.  Returns the typed vaultCredentials variant.
let decodeVaultCredentials = (vaultModeStr: string, json: JSON.t) => {
  switch vaultModeStr->getVaultModeFromName {
  | Hyperswitch => decodeHyperswitchVaultConfig(json)
  | VeryGoodSecurity => decodeVGSVaultConfig(json)
  | None => NoVault
  }
}

// Derive typed vault credentials directly from the sessions response.
// Used inside the inner iframe (PaymentMethodsSDK) now that ParentCardComponent
// forwards the raw `sessions` via the standard `sessions` message instead of an
// opaque vaultConfig blob.  Reuses build + decode so vault field names stay
// defined in exactly one place.
let getVaultCredentialsFromSessions = (sessionObj: PaymentType.loadType): vaultCredentials => {
  let vaultName = sessionObj->getVaultName
  let vaultMode = vaultName->getVaultModeFromName
  decodeVaultCredentials(vaultName, buildVaultConfig(sessionObj, vaultMode))
}

// ── Vault response token data ─────────────────────────────────────────────────
// Decoded from the vault API response received by ParentCardComponent after the
// inner iframe completes tokenisation.

type vaultTokenData = {
  token: string,
  last4Digits: string,
  binNumber: string,
  expiryMonth: string,
  expiryyear: string,
}

// Decodes the vault API response JSON into a vaultTokenData record.
//   token       ← associated_payment_methods[0].payment_method_token.data
//   last4Digits ← payment_method_data.card.last4_digits
//   binNumber   ← payment_method_data.card.card_isin (may be null)
let decodeVaultTokenData = (vaultResponse: JSON.t): vaultTokenData => {
  let vaultDict = vaultResponse->getDictFromJson

  // token
  let sessionResponse = vaultDict->getArray("associated_payment_methods")
  let tokenEntry =
    sessionResponse
    ->Array.get(0)
    ->Option.flatMap(JSON.Decode.object)
    ->Option.getOr(Dict.make())
  let tokenDict = tokenEntry->getJsonObjectFromDict("payment_method_token")->getDictFromJson
  let token = tokenDict->getString("data", "")

  // card metadata
  let cardDict =
    vaultDict
    ->getDictFromDict("payment_method_data")
    ->getDictFromDict("card")
  let last4Digits = cardDict->getString("last4_digits", "")
  let binNumber = cardDict->getString("card_isin", "")
  let expiryMonth = cardDict->getString("expiry_month", "")
  let expiryyear = cardDict->getString("expiry_year", "")

  {token, last4Digits, binNumber, expiryMonth, expiryyear}
}
