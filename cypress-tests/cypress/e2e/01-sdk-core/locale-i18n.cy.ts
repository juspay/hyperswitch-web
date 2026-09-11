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
  changeObjectKeyValue(createPaymentBody, "authentication_type", "no_three_ds");
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
  let publishableKey: string;
  let secretKey: string;
  let getIframeBody: () => Cypress.Chainable<JQuery<HTMLBodyElement>>;
  const iframeSelector =
    "#orca-payment-element-iframeRef-orca-elements-payment-element-payment-element";

  beforeEach(() => {
    publishableKey = Cypress.env("HYPERSWITCH_PUBLISHABLE_KEY");
    secretKey = Cypress.env("HYPERSWITCH_SECRET_KEY");
    getIframeBody = () => cy.paymentElementBody();
    changeObjectKeyValue(
      createPaymentBody,
      "profile_id",
      connectorProfileIdMapping.get(connectorEnum.STRIPE),
    );
    changeObjectKeyValue(
      createPaymentBody,
      "email",
      "hyperswitch_sdk_demo_id@gmail.com",
    );
    changeObjectKeyValue(createPaymentBody, "billing", defaultBillingAddress);
  });

  describe("Card Field Label Translations", () => {
    locales.forEach(
      ({ code, name, cardNumberLabel, validThruText, cvcTextLabel }) => {
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

        // NOTE: the localised `expiryPlaceholder` is intentionally NOT asserted
        // here. PaymentInputField renders the placeholder attribute only when
        // appearance.labels === "above"; under the default floating-label
        // appearance it is an empty string and `validThruText` is the visible
        // localised text.
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
      {
        code: "lt",
        name: "Lithuanian",
        billingDetailsText: "Atsiskaitymo informacija",
      },
      { code: "cs", name: "Czech", billingDetailsText: "Fakturační údaje" },
      { code: "sk", name: "Slovak", billingDetailsText: "Fakturačné údaje" },
      {
        code: "is",
        name: "Icelandic",
        billingDetailsText: "Reikningsupplýsingar",
      },
      { code: "cy", name: "Welsh", billingDetailsText: "Manylion Bilio" },
      { code: "el", name: "Greek", billingDetailsText: "Λεπτομέρειες χρέωσης" },
      {
        code: "et",
        name: "Estonian",
        billingDetailsText: "Arvelduse üksikasjad",
      },
      { code: "fi", name: "Finnish", billingDetailsText: "Laskutustiedot" },
      {
        code: "nb",
        name: "Norwegian",
        billingDetailsText: "Faktureringsopplysninger",
      },
      { code: "bs", name: "Bosnian", billingDetailsText: "Detalji naplate" },
      {
        code: "da",
        name: "Danish",
        billingDetailsText: "Faktureringsdetaljer",
      },
      { code: "ms", name: "Malay", billingDetailsText: "Butiran Pengebilan" },
      {
        code: "tr-CY",
        name: "Turkish (Cyprus)",
        billingDetailsText: "Fatura Detayları",
      },
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
        // Cybersource returns the billing fields through required_fields only
        // when the payment intent does not already provide the contact data.
        removeObjectKey(createPaymentBody, "email");

        cy.createPaymentIntent(secretKey, createPaymentBody).then(() => {
          cy.getGlobalState("clientSecret").then((clientSecret) => {
            cy.visit(getClientURL(clientSecret, publishableKey, code));
          });
        });

        cy.waitForSDKReady();

        // Billing fields remain owned by the outer Payment Element iframe.
        cy.iframe(iframeSelector)
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

  describe("Locale Code Aliases for Newly Added Locales", () => {
    // LocaleStringHelper resolves these codes onto the newly added locale files:
    // "no"/"nn" are aliases for Norwegian Bokmal, plain "tr" resolves to tr-CY,
    // and any regional variant falls back to its base language.
    const aliases: Array<{
      requested: string;
      resolvesTo: string;
      cardNumberLabel: string;
    }> = [
      { requested: "no", resolvesTo: "nb", cardNumberLabel: "Kortnummer" },
      { requested: "nn", resolvesTo: "nb", cardNumberLabel: "Kortnummer" },
      { requested: "nb-NO", resolvesTo: "nb", cardNumberLabel: "Kortnummer" },
      {
        requested: "tr",
        resolvesTo: "tr-CY",
        cardNumberLabel: "Kart Numarası",
      },
      {
        requested: "tr-TR",
        resolvesTo: "tr-CY",
        cardNumberLabel: "Kart Numarası",
      },
      { requested: "cs-CZ", resolvesTo: "cs", cardNumberLabel: "Číslo karty" },
      { requested: "sk-SK", resolvesTo: "sk", cardNumberLabel: "Číslo karty" },
      {
        requested: "lt-LT",
        resolvesTo: "lt",
        cardNumberLabel: "Kortelės numeris",
      },
      { requested: "is-IS", resolvesTo: "is", cardNumberLabel: "Kortanúmer" },
      {
        requested: "cy-GB",
        resolvesTo: "cy",
        cardNumberLabel: "Rhif y Cerdyn",
      },
      {
        requested: "el-GR",
        resolvesTo: "el",
        cardNumberLabel: "Αριθμός Κάρτας",
      },
      {
        requested: "et-EE",
        resolvesTo: "et",
        cardNumberLabel: "Kaardi number",
      },
      {
        requested: "fi-FI",
        resolvesTo: "fi",
        cardNumberLabel: "Kortin numero",
      },
      { requested: "bs-BA", resolvesTo: "bs", cardNumberLabel: "Broj kartice" },
      { requested: "da-DK", resolvesTo: "da", cardNumberLabel: "Kortnummer" },
      { requested: "ms-MY", resolvesTo: "ms", cardNumberLabel: "Nombor Kad" },
    ];

    aliases.forEach(({ requested, resolvesTo, cardNumberLabel }) => {
      it(`should resolve locale "${requested}" to "${resolvesTo}"`, () => {
        setupWithLocale(requested, secretKey, publishableKey);

        getIframeBody().contains(cardNumberLabel).should("be.visible");
      });
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
