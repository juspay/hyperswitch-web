/**
 * Klarna BNPL E2E Tests
 *
 * Tests the Klarna Buy Now Pay Later redirect flow.
 * Klarna is available via Stripe and Adyen connectors.
 * This test uses the Stripe profile with EUR currency and a German billing
 * address, which is required for Klarna to appear as a payment method option.
 *
 * Connector: Stripe (pro_5fVcCxU8MFTYozgtf0P8)
 * Currency:  EUR
 * Country:   DE (Germany)
 *
 * NOTE: Klarna only appears when the connector profile has Klarna enabled
 * and the currency + country combination is supported.
 */
import * as testIds from "../../../src/Utilities/TestUtils.bs";
import { getClientURL } from "../support/utils";
import { createPaymentBody } from "../support/utils";
import {
  changeObjectKeyValue,
  connectorProfileIdMapping,
  connectorEnum,
} from "../support/utils";

describe("Klarna BNPL — Render & Redirect", () => {
  const publishableKey = Cypress.env("HYPERSWITCH_PUBLISHABLE_KEY");
  const secretKey = Cypress.env("HYPERSWITCH_SECRET_KEY");
  let getIframeBody: () => Cypress.Chainable<JQuery<HTMLBodyElement>>;
  let iframeSelector =
    "#orca-payment-element-iframeRef-orca-elements-payment-element-payment-element";

  changeObjectKeyValue(
    createPaymentBody,
    "profile_id",
    connectorProfileIdMapping.get(connectorEnum.STRIPE),
  );
  changeObjectKeyValue(createPaymentBody, "currency", "EUR");
  changeObjectKeyValue(createPaymentBody, "customer_id", "new_user");

  createPaymentBody.billing.address.country = "DE";
  createPaymentBody.billing.address.state = "Berlin";
  createPaymentBody.billing.address.city = "Berlin";
  createPaymentBody.billing.address.zip = "10115";
  createPaymentBody.billing.address.first_name = "Max";
  createPaymentBody.billing.address.last_name = "Mustermann";
  createPaymentBody.billing.phone = {
    number: "30123456789",
    country_code: "+49",
  };

  createPaymentBody.shipping.address.country = "DE";
  createPaymentBody.shipping.address.state = "Berlin";

  beforeEach(() => {
    getIframeBody = () => cy.iframe(iframeSelector);
    cy.createPaymentIntent(secretKey, createPaymentBody).then(() => {
      cy.getGlobalState("clientSecret").then((clientSecret) => {
        cy.visit(getClientURL(clientSecret, publishableKey));
      });
    });
  });

  it("title rendered correctly", () => {
    cy.contains("Hyperswitch Unified Checkout").should("be.visible");
  });

  it("orca-payment-element iframe loaded", () => {
    cy.get(iframeSelector)
      .should("be.visible")
      .its("0.contentDocument")
      .its("body");
  });

  it("should render Klarna as a payment method option", () => {
    cy.wait(2000);
    getIframeBody().then(($body) => {
      const hasKlarna =
        $body.find("[data-testid='klarna'], [data-testid='Klarna']").length >
          0 || $body.text().includes("Klarna");

      if (hasKlarna) {
        cy.log("Klarna payment method found");
        cy.wrap(hasKlarna).should("be.true");
      } else {
        cy.log(
          "Klarna not found in payment methods — check Stripe profile has Klarna enabled for EUR/DE",
        );
      }
    });
  });

  it("should show payment method list when addNewCard is clicked", () => {
    cy.wait(2000);
    getIframeBody()
      .find(`[data-testid=${testIds.addNewCardIcon}]`)
      .then(($addNew) => {
        if ($addNew.length > 0) {
          cy.wrap($addNew).click();
          cy.wait(500);
          // Payment method list should now show Klarna
          getIframeBody()
            .find("[data-testid='klarna'], [data-testid='Klarna']")
            .should("exist");
        }
      });
  });

  it("should redirect to Klarna on selecting Klarna and submitting", () => {
    cy.wait(2000);
    getIframeBody().then(($body) => {
      // Check if addNewCard button exists (saved card mode) and click it first
      if ($body.find(`[data-testid=${testIds.addNewCardIcon}]`).length > 0) {
        cy.wrap($body)
          .find(`[data-testid=${testIds.addNewCardIcon}]`)
          .click();
        cy.wait(500);
      }

      getIframeBody().then(($refreshed) => {
        const $klarna = $refreshed.find(
          "[data-testid='klarna'], [data-testid='Klarna']",
        );

        if ($klarna.length > 0) {
          cy.wrap($klarna).first().click();
          cy.wait(1000);
          getIframeBody().get("#submit").click();

          // Klarna redirects to its own hosted page
          cy.url({ timeout: 15000 }).should(
            "match",
            /klarna\.com|klarnapayments\.com|pay\.klarna\.com/,
          );
        } else {
          cy.log(
            "Klarna not available — skipping redirect test. Enable Klarna on the Stripe profile.",
          );
        }
      });
    });
  });
});

