import * as testIds from "../../../../src/Utilities/TestUtils.bs";
import {
  getClientURL,
  createPaymentBody,
  changeObjectKeyValue,
  removeObjectKey,
  connectorEnum,
  connectorProfileIdMapping,
  defaultBillingAddress,
} from "../../support/utils";
import { stripeCards } from "../../support/cards";

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
      connectorProfileIdMapping.get(connectorEnum.STRIPE) ?? "",
    );
    changeObjectKeyValue(createPaymentBody, "billing", defaultBillingAddress);
  });

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

        cy.get("#submit").should("be.visible").click();

        getIframeBody()
          .find(".Error.pt-1", { timeout: 5000 })
          .should("be.visible")
          .and("contain.text", cardNumberEmptyText);
      });
    });
  });

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
          connectorProfileIdMapping.get(connectorEnum.CYBERSOURCE) ?? "",
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

        cy.get("#submit").should("be.visible").click();

        cy.contains("Thanks for your order!", { timeout: 10000 }).should(
          "be.visible",
        );
      });
    });
  });

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

      cy.get("#submit").should("be.visible").click();

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

      cy.get("#submit").should("be.visible").click();

      cy.contains("Thanks for your order!", { timeout: 10000 }).should(
        "be.visible",
      );
    });
  });

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
