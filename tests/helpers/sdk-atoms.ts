import type { ExtractAtomValue, PrimitiveAtom } from "jotai";
import * as Atoms from "../../src/Utilities/JotaiAtoms.bs.js";
import { paymentManagementList } from "../../src/Utilities/JotaiAtomsV2.bs.js";
import { paymentMethodListValue, sdkConfigsValue } from "../../src/Utilities/PaymentUtils.bs.js";

// These named adapters preserve the real atom identity and correct only fields
// whose generated-JS defaults lose their optional/variant types. Other fields
// retain their inferred types; this is a test boundary, not public SDK bindings.
type Keys = ExtractAtomValue<typeof Atoms.keys>;
export const sdkKeysAtom = Atoms.keys as unknown as PrimitiveAtom<
  Omit<Keys, "clientSecret" | "sdkAuthorization" | "pmSessionId"> & {
    clientSecret?: string;
    sdkAuthorization?: string;
    pmSessionId?: string;
  }
>;

type Options = ExtractAtomValue<typeof Atoms.optionAtom>;
export const sdkOptionsAtom = Atoms.optionAtom as unknown as PrimitiveAtom<
  Omit<Options, "subscriptionEvents" | "customerPaymentMethods"> & {
    subscriptionEvents?: string[];
    customerPaymentMethods: string | { TAG: string; _0: unknown };
  }
>;

// The loader defaults to a string sentinel; fetched payloads are object variants.
export type FixtureLoadable = string | { TAG: string; _0: Record<string, unknown> };
export const sdkPaymentMethodListAtom = Atoms.paymentMethodList as unknown as PrimitiveAtom<FixtureLoadable>;
export const sdkSessionsAtom = Atoms.sessions as unknown as PrimitiveAtom<FixtureLoadable>;
export const sdkPaymentManagementListAtom = paymentManagementList as unknown as PrimitiveAtom<FixtureLoadable>;

type MethodList = ExtractAtomValue<typeof paymentMethodListValue>;
export const sdkMethodListValueAtom = paymentMethodListValue as unknown as PrimitiveAtom<
  Omit<MethodList, "sdk_next_action"> & { sdk_next_action?: string }
>;

type Config = ExtractAtomValue<typeof sdkConfigsValue>;
export const sdkConfigsAtom = sdkConfigsValue as unknown as PrimitiveAtom<
  Omit<Config, "account_config"> & { account_config?: Record<string, unknown> }
>;
