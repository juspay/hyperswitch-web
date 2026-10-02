// Helpers for the 01-sdk-core theme, layout and locale specs only. Cross-group
// helpers live in fixtures/helpers.ts.
import type { Locator } from "@playwright/test";
import {
  expect,
  stripeCards,
  expectConfirmedWith,
  type Hermetic,
  type Sdk,
} from "../../fixtures";

/** Waits until the element is enabled and visible, then force-clicks it. */
export async function safeClick(el: Locator): Promise<void> {
  await expect(el).toBeEnabled();
  await expect(el).toBeVisible();
  await el.click({ force: true });
}

/**
 * Waits for the first match to render, then returns how many there are. Lets a spec branch on
 * the rendered count (e.g. "if there is more than one tab") without racing the render.
 */
export async function countRendered(items: Locator): Promise<number> {
  await expect(items.first()).toBeAttached();
  return items.count();
}

/** Computed style property of the element. */
export async function cssOf(el: Locator, prop: string): Promise<string> {
  await expect(el).toBeAttached();
  return el.evaluate(
    (node, p) => getComputedStyle(node).getPropertyValue(p),
    prop,
  );
}

/**
 * Enters the Stripe success card, clicks the visible `#submit`, then expects
 * "Thanks for your order!". In hermetic mode also checks the typed card reached /confirm,
 * so the synthetic success can't hide a broken submit.
 */
export async function payWithSuccessCard(
  sdk: Sdk,
  hermetic: Hermetic,
): Promise<void> {
  const card = stripeCards.successCard;
  await sdk.enterCardDetails(card);
  await expect(sdk.submitButton).toBeVisible();
  await sdk.submit();
  await expect(sdk.page.getByText("Thanks for your order!")).toBeVisible({
    timeout: 30_000,
  });
  await expectConfirmedWith(hermetic, card.cardNo);
}

// ─────────────────────────────────────────────────────────────────────────────
// Locale data (locale-i18n.spec.ts + locale-strings.spec.ts)
//
// Expected per-locale strings. locale-strings.spec.ts checks every row against the SDK's
// locale data; locale-i18n.spec.ts uses a few of them for the in-browser checks.
// ─────────────────────────────────────────────────────────────────────────────

export interface LocaleExpectations {
  code: string;
  name: string;
  direction: "ltr" | "rtl";
  cardNumberLabel: string;
  validThruText: string;
  cvcTextLabel: string;
  expiryPlaceholder: string;
  cardNumberEmptyText: string;
}

