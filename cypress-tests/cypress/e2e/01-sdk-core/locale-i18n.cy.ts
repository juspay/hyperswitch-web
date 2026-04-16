/**
 * Locale / i18n Tests
 * Tests for locale-specific rendering of the payment SDK.
 *
 * Covers:
 *  - Major LTR locales (English, French, German, Spanish, Japanese, Chinese)
 *  - RTL locales (Arabic, Hebrew)
 *  - Locale fallback behaviour (unsupported locale -> English)
 *  - Default "auto" locale behaviour
 *  - Translated card labels, error messages, billing field labels
 *  - Locale-specific expiry placeholder
 *  - Successful payment in non-English locale
 *
 * Prerequisites:
 *  - Demo app (localhost:9060) must accept `&locale=<code>` query parameter.
 *    This is wired via `Payment.js` reading `getQueryParam("locale")` and
 *    passing it into `hyperOptionsV1` / `hyperOptionsV2`.
 *  - `getClientURL` in `cypress/support/utils.ts` supports optional `locale`
 *    third argument.
 */
import * as testIds from "../../../../src/Utilities/TestUtils.bs";
import {
  getClientURL,
  createPaymentBody,
  changeObjectKeyValue,
  removeObjectKey,
  connectorEnum,
  connectorProfileIdMapping,
} from "../../support/utils";
import { stripeCards } from "../../support/cards";

/* ------------------------------------------------------------------ */
/*  Lookup tables for expected translated strings per locale           */
/* ------------------------------------------------------------------ */

interface LocaleExpectations {
  code: string;
  name: string;
  direction: "ltr" | "rtl";
  cardNumberLabel: string;
  validThruText: string;
  cvcTextLabel: string;
  expiryPlaceholder: string;
  cardNumberEmptyText: string;
}

const locales: LocaleExpectations[] = [
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
    cvcTextLabel: "Code CVC",
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
];

/* ------------------------------------------------------------------ */
/*  Helper: create payment intent and visit with a specific locale     */
/* ------------------------------------------------------------------ */

const setupWithLocale = (
  locale: string,
  secretKey: string,
  publishableKey: string,
) => {
  changeObjectKeyValue(
    createPaymentBody,
    "customer_id",
    `locale_test_${locale}`,
  );
  changeObjectKeyValue(
    createPaymentBody,
    "authentication_type",
    "no_three_ds",
  );
  changeObjectKeyValue(createPaymentBody, "capture_method", "automatic");
  changeObjectKeyValue(createPaymentBody, "currency", "USD");

  cy.createPaymentIntent(secretKey, createPaymentBody).then(() => {
    cy.getGlobalState("clientSecret").then((clientSecret) => {
      cy.visit(getClientURL(clientSecret, publishableKey, locale));
    });
  });

  cy.waitForSDKReady();
};

/* ================================================================== */
/*  TEST SUITES                                                        */
/* ================================================================== */