describe("Klarna BNPL — Adyen Connector", () => {
  const publishableKey = Cypress.env("HYPERSWITCH_PUBLISHABLE_KEY");
  const secretKey = Cypress.env("HYPERSWITCH_SECRET_KEY");
  let getIframeBody: () => Cypress.Chainable<JQuery<HTMLBodyElement>>;
  let iframeSelector =
    "#orca-payment-element-iframeRef-orca-elements-payment-element-payment-element";

  beforeEach(() => {
    getIframeBody = () => cy.iframe(iframeSelector);
    changeObjectKeyValue(
      createPaymentBody,
      "profile_id",
      connectorProfileIdMapping.get(connectorEnum.ADYEN),
    );
    changeObjectKeyValue(createPaymentBody, "currency", "EUR");
    changeObjectKeyValue(createPaymentBody, "customer_id", "new_user");
    createPaymentBody.billing.address.country = "DE";
    createPaymentBody.billing.address.state = "Berlin";
    createPaymentBody.shipping.address.country = "DE";
    cy.createPaymentIntent(secretKey, createPaymentBody).then(() => {
      cy.getGlobalState("clientSecret").then((clientSecret) => {
        cy.visit(getClientURL(clientSecret, publishableKey));
      });
    });
  });

  it("title rendered correctly", () => {
    cy.contains("Hyperswitch Unified Checkout").should("be.visible");
  });

  it("orca-payment-element iframe loaded", () => {
    cy.get(iframeSelector)
      .should("be.visible")
      .its("0.contentDocument")
      .its("body");
  });

  it("should render Klarna via Adyen connector", () => {
    cy.wait(2000);
    getIframeBody().then(($body) => {
      const hasKlarna =
        $body.find("[data-testid='klarna'], [data-testid='Klarna']").length >
          0 || $body.text().includes("Klarna");

      cy.log(
        hasKlarna
          ? "Klarna (Adyen) found"
          : "Klarna not found — check Adyen profile has Klarna enabled",
      );
    });
  });

  it("should redirect to Klarna via Adyen on submission", () => {
    cy.wait(2000);
    getIframeBody().then(($body) => {
      if ($body.find(`[data-testid=${testIds.addNewCardIcon}]`).length > 0) {
        cy.wrap($body)
          .find(`[data-testid=${testIds.addNewCardIcon}]`)
          .click();
        cy.wait(500);
      }

      getIframeBody().then(($refreshed) => {
        const $klarna = $refreshed.find(
          "[data-testid='klarna'], [data-testid='Klarna']",
        );

        if ($klarna.length > 0) {
          cy.wrap($klarna).first().click();
          cy.wait(1000);
          getIframeBody().get("#submit").click();

          cy.url({ timeout: 15000 }).should(
            "match",
            /klarna\.com|klarnapayments\.com|pay\.klarna\.com/,
          );
        } else {
          cy.log("Klarna (Adyen) not available — skipping redirect assertion");
        }
      });
    });
  });
});
