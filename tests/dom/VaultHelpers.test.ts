import { describe, expect, it } from "vitest";
import * as Vault from "../../src/Payments/VaultHelpers.bs.js";
import * as Session from "../../src/hyper-loader/PaymentMethodSession.bs.js";
import { authorization, card } from "../helpers/lifecycle-fixtures";
const loaded = (value: unknown) => ({
  TAG: "Loaded",
  _0: value
});
describe("vault credential and response boundaries", () => {
  it("packs only supported merchant vault fields into the synthetic session", () => {
    const auth = authorization();
    const session = Session.buildSyntheticSession("pms_unit", "cus_unit", "hyperswitch", {
      sdkAuthorization: auth,
      vaultId: "vault_unit",
      environment: "sandbox",
      ...card,
      arbitrary: "omit"
    });
    expect(session).toEqual({
      payment_method_session_id: "pms_unit",
      customer_id: "cus_unit",
      associated_payment_methods: [],
      vault_details: {
        vault_type: "hyperswitch",
        vault_data: {
          sdk_authorization: auth,
          vault_id: "vault_unit",
          environment: "sandbox"
        }
      }
    });
    expect(Vault.getVaultCredentialsFromSessions(loaded(session))).toEqual({
      TAG: "HyperswitchVault",
      _0: {
        sdkAuthorization: auth,
        pmSessionId: "pms_unit"
      }
    });
  });
  it("selects VGS credentials and excludes unrelated session and card data", () => {
    const session = {
      vault_details: {
        vault_type: "vgs",
        vault_data: {
          vault_id: "vault_unit",
          environment: "sandbox",
          ...card,
          sdk_authorization: "do-not-copy"
        }
      },
      ...card
    };
    expect(Vault.getVaultName(loaded(session))).toBe("vgs");
    expect(Vault.buildVaultConfig(loaded(session), "VeryGoodSecurity")).toEqual({
      vaultId: "vault_unit",
      environment: "sandbox"
    });
    expect(Vault.getVaultCredentialsFromSessions(loaded(session))).toEqual({
      TAG: "VGS",
      _0: {
        vaultId: "vault_unit",
        environment: "sandbox"
      }
    });
  });
  it("defaults missing credentials without inventing a vault provider", () => {
    for (const state of ["Loading", {
      TAG: "LoadError",
      _0: {}
    }, loaded({})]) {
      expect(Vault.getVaultName(state)).toBe("");
      expect(Vault.getVaultCredentialsFromSessions(state)).toBe("NoVault");
      expect(Vault.buildHyperswitchVaultConfig(state)).toEqual(typeof state !== "string" && state.TAG === "Loaded" ? {
        sdkAuthorization: "",
        pmSessionId: ""
      } : {});
      expect(Vault.buildVGSVaultConfig(state)).toEqual(typeof state !== "string" && state.TAG === "Loaded" ? {
        vaultId: "",
        environment: ""
      } : {});
    }
    expect(Vault.getVaultModeFromName("hyperswitch")).toBe("Hyperswitch");
    expect(Vault.getVaultModeFromName("vgs")).toBe("VeryGoodSecurity");
    expect(Vault.getVaultModeFromName("other")).toBe("None");
    expect(Vault.decodeVaultCredentials("unknown", card)).toBe("NoVault");
    expect(Vault.decodeVaultCredentials("vgs", {
      vaultId: 42,
      environment: false
    })).toEqual({
      TAG: "VGS",
      _0: {
        vaultId: "",
        environment: ""
      }
    });
    expect(Vault.decodeVaultCredentials("hyperswitch", null)).toEqual({
      TAG: "HyperswitchVault",
      _0: {
        sdkAuthorization: "",
        pmSessionId: ""
      }
    });
  });
  it("returns only the first token and allowed card metadata from a vault response", () => {
    expect(Vault.decodeVaultTokenData({
      associated_payment_methods: [{
        payment_method_token: {
          data: "tok_first"
        }
      }, {
        payment_method_token: {
          data: "tok_second"
        }
      }],
      payment_method_data: {
        card: {
          last4_digits: "1111",
          card_isin: "411111",
          expiry_month: "10",
          expiry_year: "2029",
          ...card
        }
      },
      ...card
    })).toEqual({
      token: "tok_first",
      last4Digits: "1111",
      binNumber: "411111",
      expiryMonth: "10",
      expiryYear: "2029"
    });
    for (const value of [null, {}, {
      associated_payment_methods: [false],
      payment_method_data: {
        card: {
          last4_digits: 1111
        }
      }
    }]) {
      expect(Vault.decodeVaultTokenData(value)).toEqual({
        token: "",
        last4Digits: "",
        binNumber: "",
        expiryMonth: "",
        expiryYear: ""
      });
    }
  });
});