export const locales: LocaleExpectations[] = [
  {
    code: "en",
    name: "English",
    direction: "ltr",
    cardNumberLabel: "Card Number",
    validThruText: "Expiry",
    cvcTextLabel: "CVC",
    expiryPlaceholder: "MM / YY",
    cardNumberEmptyText: "Card Number cannot be empty",
  },
  {
    code: "fr",
    name: "French",
    direction: "ltr",
    cardNumberLabel: "Numéro de carte",
    validThruText: "Expiration",
    cvcTextLabel: "CVC",
    expiryPlaceholder: "MM / AA",
    cardNumberEmptyText: "Le numéro de carte ne peut pas être vide",
  },
  {
    code: "de",
    name: "German",
    direction: "ltr",
    cardNumberLabel: "Kartennummer",
    validThruText: "Ablauf",
    cvcTextLabel: "CVC",
    expiryPlaceholder: "MM / JJ",
    cardNumberEmptyText: "Die Kartennummer darf nicht leer sein",
  },
  {
    code: "es",
    name: "Spanish",
    direction: "ltr",
    cardNumberLabel: "Número de tarjeta",
    validThruText: "Vencimiento",
    cvcTextLabel: "CVV",
    expiryPlaceholder: "MM / AA",
    cardNumberEmptyText: "El número de la tarjeta no puede estar vacío",
  },
  {
    code: "ja",
    name: "Japanese",
    direction: "ltr",
    cardNumberLabel: "カード番号",
    validThruText: "を通じて有効",
    cvcTextLabel: "セキュリティコード",
    expiryPlaceholder: "MM / YY",
    cardNumberEmptyText: "カード番号を空にすることはできません",
  },
  {
    code: "zh",
    name: "Chinese (Simplified)",
    direction: "ltr",
    cardNumberLabel: "卡號",
    validThruText: "有效期",
    cvcTextLabel: "安全碼",
    expiryPlaceholder: "MM / YY",
    cardNumberEmptyText: "卡号不能为空",
  },
  {
    code: "ar",
    name: "Arabic (RTL)",
    direction: "rtl",
    cardNumberLabel: "رقم البطاقة",
    validThruText: "صالحة من خلال",
    cvcTextLabel: "رمز الحماية",
    expiryPlaceholder: "MM / YY",
    cardNumberEmptyText: "لا يمكن أن يكون رقم البطاقة فارغاً",
  },
  {
    code: "he",
    name: "Hebrew (RTL)",
    direction: "rtl",
    cardNumberLabel: "מספר כרטיס",
    validThruText: "תוקף",
    cvcTextLabel: "קוד בגב הכרטיס",
    expiryPlaceholder: "MM / YY",
    cardNumberEmptyText: "מספר הכרטיס אינו יכול להיות ריק",
  },
  {
    code: "lt",
    name: "Lithuanian",
    direction: "ltr",
    cardNumberLabel: "Kortelės numeris",
    validThruText: "Galiojimo pabaiga",
    cvcTextLabel: "CVC",
    expiryPlaceholder: "MM / YY",
    cardNumberEmptyText: "Kortelės numeris negali būti tuščias",
  },
  {
    code: "cs",
    name: "Czech",
    direction: "ltr",
    cardNumberLabel: "Číslo karty",
    validThruText: "Datum ukončení platnosti",
    cvcTextLabel: "CVC",
    expiryPlaceholder: "MM / RR",
    cardNumberEmptyText: "Číslo karty nesmí být prázdné",
  },
  {
    code: "sk",
    name: "Slovak",
    direction: "ltr",
    cardNumberLabel: "Číslo karty",
    validThruText: "Ukončenie platnosti",
    cvcTextLabel: "CVC",
    expiryPlaceholder: "MM / RR",
    cardNumberEmptyText: "Číslo karty nemôže byť prázdne",
  },
  {
    code: "is",
    name: "Icelandic",
    direction: "ltr",
    cardNumberLabel: "Kortanúmer",
    validThruText: "Gildistími",
    cvcTextLabel: "CVC",
    expiryPlaceholder: "MM / ÁÁ",
    cardNumberEmptyText: "Kortanúmer má ekki vera autt.",
  },
  {
    code: "cy",
    name: "Welsh",
    direction: "ltr",
    cardNumberLabel: "Rhif y Cerdyn",
    validThruText: "Daw i ben",
    cvcTextLabel: "CVC",
    expiryPlaceholder: "MM / BB",
    cardNumberEmptyText: "Ni all Rhif y Cerdyn fod yn wag",
  },
  {
    code: "el",
    name: "Greek",
    direction: "ltr",
    cardNumberLabel: "Αριθμός Κάρτας",
    validThruText: "Λήξη",
    cvcTextLabel: "CVC",
    expiryPlaceholder: "ΜΜ / ΕΕ",
    cardNumberEmptyText: "Ο αριθμός κάρτας δεν μπορεί να είναι κενός",
  },
  {
    code: "et",
    name: "Estonian",
    direction: "ltr",
    cardNumberLabel: "Kaardi number",
    validThruText: "Kehtivus",
    cvcTextLabel: "CVC",
    expiryPlaceholder: "KK / AA",
    cardNumberEmptyText: "Kaardi numbri väli peab olema täidetud",
  },
  {
    code: "fi",
    name: "Finnish",
    direction: "ltr",
    cardNumberLabel: "Kortin numero",
    validThruText: "Voimassaolo",
    cvcTextLabel: "CVC",
    expiryPlaceholder: "KK / VV",
    cardNumberEmptyText: "Kortin numero ei voi olla tyhjä",
  },
  {
    code: "nb",
    name: "Norwegian",
    direction: "ltr",
    cardNumberLabel: "Kortnummer",
    validThruText: "Utløp",
    cvcTextLabel: "CVC",
    expiryPlaceholder: "MM / ÅÅ",
    cardNumberEmptyText: "Kortnummer kan ikke stå tomt",
  },
  {
    code: "bs",
    name: "Bosnian",
    direction: "ltr",
    cardNumberLabel: "Broj kartice",
    validThruText: "Istek",
    cvcTextLabel: "CVC",
    expiryPlaceholder: "MM / GG",
    cardNumberEmptyText: "Polje za broj kartice ne može biti prazno",
  },
  {
    code: "da",
    name: "Danish",
    direction: "ltr",
    cardNumberLabel: "Kortnummer",
    validThruText: "Udløbsdato",
    cvcTextLabel: "CVC",
    expiryPlaceholder: "MM / ÅÅ",
    cardNumberEmptyText: "Kortnummeret kan ikke være tomt",
  },
  {
    code: "ms",
    name: "Malay",
    direction: "ltr",
    cardNumberLabel: "Nombor Kad",
    validThruText: "Luput Pada",
    cvcTextLabel: "CVC",
    expiryPlaceholder: "BB / TT",
    cardNumberEmptyText: "Nombor Kad tidak boleh kosong",
  },
  {
    code: "tr-CY",
    name: "Turkish (Cyprus)",
    direction: "ltr",
    cardNumberLabel: "Kart Numarası",
    validThruText: "Son kullanma tarihi",
    cvcTextLabel: "CVC",
    expiryPlaceholder: "AA / YY",
    cardNumberEmptyText: "Kart Numarası boş olamaz",
  },
];

export const localeByCode = (code: string): LocaleExpectations => {
  const l = locales.find((x) => x.code === code);
  if (!l) throw new Error(`no locale expectations for ${code}`);
  return l;
};