describe("Locale / i18n Tests", () => {
  const publishableKey = Cypress.env("HYPERSWITCH_PUBLISHABLE_KEY");
  const secretKey = Cypress.env("HYPERSWITCH_SECRET_KEY");
  let getIframeBody: () => Cypress.Chainable<JQuery<HTMLBodyElement>>;
  const iframeSelector =
    "#orca-payment-element-iframeRef-orca-elements-payment-element-payment-element";

  beforeEach(() => {
    getIframeBody = () => cy.iframe(iframeSelector);
    changeObjectKeyValue(
      createPaymentBody,
      "profile_id",
      connectorProfileIdMapping.get(connectorEnum.STRIPE),
    );
    changeObjectKeyValue(createPaymentBody, "billing", {
      email: "hyperswitch_sdk_demo_id@gmail.com",
      address: {
        line1: "1467",
        line2: "Harrison Street",
        line3: "Harrison Street",
        city: "San Fransico",
        state: "California",
        zip: "94122",
        country: "US",
        first_name: "joseph",
        last_name: "Doe",
      },
      phone: {
        number: "8056594427",
        country_code: "+91",
      },
    });
  });

  /* ---------------------------------------------------------------- */
  /*  1. Card label translations for every major locale                */
  /* ---------------------------------------------------------------- */

  describe("Card Field Label Translations", () => {
    locales.forEach(
      ({
        code,
        name,
        cardNumberLabel,
        validThruText,
        cvcTextLabel,
      }) => {
        it(`should display translated card labels in ${name} (${code})`, () => {
          setupWithLocale(code, secretKey, publishableKey);

          getIframeBody().contains(cardNumberLabel).should("be.visible");

          getIframeBody().contains(validThruText).should("be.visible");

          getIframeBody().contains(cvcTextLabel).should("be.visible");
        });
      },
    );
  });

  /* ---------------------------------------------------------------- */
  /*  2. Expiry placeholder locale-specific format                     */
  /* ---------------------------------------------------------------- */

  describe("Expiry Placeholder Localisation", () => {
    locales.forEach(({ code, name, validThruText }) => {
      it(`should show expiry floating label "${validThruText}" in ${name} (${code})`, () => {
        setupWithLocale(code, secretKey, publishableKey);

        getIframeBody()
          .find(`[data-testid=${testIds.expiryInputTestId}]`)
          .should("be.visible");

        getIframeBody().contains(validThruText).should("be.visible");
      });
    });
  });

  /* ---------------------------------------------------------------- */
  /*  3. Error message translations                                    */
  /* ---------------------------------------------------------------- */

  describe("Error Message Translations", () => {
    locales.forEach(({ code, name, cardNumberEmptyText }) => {
      it(`should display translated empty-card error in ${name} (${code})`, () => {
        setupWithLocale(code, secretKey, publishableKey);

        getIframeBody()
          .find(`[data-testid=${testIds.expiryInputTestId}]`)
          .safeType("1230");

        getIframeBody()
          .find(`[data-testid=${testIds.cardCVVInputTestId}]`)
          .safeType("123");

        cy.get("#submit").click();

        getIframeBody()
          .find(".Error.pt-1", { timeout: 5000 })
          .should("be.visible")
          .and("contain.text", cardNumberEmptyText);
      });
    });
  });

  /* ---------------------------------------------------------------- */
  /*  4. RTL layout for Arabic and Hebrew                              */
  /* ---------------------------------------------------------------- */

  describe("RTL Layout Support", () => {
    const rtlLocales = locales.filter((l) => l.direction === "rtl");

    rtlLocales.forEach(({ code, name }) => {
      it(`should apply RTL direction for ${name} (${code})`, () => {
        setupWithLocale(code, secretKey, publishableKey);

        getIframeBody()
          .find("[dir]", { timeout: 10000 })
          .first()
          .should("have.attr", "dir", "rtl");
      });
    });

    const ltrLocales = locales.filter((l) => l.direction === "ltr");

    ltrLocales.forEach(({ code, name }) => {
      it(`should apply LTR direction for ${name} (${code})`, () => {
        setupWithLocale(code, secretKey, publishableKey);

        getIframeBody()
          .find("[dir]", { timeout: 10000 })
          .first()
          .should("have.attr", "dir", "ltr");
      });
    });
  });

  /* ---------------------------------------------------------------- */
  /*  5. Dynamic billing field label translations                      */
  /* ---------------------------------------------------------------- */

  describe("Billing Field Label Translations", () => {
    const billingLocales: Array<{
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
      {
        code: "de",
        name: "German",
        billingDetailsText: "Rechnungsdetails",
      },
      {
        code: "es",
        name: "Spanish",
        billingDetailsText: "Detalles de facturación",
      },
      { code: "ja", name: "Japanese", billingDetailsText: "支払明細" },
      { code: "zh", name: "Chinese", billingDetailsText: "账单详情" },
      {
        code: "ar",
        name: "Arabic",
        billingDetailsText: "تفاصيل الفاتورة",
      },
      { code: "he", name: "Hebrew", billingDetailsText: "פרטי תשלום" },
    ];

    billingLocales.forEach(({ code, name, billingDetailsText }) => {
      it(`should display translated billing details header in ${name} (${code})`, () => {
        changeObjectKeyValue(
          createPaymentBody,
          "profile_id",
          connectorProfileIdMapping.get(connectorEnum.CYBERSOURCE),
        );
        changeObjectKeyValue(
          createPaymentBody,
          "customer_id",
          `locale_billing_${code}`,
        );
        changeObjectKeyValue(
          createPaymentBody,
          "authentication_type",
          "no_three_ds",
        );
        removeObjectKey(createPaymentBody, "billing");

        cy.createPaymentIntent(secretKey, createPaymentBody).then(() => {
          cy.getGlobalState("clientSecret").then((clientSecret) => {
            cy.visit(getClientURL(clientSecret, publishableKey, code));
          });
        });

        cy.waitForSDKReady();

        getIframeBody()
          .contains(billingDetailsText, { timeout: 10000 })
          .should("be.visible");
      });
    });
  });

  /* ---------------------------------------------------------------- */
  /*  6. Fallback behaviour for unsupported locale                     */
  /* ---------------------------------------------------------------- */

  describe("Locale Fallback Behaviour", () => {
    it("should fall back to English for an unsupported locale code", () => {
      setupWithLocale("xx-UNKNOWN", secretKey, publishableKey);

      getIframeBody().contains("Card Number").should("be.visible");
      getIframeBody().contains("Expiry").should("be.visible");
      getIframeBody().contains("CVC").should("be.visible");
    });

    it("should fall back to base language when regional variant is unsupported", () => {
      setupWithLocale("fr-CA", secretKey, publishableKey);

      getIframeBody().contains("Numéro de carte").should("be.visible");
    });

    it("should fall back to English for empty locale string", () => {
      changeObjectKeyValue(
        createPaymentBody,
        "customer_id",
        "locale_empty_test",
      );
      changeObjectKeyValue(
        createPaymentBody,
        "authentication_type",
        "no_three_ds",
      );

      cy.createPaymentIntent(secretKey, createPaymentBody).then(() => {
        cy.getGlobalState("clientSecret").then((clientSecret) => {
          cy.visit(getClientURL(clientSecret, publishableKey));
        });
      });

      cy.waitForSDKReady();

      getIframeBody()
        .find(`[data-testid=${testIds.cardNoInputTestId}]`)
        .should("be.visible");
    });
  });

  /* ---------------------------------------------------------------- */
  /*  7. Successful payment in non-English locales                     */
  /* ---------------------------------------------------------------- */

  describe("Payment Completion in Non-English Locales", () => {
    const paymentLocales = [
      { code: "fr", name: "French" },
      { code: "de", name: "German" },
      { code: "es", name: "Spanish" },
      { code: "ja", name: "Japanese" },
    ];

    paymentLocales.forEach(({ code, name }) => {
      it(`should complete a card payment successfully in ${name} (${code})`, () => {
        setupWithLocale(code, secretKey, publishableKey);

        const { cardNo, card_exp_month, card_exp_year, cvc } =
          stripeCards.successCard;

        cy.enterCardDetails({
          cardNo,
          card_exp_month,
          card_exp_year,
          cvc,
        });

        cy.get("#submit").click();

        cy.contains("Thanks for your order!", { timeout: 10000 }).should(
          "be.visible",
        );
      });
    });
  });

  /* ---------------------------------------------------------------- */
  /*  8. RTL payment flow (Arabic)                                     */
  /* ---------------------------------------------------------------- */

  describe("RTL Payment Flow", () => {
    it("should complete a card payment successfully in Arabic (RTL)", () => {
      setupWithLocale("ar", secretKey, publishableKey);

      const { cardNo, card_exp_month, card_exp_year, cvc } =
        stripeCards.successCard;

      cy.enterCardDetails({
        cardNo,
        card_exp_month,
        card_exp_year,
        cvc,
      });

      cy.get("#submit").click();

      cy.contains("Thanks for your order!", { timeout: 10000 }).should(
        "be.visible",
      );
    });

    it("should complete a card payment successfully in Hebrew (RTL)", () => {
      setupWithLocale("he", secretKey, publishableKey);

      const { cardNo, card_exp_month, card_exp_year, cvc } =
        stripeCards.successCard;

      cy.enterCardDetails({
        cardNo,
        card_exp_month,
        card_exp_year,
        cvc,
      });

      cy.get("#submit").click();

      cy.contains("Thanks for your order!", { timeout: 10000 }).should(
        "be.visible",
      );
    });
  });

  /* ---------------------------------------------------------------- */
  /*  9. All 18 supported locales – SDK loads without error            */
  /* ---------------------------------------------------------------- */

  describe("SDK Loads for All Supported Locales", () => {
    const allLocales = [
      "en",
      "en-gb",
      "fr",
      "fr-be",
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
    ];

    allLocales.forEach((code) => {
      it(`should load SDK without errors for locale "${code}"`, () => {
        setupWithLocale(code, secretKey, publishableKey);

        cy.get(iframeSelector).should("be.visible");

        getIframeBody()
          .find(`[data-testid=${testIds.cardNoInputTestId}]`)
          .should("be.visible");

        cy.get("#submit").should("be.visible");
      });
    });
  });
});
