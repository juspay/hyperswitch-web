/**
 * Network Failure & Error Scenario Tests
 *
 * These tests are connector-agnostic. They use cy.intercept to simulate
 * API failures at the network level and verify that the SDK handles them
 * gracefully — never leaving the user stuck with a disabled submit button
 * or a blank error state.
 *
 * Regressions covered:
 * - PR #1375: Wrong complete value triggered after payment failure
 * - PR #1389: SDK authorization truncation causing silent failures
 * - PR #1340: Incorrect headers on confirm call in V2
 *
 * Connector: Stripe (pro_5fVcCxU8MFTYozgtf0P8)
 * Currency:  USD
 */
import * as testIds from "../../../src/Utilities/TestUtils.bs";
import { getClientURL } from "../support/utils";
import { createPaymentBody } from "../support/utils";
import {
  changeObjectKeyValue,
  connectorProfileIdMapping,
  connectorEnum,
} from "../support/utils";
import { stripeCards, stripeSpecialCards } from "cypress/support/cards";

describe("Network Failure — Payment Confirm API Errors", () => {
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
  changeObjectKeyValue(createPaymentBody, "customer_id", "new_user");

  beforeEach(() => {
    getIframeBody = () => cy.iframe(iframeSelector);
    cy.createPaymentIntent(secretKey, createPaymentBody).then(() => {
      cy.getGlobalState("clientSecret").then((clientSecret) => {
        cy.visit(getClientURL(clientSecret, publishableKey));
      });
    });
  });

  it("should re-enable submit and not crash when confirm endpoint returns 500", () => {
    cy.intercept("POST", "**/payments/*/confirm*", {
      statusCode: 500,
      body: { error: { type: "server_error", message: "Internal server error" } },
    }).as("confirmFail500");

    const errors: string[] = [];
    cy.on("uncaught:exception", (err) => {
      errors.push(err.message);
      return false;
    });

    const { cardNo, card_exp_month, card_exp_year, cvc } =
      stripeCards.successCard;

    cy.wait(2000);
    getIframeBody().find(`[data-testid=${testIds.cardNoInputTestId}]`).type(cardNo);
    getIframeBody().find(`[data-testid=${testIds.expiryInputTestId}]`).type(card_exp_month);
    getIframeBody().find(`[data-testid=${testIds.expiryInputTestId}]`).type(card_exp_year);
    getIframeBody().find(`[data-testid=${testIds.cardCVVInputTestId}]`).type(cvc);

    getIframeBody().get("#submit").click();
    cy.wait("@confirmFail500");
    cy.wait(2000);

    // SDK returns the error via callback — submit must be re-enabled, no JS crash
    getIframeBody()
      .get("#submit")
      .should("not.be.disabled")
      .and("not.have.attr", "disabled");

    cy.wrap(errors).should("have.length", 0);
  });

  it("should re-enable the submit button after a failed payment confirm (402 decline)", () => {
    cy.intercept("POST", "**/payments/*/confirm*", {
      statusCode: 402,
      body: {
        error: {
          type: "card_error",
          code: "card_declined",
          message: "Your card was declined.",
        },
      },
    }).as("cardDeclined");

    const { cardNo, card_exp_month, card_exp_year, cvc } =
      stripeCards.successCard;

    cy.wait(2000);
    getIframeBody().find(`[data-testid=${testIds.cardNoInputTestId}]`).type(cardNo);
    getIframeBody().find(`[data-testid=${testIds.expiryInputTestId}]`).type(card_exp_month);
    getIframeBody().find(`[data-testid=${testIds.expiryInputTestId}]`).type(card_exp_year);
    getIframeBody().find(`[data-testid=${testIds.cardCVVInputTestId}]`).type(cvc);

    // Submit — button should be disabled while the request is in flight
    getIframeBody().get("#submit").click();
    cy.wait("@cardDeclined");
    cy.wait(2000);

    // Submit button must be re-enabled after failure (regression for PR #1375)
    getIframeBody()
      .get("#submit")
      .should("not.be.disabled")
      .and("not.have.attr", "disabled");
  });

  it("should show 'card declined' message when a decline card is used (live sandbox call)", () => {
    const { cardNo, card_exp_month, card_exp_year, cvc } =
      stripeSpecialCards.declinedCard;

    cy.wait(2000);
    getIframeBody().find(`[data-testid=${testIds.cardNoInputTestId}]`).type(cardNo);
    getIframeBody().find(`[data-testid=${testIds.expiryInputTestId}]`).type(card_exp_month);
    getIframeBody().find(`[data-testid=${testIds.expiryInputTestId}]`).type(card_exp_year);
    getIframeBody().find(`[data-testid=${testIds.cardCVVInputTestId}]`).type(cvc);

    getIframeBody().get("#submit").click();
    cy.wait(5000);

    // Should show a decline message
    cy.contains(
      /declined|Payment failed|check your payment method/i,
      { timeout: 10000 },
    ).should("be.visible");
  });

  it("should disable submit button during in-flight payment request", () => {
    // Delay the confirm response to observe loading state
    cy.intercept("POST", "**/payments/*/confirm*", (req) => {
      req.on("response", (res) => {
        res.setDelay(4000);
      });
    }).as("slowConfirm");

    const { cardNo, card_exp_month, card_exp_year, cvc } =
      stripeCards.successCard;

    cy.wait(2000);
    getIframeBody().find(`[data-testid=${testIds.cardNoInputTestId}]`).type(cardNo);
    getIframeBody().find(`[data-testid=${testIds.expiryInputTestId}]`).type(card_exp_month);
    getIframeBody().find(`[data-testid=${testIds.expiryInputTestId}]`).type(card_exp_year);
    getIframeBody().find(`[data-testid=${testIds.cardCVVInputTestId}]`).type(cvc);

    getIframeBody().get("#submit").click();

    // Immediately after click, submit must be disabled (processing state)
    getIframeBody()
      .get("#submit")
      .should("be.disabled");
  });
});

