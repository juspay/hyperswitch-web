// Locale data table: checks the SDK's locale data against the expected per-locale strings in
// core-a-helpers.ts, without a browser. (locale-i18n.spec.ts checks in a real browser that the
// SDK renders the translated strings, for a handful of locales.)
//
// STOP-GAP until the Vitest unit layer (testing plan phase 2, "locale table test") takes over;
// delete this file once that exists. Browser-free: no `page`, no fixtures that open a browser
// context (plain @playwright/test `test`), so the whole file runs in well under a second.
//
// Each expectation is asserted against the SDK's own locale data, following the same chain the
// SDK uses at runtime:
//
//   LoaderController.setConfigs: locale option ("" -> config.locale, default "auto")
//     -> CardTheme.getLocaleObject(locale)            ("auto" -> navigator.language)
//     -> LocaleStringHelper.mapLocalStringToTypeLocale(locale)   (imported from src/, compiled)
//     -> <Name>Locale.localeStrings                    (the switch in src/CardTheme.res)
//
// The locale modules (src/LocaleStrings/*Locale.bs.js) import react/jsx-runtime and Utils.bs.js,
// whose import graph only resolves under webpack (e.g. `import PackageJson from "/package.json"`).
// Their data is a plain object literal, so they're evaluated here with those two imports stubbed;
// the loader fails loudly if a locale module ever grows another import. The locale -> module map is
// parsed from src/CardTheme.res so it can't drift from the SDK.
//
// Which DOM text each key feeds (so a data match means the browser shows it):
//   cardNumberLabel / validThruText / cvcTextLabel  CommonCardFieldHooks.res, CardFields.res (floating labels)
//   cardNumberEmptyText                             Payment.res (card number error on submit)
//   localeDirection                                 RenderPaymentMethods.res, PaymentMethodsSDK.res (`dir`)
//   billingDetailsText                              DynamicFields.res (billing section header)
import fs from "node:fs";
import path from "node:path";
import { test, expect } from "@playwright/test";
import { REPO_ROOT } from "../../fixtures/env";
// Compiled ReScript (gitignored, produced by `npm run re:build`), like fixtures/test-ids.ts.
import { mapLocalStringToTypeLocale as mapLocale } from "../../../src/LocaleStrings/LocaleStringHelper.bs.js";
import {
  allSupportedLocales,
  billingLocales,
  localeAliases,
  locales,
} from "./core-a-helpers";

type LocaleStrings = Record<string, unknown> & {
  cardNumberLabel: string;
  validThruText: string;
  cvcTextLabel: string;
  cardNumberEmptyText: string;
  billingDetailsText: string;
  localeDirection: string;
};

/** Playwright's default browser locale; what "auto" resolves to in the browser tests. */
const NAVIGATOR_LANGUAGE = "en-US";

// ── Locale enum -> module, parsed from CardTheme.getLocaleObject ─────────────
const cardThemeSrc = fs.readFileSync(
  path.join(REPO_ROOT, "src/CardTheme.res"),
  "utf8",
);
const MODULE_BY_ENUM: Record<string, string> = Object.fromEntries(
  [
    ...cardThemeSrc.matchAll(
      /\|\s*([A-Z_]+)\s*=>\s*import\((\w+)\.localeStrings\)/g,
    ),
  ].map((m) => [m[1], m[2]]),
);
/** getLocaleObject's `catch` fallback. */
const FALLBACK_MODULE = /catch\s*\{\s*\|\s*_\s*=>\s*(\w+)\.localeStrings/.exec(
  cardThemeSrc,
)?.[1];

// ── Locale module loader ─────────────────────────────────────────────────────
const ALLOWED_IMPORTS: Record<string, string> = {
  'import * as JsxRuntime from "react/jsx-runtime";': "JsxRuntime",
  'import * as Utils$OrcaPaymentPage from "../Utilities/Utils.bs.js";':
    "Utils$OrcaPaymentPage",
};
// Only the JSX-returning message functions touch these; the strings under test never do.
const jsxStub = { jsx: () => null, jsxs: () => null, Fragment: "Fragment" };
const utilsStub = { nbsp: "\u00A0" }; // Utils.res: let nbsp = `\u00A0`

const moduleCache = new Map<string, LocaleStrings>();
function loadLocaleModule(moduleName: string): LocaleStrings {
  const cached = moduleCache.get(moduleName);
  if (cached) return cached;
  const file = path.join(REPO_ROOT, "src/LocaleStrings", `${moduleName}.bs.js`);
  const src = fs.readFileSync(file, "utf8");
  const imports = src.match(/^import .*$/gm) ?? [];
  const unknown = imports.filter((i) => !(i in ALLOWED_IMPORTS));
  if (unknown.length)
    throw new Error(
      `${file}: unexpected import(s), extend ALLOWED_IMPORTS:\n${unknown.join("\n")}`,
    );
  const body = src
    .replace(/^import .*$/gm, "")
    .replace(/^export\s*\{[^}]*\}\s*;?/m, "");
  // eslint-disable-next-line @typescript-eslint/no-implied-eval
  const evaluate = new Function(
    "JsxRuntime",
    "Utils$OrcaPaymentPage",
    `${body}\nreturn localeStrings;`,
  );
  const strings = evaluate(jsxStub, utilsStub) as LocaleStrings;
  moduleCache.set(moduleName, strings);
  return strings;
}

