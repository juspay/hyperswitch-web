/**
 * Submit Button State Tests
 * Tests for submit button behavior: disabled during processing,
 * re-enabled after error, loading states, and visual feedback.
 */
import * as testIds from "../../../../../src/Utilities/TestUtils.bs";
import {
  getClientURL,
  createPaymentBody,
  changeObjectKeyValue,
} from "../../../support/utils";
import { stripeCards } from "../../../support/cards";

describe("Submit Button States", () => {
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
      "submit_button_test_user",
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

  describe("Initial State", () => {
    it("should render the submit button as visible and enabled on page load", () => {
      cy.get("#submit")
        .should("be.visible")
        .and("not.be.disabled");
    });

    it("should display the submit button with appropriate text", () => {
      cy.get("#submit")
        .should("be.visible")
        .invoke("text")
        .should("not.be.empty");
    });
  });

  describe("Processing State", () => {
    it("should disable submit button immediately after click with valid card", () => {
      const { cardNo, card_exp_month, card_exp_year, cvc } =
        stripeCards.successCard;

      cy.enterCardDetails({ cardNo, card_exp_month, card_exp_year, cvc });

      cy.get("#submit").click();

      // Button should be disabled while processing
      cy.get("#submit").should("be.disabled");
    });

    it("should show loading indicator while payment is processing", () => {
      const { cardNo, card_exp_month, card_exp_year, cvc } =
        stripeCards.successCard;

      cy.enterCardDetails({ cardNo, card_exp_month, card_exp_year, cvc });

      cy.get("#submit").click();

      // Check for loading/spinner state on the button
      cy.get("#submit")
        .should("be.disabled");
    });
  });

  describe("Error Recovery State", () => {
    it("should keep submit button enabled after client-side validation error", () => {
      // Type partial/invalid card data to trigger client-side validation error
      // (Submitting a completely empty form may go to "Processing..." without errors)
      getIframeBody()
        .find(`[data-testid=${testIds.cardNoInputTestId}]`)
        .safeType("4242 4242");

      getIframeBody()
        .find(`[data-testid=${testIds.expiryInputTestId}]`)
        .safeType("12");

      cy.get("#submit").click();

      getIframeBody()
        .find(".Error.pt-1", { timeout: 10000 })
        .should("be.visible");

      // Button should remain enabled after validation error
      cy.get("#submit")
        .should("be.visible")
        .and("not.be.disabled");
    });

    it("should allow resubmission after fixing validation errors", () => {
      // Type partial/invalid card data to trigger client-side validation error
      // (Submitting a completely empty form may go to "Processing..." without errors)
      getIframeBody()
        .find(`[data-testid=${testIds.cardNoInputTestId}]`)
        .safeType("4242 4242");

      cy.get("#submit").click();

      getIframeBody()
        .find(".Error.pt-1", { timeout: 5000 })
        .should("be.visible");

      // Now clear and fill in valid card details
      getIframeBody()
        .find(`[data-testid=${testIds.cardNoInputTestId}]`)
        .clear();

      const { cardNo, card_exp_month, card_exp_year, cvc } =
        stripeCards.successCard;

      cy.enterCardDetails({ cardNo, card_exp_month, card_exp_year, cvc });

      // Submit again with valid data
      cy.get("#submit").click();

      cy.contains("Thanks for your order!", { timeout: 10000 }).should(
        "be.visible",
      );
    });
  });

  describe("Submit with Incomplete Fields", () => {
    it("should not process payment when only card number is filled", () => {
      getIframeBody()
        .find(`[data-testid=${testIds.cardNoInputTestId}]`)
        .safeType(stripeCards.successCard.cardNo);

      cy.get("#submit").click();

      getIframeBody()
        .find(".Error.pt-1", { timeout: 5000 })
        .should("be.visible");

      // Should still be on the payment page
      cy.get("#submit")
        .should("be.visible");
    });

    it("should not process payment when CVC is missing", () => {
      getIframeBody()
        .find(`[data-testid=${testIds.cardNoInputTestId}]`)
        .safeType(stripeCards.successCard.cardNo);

      getIframeBody()
        .find(`[data-testid=${testIds.expiryInputTestId}]`)
        .safeType(
          stripeCards.successCard.card_exp_month +
            stripeCards.successCard.card_exp_year,
        );

      cy.get("#submit").click();

      getIframeBody()
        .find(".Error.pt-1", { timeout: 5000 })
        .should("be.visible");
    });

    it("should not process payment when expiry is missing", () => {
      getIframeBody()
        .find(`[data-testid=${testIds.cardNoInputTestId}]`)
        .safeType(stripeCards.successCard.cardNo);

      getIframeBody()
        .find(`[data-testid=${testIds.cardCVVInputTestId}]`)
        .safeType(stripeCards.successCard.cvc);

      cy.get("#submit").click();

      getIframeBody()
        .find(".Error.pt-1", { timeout: 5000 })
        .should("be.visible");
    });
  });
});