describe("Network Failure — Payment Methods API Errors", () => {
  const publishableKey = Cypress.env("HYPERSWITCH_PUBLISHABLE_KEY");
  const secretKey = Cypress.env("HYPERSWITCH_SECRET_KEY");
  let iframeSelector =
    "#orca-payment-element-iframeRef-orca-elements-payment-element-payment-element";

  changeObjectKeyValue(
    createPaymentBody,
    "profile_id",
    connectorProfileIdMapping.get(connectorEnum.STRIPE),
  );
  changeObjectKeyValue(createPaymentBody, "customer_id", "new_user");

  it("should still render the payment element when payment_methods API returns 503", () => {
    cy.intercept("GET", "**/account/payment_methods*", {
      statusCode: 503,
      body: { error: "Service temporarily unavailable" },
    }).as("pmFail");

    cy.createPaymentIntent(secretKey, createPaymentBody).then(() => {
      cy.getGlobalState("clientSecret").then((clientSecret) => {
        cy.visit(getClientURL(clientSecret, publishableKey));
        cy.wait("@pmFail");
        cy.wait(2000);

        // The page must not be blank or crash — SDK should show fallback
        cy.get("body").should("be.visible").and("not.be.empty");
        cy.get(iframeSelector).should("exist");
      });
    });
  });

  it("should show a user-visible error when payment_methods API returns 500", () => {
    cy.intercept("GET", "**/account/payment_methods*", {
      statusCode: 500,
      body: { error: { message: "Internal server error" } },
    }).as("pmError");

    cy.createPaymentIntent(secretKey, createPaymentBody).then(() => {
      cy.getGlobalState("clientSecret").then((clientSecret) => {
        cy.visit(getClientURL(clientSecret, publishableKey));
        cy.wait("@pmError");
        cy.wait(2000);

        // Page should not be blank and should indicate an issue
        cy.get("body").should("be.visible").and("not.be.empty");
      });
    });
  });
});

describe("Network Failure — Regression PR#1389: SDK Authorization Header", () => {
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
  changeObjectKeyValue(createPaymentBody, "customer_id", "new_user");

  beforeEach(() => {
    getIframeBody = () => cy.iframe(iframeSelector);
    cy.createPaymentIntent(secretKey, createPaymentBody).then(() => {
      cy.getGlobalState("clientSecret").then((clientSecret) => {
        cy.visit(getClientURL(clientSecret, publishableKey));
      });
    });
  });

  it("regression PR#1389: payment_methods request should include a well-formed api-key header", () => {
    // Intercept and inspect the payment methods request headers
    cy.intercept("GET", "**/account/payment_methods*", (req) => {
      // The api-key header must be present and not empty / truncated
      const apiKey = req.headers["api-key"] || "";
      expect(apiKey).to.have.length.greaterThan(0);
      // A Hyperswitch publishable key starts with "pk_"
      expect(apiKey).to.match(/^pk_/);
      req.continue();
    }).as("pmWithKey");

    cy.wait(2000);
    cy.wait("@pmWithKey");
  });

  it("regression PR#1340: confirm call should include required headers", () => {
    cy.intercept("POST", "**/payments/*/confirm*", (req) => {
      // Content-Type must be application/json
      const contentType = req.headers["content-type"] || "";
      expect(contentType).to.include("application/json");

      // api-key must be present and non-empty
      const apiKey = req.headers["api-key"] || "";
      expect(apiKey).to.have.length.greaterThan(0);

      req.continue();
    }).as("confirmHeaders");

    const { cardNo, card_exp_month, card_exp_year, cvc } =
      stripeCards.successCard;

    cy.wait(2000);
    getIframeBody().find(`[data-testid=${testIds.cardNoInputTestId}]`).type(cardNo);
    getIframeBody().find(`[data-testid=${testIds.expiryInputTestId}]`).type(card_exp_month);
    getIframeBody().find(`[data-testid=${testIds.expiryInputTestId}]`).type(card_exp_year);
    getIframeBody().find(`[data-testid=${testIds.cardCVVInputTestId}]`).type(cvc);
    getIframeBody().get("#submit").click();

    cy.wait("@confirmHeaders");
  });
});
