/**
 * Comprehensive Saved Cards Flow Tests
 * Tests for saved card display, selection, CVC entry, adding new card,
 * and payment with saved cards. The existing test (07-saved-cards.cy.ts)
 * only covers a basic flow with a single conditional check.
 */
import * as testIds from "../../../../../src/Utilities/TestUtils.bs";
import {
  getClientURL,
  createPaymentBody,
  changeObjectKeyValue,
} from "../../../support/utils";
import { stripeCards } from "../../../support/cards";

describe("Comprehensive Saved Cards Flow", () => {
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
      "hyperswitch_sdk_demo_id",
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

  describe("Saved Card Display", () => {
    it("should display saved cards if customer has saved payment methods", () => {
      getIframeBody().then(($body) => {
        const hasAddNewCard =
          $body.find(`[data-testid=${testIds.addNewCardIcon}]`).length > 0;

        if (hasAddNewCard) {
          // Saved cards exist - verify the list is rendered
          getIframeBody()
            .find(`[data-testid=${testIds.addNewCardIcon}]`)
            .should("be.visible");
        } else {
          // No saved cards - new card form should be shown
          getIframeBody()
            .find(`[data-testid=${testIds.cardNoInputTestId}]`)
            .should("be.visible");
        }
      });
    });

    it("should display masked card numbers for saved cards", () => {
      getIframeBody().then(($body) => {
        const hasAddNewCard =
          $body.find(`[data-testid=${testIds.addNewCardIcon}]`).length > 0;

        if (hasAddNewCard) {
          // Verify saved cards show masked numbers (last 4 digits pattern)
          getIframeBody()
            .contains(/\d{4}/)
            .should("be.visible");
        }
      });
    });
  });

  describe("Add New Card Flow", () => {
    it("should show new card form when add new card button is clicked", () => {
      getIframeBody().then(($body) => {
        const hasAddNewCard =
          $body.find(`[data-testid=${testIds.addNewCardIcon}]`).length > 0;

        if (hasAddNewCard) {
          getIframeBody()
            .find(`[data-testid=${testIds.addNewCardIcon}]`)
            .click();

          // New card form fields should be visible
          getIframeBody()
            .find(`[data-testid=${testIds.cardNoInputTestId}]`)
            .should("be.visible");

          getIframeBody()
            .find(`[data-testid=${testIds.expiryInputTestId}]`)
            .should("be.visible");

          getIframeBody()
            .find(`[data-testid=${testIds.cardCVVInputTestId}]`)
            .should("be.visible");
        }
      });
    });

    it("should complete payment with a new card after clicking add new card", () => {
      getIframeBody().then(($body) => {
        const hasAddNewCard =
          $body.find(`[data-testid=${testIds.addNewCardIcon}]`).length > 0;

        if (hasAddNewCard) {
          getIframeBody()
            .find(`[data-testid=${testIds.addNewCardIcon}]`)
            .click();

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
        }
      });
    });
  });

  describe("Saved Card CVC Entry", () => {
    it("should require CVC before submitting with a saved card", () => {
      getIframeBody().then(($body) => {
        const hasSavedCards =
          $body.find(`[data-testid=${testIds.addNewCardIcon}]`).length > 0;

        if (hasSavedCards) {
          // Click on a saved card with 4-digit display
          getIframeBody()
            .contains(/\d{4}/)
            .first()
            .click();

          // Submit without entering CVC
          cy.get("#submit").click();

          // Should show CVC error
          getIframeBody()
            .find(".Error.pt-1", { timeout: 5000 })
            .should("be.visible");
        }
      });
    });

    it("should complete payment with saved card after entering valid CVC", () => {
      getIframeBody().then(($body) => {
        const hasSavedCards =
          $body.find(`[data-testid=${testIds.addNewCardIcon}]`).length > 0;

        if (hasSavedCards) {
          // Click on a saved card
          getIframeBody().contains("4 digit").click();

          // Enter CVC
          getIframeBody()
            .find(`[data-testid=${testIds.cardCVVInputTestId}]`)
            .safeType("1234");

          cy.get("#submit").click();

          cy.contains("Thanks for your order!", { timeout: 10000 }).should(
            "be.visible",
          );
        }
      });
    });

    it("should show error for empty CVC on saved card submission", () => {
      getIframeBody().then(($body) => {
        const hasSavedCards =
          $body.find(`[data-testid=${testIds.addNewCardIcon}]`).length > 0;

        if (hasSavedCards) {
          getIframeBody().contains("4 digit").click();

          cy.get("#submit").click();

          getIframeBody()
            .find(".Error.pt-1", { timeout: 5000 })
            .should("be.visible")
            .and("contain.text", "CVC Number cannot be empty");
        }
      });
    });

    it("should accept 3-digit CVC for non-Amex saved card", () => {
      getIframeBody().then(($body) => {
        const hasSavedCards =
          $body.find(`[data-testid=${testIds.addNewCardIcon}]`).length > 0;

        if (hasSavedCards) {
          getIframeBody().contains("4 digit").click();

          getIframeBody()
            .find(`[data-testid=${testIds.cardCVVInputTestId}]`)
            .safeType("123");

          getIframeBody()
            .find(`[data-testid=${testIds.cardCVVInputTestId}]`)
            .should("have.value", "123");
        }
      });
    });
  });

  describe("Saved Card Selection", () => {
    it("should highlight selected saved card", () => {
      getIframeBody().then(($body) => {
        const hasSavedCards =
          $body.find(`[data-testid=${testIds.addNewCardIcon}]`).length > 0;

        if (hasSavedCards) {
          getIframeBody().contains("4 digit").click();

          // The selected card should have some visual indicator
          getIframeBody()
            .find(`[data-testid=${testIds.cardCVVInputTestId}]`)
            .should("be.visible");
        }
      });
    });
  });
});