/** Expected billing-section header (billingDetailsText) per locale. */
export const billingLocales: Array<{
  code: string;
  name: string;
  billingDetailsText: string;
}> = [
  { code: "en", name: "English", billingDetailsText: "Billing Details" },
  {
    code: "fr",
    name: "French",
    billingDetailsText: "Détails de la facturation",
  },
  { code: "de", name: "German", billingDetailsText: "Rechnungsdetails" },
  {
    code: "es",
    name: "Spanish",
    billingDetailsText: "Detalles de facturación",
  },
  { code: "ja", name: "Japanese", billingDetailsText: "支払明細" },
  { code: "zh", name: "Chinese", billingDetailsText: "账单详情" },
  { code: "ar", name: "Arabic", billingDetailsText: "تفاصيل الفاتورة" },
  { code: "he", name: "Hebrew", billingDetailsText: "פרטי תשלום" },
  {
    code: "lt",
    name: "Lithuanian",
    billingDetailsText: "Atsiskaitymo informacija",
  },
  { code: "cs", name: "Czech", billingDetailsText: "Fakturační údaje" },
  { code: "sk", name: "Slovak", billingDetailsText: "Fakturačné údaje" },
  { code: "is", name: "Icelandic", billingDetailsText: "Reikningsupplýsingar" },
  { code: "cy", name: "Welsh", billingDetailsText: "Manylion Bilio" },
  { code: "el", name: "Greek", billingDetailsText: "Λεπτομέρειες χρέωσης" },
  { code: "et", name: "Estonian", billingDetailsText: "Arvelduse üksikasjad" },
  { code: "fi", name: "Finnish", billingDetailsText: "Laskutustiedot" },
  {
    code: "nb",
    name: "Norwegian",
    billingDetailsText: "Faktureringsopplysninger",
  },
  { code: "bs", name: "Bosnian", billingDetailsText: "Detalji naplate" },
  { code: "da", name: "Danish", billingDetailsText: "Faktureringsdetaljer" },
  { code: "ms", name: "Malay", billingDetailsText: "Butiran Pengebilan" },
  {
    code: "tr-CY",
    name: "Turkish (Cyprus)",
    billingDetailsText: "Fatura Detayları",
  },
];

/**
 * Locale codes that are aliases or regional variants. LocaleStringHelper resolves these codes
 * onto the newly added locale files: "no"/"nn" are aliases for Norwegian Bokmal, plain "tr"
 * resolves to tr-CY, and any regional variant falls back to its base language.
 */
export const localeAliases: Array<{
  requested: string;
  resolvesTo: string;
  cardNumberLabel: string;
}> = [
  { requested: "no", resolvesTo: "nb", cardNumberLabel: "Kortnummer" },
  { requested: "nn", resolvesTo: "nb", cardNumberLabel: "Kortnummer" },
  { requested: "nb-NO", resolvesTo: "nb", cardNumberLabel: "Kortnummer" },
  { requested: "tr", resolvesTo: "tr-CY", cardNumberLabel: "Kart Numarası" },
  { requested: "tr-TR", resolvesTo: "tr-CY", cardNumberLabel: "Kart Numarası" },
  { requested: "cs-CZ", resolvesTo: "cs", cardNumberLabel: "Číslo karty" },
  { requested: "sk-SK", resolvesTo: "sk", cardNumberLabel: "Číslo karty" },
  { requested: "lt-LT", resolvesTo: "lt", cardNumberLabel: "Kortelės numeris" },
  { requested: "is-IS", resolvesTo: "is", cardNumberLabel: "Kortanúmer" },
  { requested: "cy-GB", resolvesTo: "cy", cardNumberLabel: "Rhif y Cerdyn" },
  { requested: "el-GR", resolvesTo: "el", cardNumberLabel: "Αριθμός Κάρτας" },
  { requested: "et-EE", resolvesTo: "et", cardNumberLabel: "Kaardi number" },
  { requested: "fi-FI", resolvesTo: "fi", cardNumberLabel: "Kortin numero" },
  { requested: "bs-BA", resolvesTo: "bs", cardNumberLabel: "Broj kartice" },
  { requested: "da-DK", resolvesTo: "da", cardNumberLabel: "Kortnummer" },
  { requested: "ms-MY", resolvesTo: "ms", cardNumberLabel: "Nombor Kad" },
];

/** Every locale code the SDK advertises as supported; each must resolve to locale data. */
export const allSupportedLocales = [
  "en",
  "en-gb",
  "fr",
  "fr-be",
  "fr-ca",
  "de",
  "es",
  "ca",
  "pt",
  "it",
  "pl",
  "nl",
  "sv",
  "ru",
  "ja",
  "zh",
  "zh-hant",
  "ar",
  "he",
  "da",
  "lt",
  "cs",
  "sk",
  "is",
  "cy",
  "el",
  "et",
  "fi",
  "nb",
  "bs",
  "ms",
  "tr-cy",
];