/** What the SDK resolves the locale option to: [enum, locale module name]. */
function resolveLocale(localeOption: string): {
  enumValue: string;
  moduleName: string;
} {
  const requested = localeOption === "" ? "auto" : localeOption; // setConfigs: "" -> config.locale ("auto")
  const locale = requested === "auto" ? NAVIGATOR_LANGUAGE : requested; // getLocaleObject
  const enumValue = mapLocale(locale) as string;
  const moduleName = MODULE_BY_ENUM[enumValue];
  if (!moduleName)
    throw new Error(
      `CardTheme.getLocaleObject has no module for ${enumValue} (from "${localeOption}")`,
    );
  return { enumValue, moduleName };
}

/** The localeStrings object the SDK renders with for `localeOption`. */
const stringsFor = (localeOption: string) =>
  loadLocaleModule(resolveLocale(localeOption).moduleName);

// Milliseconds per test: run the file in one worker (in order, tests still independent)
// instead of fanning 157 tiny tests out across every worker.
test.describe.configure({ mode: "default" });

test.describe("Locale / i18n data (browser-less)", () => {
  test("locale module map was parsed from CardTheme.res", () => {
    expect(Object.keys(MODULE_BY_ENUM).length).toBeGreaterThanOrEqual(
      allSupportedLocales.length,
    );
    expect(FALLBACK_MODULE).toBe("EnglishLocale");
  });

  test.describe("Card Field Label Translations", () => {
    for (const {
      code,
      name,
      cardNumberLabel,
      validThruText,
      cvcTextLabel,
    } of locales) {
      test(`should display translated card labels in ${name} (${code})`, () => {
        const s = stringsFor(code);
        expect(s.cardNumberLabel).toBe(cardNumberLabel);
        expect(s.validThruText).toBe(validThruText);
        expect(s.cvcTextLabel).toBe(cvcTextLabel);
      });
    }
  });

  test.describe("Expiry Placeholder Localisation", () => {
    for (const { code, name, validThruText } of locales) {
      // The expiry input being visible is a rendering check: locale-i18n.spec.ts covers it.
      test(`should show expiry floating label "${validThruText}" in ${name} (${code})`, () => {
        expect(stringsFor(code).validThruText).toBe(validThruText);
      });
    }
  });

  test.describe("Error Message Translations", () => {
    for (const { code, name, cardNumberEmptyText } of locales) {
      test(`should display translated empty-card error in ${name} (${code})`, () => {
        expect(stringsFor(code).cardNumberEmptyText).toBe(cardNumberEmptyText);
      });
    }
  });

  test.describe("RTL Layout Support", () => {
    for (const { code, name } of locales.filter((l) => l.direction === "rtl")) {
      test(`should apply RTL direction for ${name} (${code})`, () => {
        expect(stringsFor(code).localeDirection).toBe("rtl");
      });
    }

    for (const { code, name } of locales.filter((l) => l.direction === "ltr")) {
      test(`should apply LTR direction for ${name} (${code})`, () => {
        expect(stringsFor(code).localeDirection).toBe("ltr");
      });
    }
  });

  test.describe("Billing Field Label Translations", () => {
    for (const { code, name, billingDetailsText } of billingLocales) {
      test(`should display translated billing details header in ${name} (${code})`, () => {
        expect(stringsFor(code).billingDetailsText).toBe(billingDetailsText);
      });
    }
  });

  test.describe("Locale Fallback Behaviour", () => {
    test("should fall back to English for an unsupported locale code", () => {
      const { enumValue } = resolveLocale("xx-UNKNOWN");
      expect(enumValue).toBe("EN");
      const s = stringsFor("xx-UNKNOWN");
      expect(s.cardNumberLabel).toBe("Card Number");
      expect(s.validThruText).toBe("Expiry");
      expect(s.cvcTextLabel).toBe("CVC");
    });

    test('should show French card labels for the regional variant "fr-CA"', () => {
      // "fr-CA" is an exact match (FrenchCanadianLocale), which shares the French label.
      expect(stringsFor("fr-CA").cardNumberLabel).toBe("Numéro de carte");
    });

    test("should fall back to English for empty locale string", () => {
      // That the card number input renders with locale "" is a browser check: locale-i18n.spec.ts.
      expect(resolveLocale("").enumValue).toBe("EN");
      expect(stringsFor("").cardNumberLabel).toBe("Card Number");
    });
  });

  test.describe("Locale Code Aliases for Newly Added Locales", () => {
    for (const { requested, resolvesTo, cardNumberLabel } of localeAliases) {
      test(`should resolve locale "${requested}" to "${resolvesTo}"`, () => {
        expect(resolveLocale(requested).enumValue).toBe(
          resolveLocale(resolvesTo).enumValue,
        );
        expect(stringsFor(requested).cardNumberLabel).toBe(cardNumberLabel);
      });
    }
  });

  // Paying in a non-English or RTL locale is a browser flow with no data equivalent:
  // locale-i18n.spec.ts pays in French and in Arabic.

  test.describe("All Supported Locales", () => {
    for (const code of allSupportedLocales) {
      test(`should resolve locale "${code}" to its own locale module`, () => {
        // Resolves to its own locale module (not the silent English fallback) and that module
        // loads with the strings the card form needs.
        const { enumValue, moduleName } = resolveLocale(code);
        if (!code.startsWith("en")) expect(enumValue).not.toBe("EN");
        expect(moduleName).toBe(MODULE_BY_ENUM[enumValue]);
        const s = loadLocaleModule(moduleName);
        for (const key of [
          "cardNumberLabel",
          "validThruText",
          "cvcTextLabel",
          "cardNumberEmptyText",
        ] as const) {
          expect(
            typeof s[key] === "string" && s[key].length > 0,
            `${moduleName}.${key}`,
          ).toBe(true);
        }
      });
    }
  });
});
