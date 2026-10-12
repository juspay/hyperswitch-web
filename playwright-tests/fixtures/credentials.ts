// ---------------------------------------------------------------------------
// Merchant credentials for the live tier.
//
// One file, credentialsOutputPath():
//   CREDENTIALS_OUTPUT_PATH when set (CI points it outside the workspace),
//   otherwise playwright-tests/test-credentials-<TEST_ENV>.json (gitignored).
// A file is only accepted when it carries profile IDs for every connector in
// requiredPresetProfileIds; otherwise it is ignored as stale.
//
// When the file is missing or stale, the `live-setup` project
// (setup/credentials.setup.ts) provisions a merchant with
// setup/merchant-setup.js#setupAllCredentials and writes it there.
//
// The hermetic tier never reads any of this: it uses HERMETIC_CREDENTIALS.
// ---------------------------------------------------------------------------
import fs from "node:fs";
import path from "node:path";
import { PW_ROOT, TEST_ENV, requiredPresetProfileIds } from "./env";
import { connectorEnum, type Connector } from "./connectors";

export interface Credentials {
  publishableKey: string;
  secretKey: string;
  merchantId: string;
  connectorProfileIds: Record<string, string>;
}

/** The file the setup project writes and the live tier reads. */
export const credentialsOutputPath = (): string =>
  process.env.CREDENTIALS_OUTPUT_PATH
    ? path.resolve(process.env.CREDENTIALS_OUTPUT_PATH)
    : path.join(PW_ROOT, `test-credentials-${TEST_ENV}.json`);

export interface LoadedCredentials {
  credentials: Credentials;
  path: string;
}

/** Returns the pre-provisioned credentials file if it exists and is valid, or null. Never throws. */
export function loadPresetCredentials(log = false): LoadedCredentials | null {
  const file = credentialsOutputPath();
  if (!fs.existsSync(file)) return null;
  try {
    const parsed = JSON.parse(fs.readFileSync(file, "utf-8")) as Credentials;
    const missing = requiredPresetProfileIds.filter(
      (c) => !parsed.connectorProfileIds?.[c],
    );
    if (missing.length > 0) {
      if (log)
        console.warn(
          `[playwright] Ignoring stale credentials at ${file}: missing profile IDs for ${missing.join(", ")}.`,
        );
      return null;
    }
    if (log)
      console.log(
        `[playwright] Using credentials at ${file} (merchant ${parsed.merchantId})`,
      );
    return { credentials: parsed, path: file };
  } catch (err) {
    if (log)
      console.warn(
        `[playwright] Failed to parse ${file}: ${(err as Error).message}`,
      );
    return null;
  }
}

/**
 * Fake, clearly-non-secret credentials used by the hermetic tier. Every
 * connector in connectorEnum gets a deterministic profile ID so specs can keep
 * using `credentials.profileId(connectorEnum.X)` unchanged.
 */
export const HERMETIC_CREDENTIALS: Credentials = {
  publishableKey: "pk_snd_hermetic0000000000000000000000",
  secretKey: "snd_hermetic_not_a_real_key",
  merchantId: "merchant_hermetic",
  connectorProfileIds: Object.fromEntries(
    Object.values(connectorEnum).map((c) => [c, `pro_hermetic_${c}`]),
  ),
};

/** Credentials plus a per-connector profile ID lookup. */
export class TestCredentials implements Credentials {
  readonly publishableKey: string;
  readonly secretKey: string;
  readonly merchantId: string;
  readonly connectorProfileIds: Record<string, string>;

  constructor(c: Credentials) {
    this.publishableKey = c.publishableKey;
    this.secretKey = c.secretKey;
    this.merchantId = c.merchantId;
    this.connectorProfileIds = { ...c.connectorProfileIds };
  }

  /** Profile ID of the business profile provisioned for `connector` (undefined if absent). */
  profileId(connector: Connector): string | undefined {
    return this.connectorProfileIds[connector];
  }

  /** Default profile used when a payment body has no profile_id (the Stripe profile). */
  get defaultProfileId(): string {
    return this.connectorProfileIds[connectorEnum.STRIPE] ?? "";
  }
}
