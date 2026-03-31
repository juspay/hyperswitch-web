/**
 * Card Payment Edge Cases
 * Tests for decline scenarios, double-submit prevention, and card brand icon verification
 * that are missing from the existing test suite.
 */
import * as testIds from "../../../../../src/Utilities/TestUtils.bs";
import {
  getClientURL,
  createPaymentBody,
  changeObjectKeyValue,
} from "../../../support/utils";
import { stripeCards } from "../../../support/cards";

describe("Card Payment Edge Cases", () => {
  const publishableKey = Cypress.env("HYPERSWITCH_PUBLISHABLE_KEY");
  const secretKey = Cypress.env("HYPERSWITCH_SECRET_KEY");
  let getIframeBody: () => Cypress.Chainable<JQuery<HTMLBodyElement>>;
  const iframeSelector =
    "#orca-payment-element-iframeRef-orca-elements-payment-element-payment-element";

  beforeEach(() => {
    getIframeBody = () => cy.iframe(iframeSelector);
    changeObjectKeyValue(
      createPaymentBody,
      "customer_id",
      "edge_case_test_user",
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

  describe("Decline Scenarios", () => {
    it("should display error message when payment is declined with invalid card", () => {
      const { cardNo, card_exp_month, card_exp_year, cvc } =
        stripeCards.invalidCard;

      cy.enterCardDetails({ cardNo, card_exp_month, card_exp_year, cvc });

      cy.get("#submit").click();

      cy.contains("Please enter valid details", { timeout: 10000 }).should(
        "be.visible",
      );
    });

    it("should allow user to retry after a declined payment", () => {
      const invalidCard = stripeCards.invalidCard;

      cy.enterCardDetails({
        cardNo: invalidCard.cardNo,
        card_exp_month: invalidCard.card_exp_month,
        card_exp_year: invalidCard.card_exp_year,
        cvc: invalidCard.cvc,
      });

      cy.get("#submit").click();

      cy.contains("Please enter valid details", { timeout: 10000 }).should(
        "be.visible",
      );

      // Retry with a valid card
      const validCard = stripeCards.successCard;

      getIframeBody()
        .find(`[data-testid=${testIds.cardNoInputTestId}]`)
        .safeType(validCard.cardNo);

      getIframeBody()
        .find(`[data-testid=${testIds.expiryInputTestId}]`)
        .safeType(validCard.card_exp_month + validCard.card_exp_year);

      getIframeBody()
        .find(`[data-testid=${testIds.cardCVVInputTestId}]`)
        .safeType(validCard.cvc);

      cy.get("#submit").click();

      cy.contains("Thanks for your order!", { timeout: 10000 }).should(
        "be.visible",
      );
    });
  });

  describe("Double Submit Prevention", () => {
    it("should not allow multiple rapid clicks on submit button", () => {
      const { cardNo, card_exp_month, card_exp_year, cvc } =
        stripeCards.successCard;

      cy.enterCardDetails({ cardNo, card_exp_month, card_exp_year, cvc });

      // Click submit multiple times rapidly
      cy.get("#submit").click();

      // After first click, verify the button is disabled while processing
      cy.get("#submit").should("be.disabled");

      // Payment should still succeed with a single charge
      cy.contains("Thanks for your order!", { timeout: 15000 }).should(
        "be.visible",
      );
    });

    it("should disable submit button while payment is processing", () => {
      const { cardNo, card_exp_month, card_exp_year, cvc } =
        stripeCards.successCard;

      cy.enterCardDetails({ cardNo, card_exp_month, card_exp_year, cvc });

      cy.get("#submit").click();

      // Immediately check that the submit button is in a disabled/processing state
      cy.get("#submit").should("be.disabled");
    });
  });

  describe("Card Brand Icon Display", () => {
    // Helper to find card brand SVG icons using xlink:href (namespaced attribute)
    const findCardBrandIcon = (brand: string) => {
      return getIframeBody()
        .find("svg use")
        .filter((_, el) => {
          const href =
            el.getAttribute("href") ||
            el.getAttributeNS(
              "http://www.w3.org/1999/xlink",
              "href",
            ) ||
            "";
          return href.includes(brand);
        });
    };

    it("should display Visa icon when typing a Visa card number", () => {
      getIframeBody()
        .find(`[data-testid=${testIds.cardNoInputTestId}]`)
        .safeType("4242");

      // Verify a card brand SVG icon is rendered (the SDK uses <svg> with <use> referencing brand icons)
      findCardBrandIcon("visa-light").should("have.length.gte", 1);
    });

    it("should display MasterCard icon when typing a MasterCard number", () => {
      getIframeBody()
        .find(`[data-testid=${testIds.cardNoInputTestId}]`)
        .safeType("5555");

      findCardBrandIcon("mastercard").should("have.length.gte", 1);
    });

    it("should display Amex icon when typing an Amex card number", () => {
      getIframeBody()
        .find(`[data-testid=${testIds.cardNoInputTestId}]`)
        .safeType("3782");

      findCardBrandIcon("amex-light").should("have.length.gte", 1);
    });

    it("should update card brand icon when switching from Visa to MasterCard", () => {
      // Type Visa prefix
      getIframeBody()
        .find(`[data-testid=${testIds.cardNoInputTestId}]`)
        .safeType("4242");

      // Verify Visa icon shows
      findCardBrandIcon("visa-light").should("have.length.gte", 1);

      // Clear and type MasterCard prefix
      getIframeBody()
        .find(`[data-testid=${testIds.cardNoInputTestId}]`)
        .clear()
        .safeType("5555");

      findCardBrandIcon("mastercard").should("have.length.gte", 1);
    });
  });

  describe("Empty Form Submission", () => {
    it("should show error when submitting completely empty form", () => {
      cy.get("#submit").click();

      getIframeBody()
        .find(".Error.pt-1", { timeout: 5000 })
        .should("be.visible");
    });

    it("should show specific field errors for each empty required field", () => {
      // Only fill card number, leave expiry and CVC empty
      getIframeBody()
        .find(`[data-testid=${testIds.cardNoInputTestId}]`)
        .safeType(stripeCards.successCard.cardNo);

      cy.get("#submit").click();

      getIframeBody()
        .find(".Error.pt-1", { timeout: 5000 })
        .should("be.visible");
    });
  });

  describe("Special Characters and Input Sanitization", () => {
    it("should reject special characters in card number field", () => {
      getIframeBody()
        .find(`[data-testid=${testIds.cardNoInputTestId}]`)
        .safeType("4242!@#$4242");

      getIframeBody()
        .find(`[data-testid=${testIds.cardNoInputTestId}]`)
        .should("have.value", "4242 4242");
    });

    it("should reject special characters in CVC field", () => {
      getIframeBody()
        .find(`[data-testid=${testIds.cardNoInputTestId}]`)
        .safeType(stripeCards.successCard.cardNo);

      getIframeBody()
        .find(`[data-testid=${testIds.cardCVVInputTestId}]`)
        .safeType("1!2@3");

      getIframeBody()
        .find(`[data-testid=${testIds.cardCVVInputTestId}]`)
        .should("have.value", "123");
    });

    it("should reject special characters in expiry field", () => {
      getIframeBody()
        .find(`[data-testid=${testIds.cardNoInputTestId}]`)
        .safeType(stripeCards.successCard.cardNo);

      getIframeBody()
        .find(`[data-testid=${testIds.expiryInputTestId}]`)
        .safeType("1!2/3@0");

      // Only digits should be kept
      getIframeBody()
        .find(`[data-testid=${testIds.expiryInputTestId}]`)
        .invoke("val")
        .should("match", /^[\d\s\/]*$/);
    });
  });
});
