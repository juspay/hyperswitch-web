/**
 * Adyen Card Payment Tests
 * Tests for card payments via the Adyen connector.
 * Gap: No Adyen connector tests existed despite having profile ID mapping.
 */
import * as testIds from "../../../../../src/Utilities/TestUtils.bs";
import {
  getClientURL,
  createPaymentBody,
  changeObjectKeyValue,
  connectorEnum,
  connectorProfileIdMapping,
} from "../../../support/utils";
import { stripeCards } from "../../../support/cards";

describe("Adyen Card Payment", () => {
  const publishableKey = Cypress.env("HYPERSWITCH_PUBLISHABLE_KEY");
  const secretKey = Cypress.env("HYPERSWITCH_SECRET_KEY");
  let getIframeBody: () => Cypress.Chainable<JQuery<HTMLBodyElement>>;
  const iframeSelector =
    "#orca-payment-element-iframeRef-orca-elements-payment-element-payment-element";

  beforeEach(() => {
    getIframeBody = () => cy.iframe(iframeSelector);

    // Configure for Adyen connector
    changeObjectKeyValue(
      createPaymentBody,
      "profile_id",
      connectorProfileIdMapping.get(connectorEnum.ADYEN),
    );
    changeObjectKeyValue(
      createPaymentBody,
      "customer_id",
      "adyen_card_test_user",
    );
    changeObjectKeyValue(
      createPaymentBody,
      "authentication_type",
      "no_three_ds",
    );
    changeObjectKeyValue(createPaymentBody, "capture_method", "automatic");

    cy.createPaymentIntent(secretKey, createPaymentBody).then(() => {
      cy.getGlobalState("clientSecret").then((clientSecret) => {
        cy.visit(getClientURL(clientSecret, publishableKey));
        cy.waitForSDKReady();
      });
    });
  });

  describe("Successful Payments", () => {
    // TODO: Adyen test cards are not available in cards.ts.
    // Stripe test cards (4242...) do not work with Adyen's test environment.
    // Add Adyen-specific test cards to cypress/support/cards.ts to enable these tests.
    it.skip("should complete a successful card payment with Adyen (no 3DS)", () => {
      const { cardNo, card_exp_month, card_exp_year, cvc } =
        stripeCards.successCard;

      cy.enterCardDetails({ cardNo, card_exp_month, card_exp_year, cvc });

      cy.get("#submit").click();

      cy.contains("Thanks for your order!", { timeout: 10000 }).should(
        "be.visible",
      );
    });

    it.skip("should complete a successful MasterCard payment with Adyen", () => {
      const { cardNo, card_exp_month, card_exp_year, cvc } =
        stripeCards.masterCard16;

      cy.enterCardDetails({ cardNo, card_exp_month, card_exp_year, cvc });

      cy.get("#submit").click();

      cy.contains("Thanks for your order!", { timeout: 10000 }).should(
        "be.visible",
      );
    });
  });

  describe("Failed Payments", () => {
    it("should fail with an invalid card number via Adyen", () => {
      const { cardNo, card_exp_month, card_exp_year, cvc } =
        stripeCards.invalidCard;

      cy.enterCardDetails({ cardNo, card_exp_month, card_exp_year, cvc });

      cy.get("#submit").click();

      cy.contains("Please enter valid details", { timeout: 10000 }).should(
        "be.visible",
      );
    });
  });

  describe("3DS Authentication with Adyen", () => {
    // TODO: Requires Adyen-specific 3DS test cards. Stripe's 3DS card does not trigger 3DS with Adyen.
    it.skip("should redirect to 3DS page when authentication is required", () => {
      changeObjectKeyValue(
        createPaymentBody,
        "authentication_type",
        "three_ds",
      );
      changeObjectKeyValue(
        createPaymentBody,
        "customer_id",
        "adyen_3ds_test_user",
      );

      cy.createPaymentIntent(secretKey, createPaymentBody).then(() => {
        cy.getGlobalState("clientSecret").then((clientSecret) => {
          cy.visit(getClientURL(clientSecret, publishableKey));
        });
      });

      cy.waitForSDKReady();

      const { cardNo, card_exp_month, card_exp_year, cvc } =
        stripeCards.threeDSCard;

      cy.enterCardDetails({ cardNo, card_exp_month, card_exp_year, cvc });

      cy.get("#submit").click();

      // Adyen should trigger 3DS redirect/challenge
      cy.url({ timeout: 15000 }).should("not.include", "localhost:9060");
    });
  });

  describe("Manual Capture with Adyen", () => {
    // TODO: Requires Adyen-specific test cards. Stripe cards do not authorize with Adyen.
    it.skip("should authorize payment with manual capture", () => {
      changeObjectKeyValue(createPaymentBody, "capture_method", "manual");
      changeObjectKeyValue(
        createPaymentBody,
        "customer_id",
        "adyen_manual_capture_user",
      );

      cy.createPaymentIntent(secretKey, createPaymentBody).then(() => {
        cy.getGlobalState("clientSecret").then((clientSecret) => {
          cy.visit(getClientURL(clientSecret, publishableKey));
        });
      });

      cy.waitForSDKReady();

      const { cardNo, card_exp_month, card_exp_year, cvc } =
        stripeCards.successCard;

      cy.enterCardDetails({ cardNo, card_exp_month, card_exp_year, cvc });

      cy.get("#submit").click();

      // Manual capture should show authorization message
      cy.contains(/Thanks for your order|authorized/i, {
        timeout: 10000,
      }).should("be.visible");
    });
  });
});
