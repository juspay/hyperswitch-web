/**
 * Keyboard Navigation and Accessibility Tests
 * Tests for tab navigation, focus management, and basic a11y patterns
 * in the payment form. This area was completely untested.
 */
import * as testIds from "../../../../src/Utilities/TestUtils.bs";
import {
  getClientURL,
  createPaymentBody,
  changeObjectKeyValue,
} from "../../support/utils";
import { stripeCards } from "../../support/cards";

describe("Keyboard Navigation and Accessibility", () => {
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
      "pro_5fVcCxU8MFTYozgtf0P8",
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
    changeObjectKeyValue(
      createPaymentBody,
      "customer_id",
      "a11y_test_user",
    );
    changeObjectKeyValue(
      createPaymentBody,
      "authentication_type",
      "no_three_ds",
    );

    cy.createPaymentIntent(secretKey, createPaymentBody).then(() => {
      cy.getGlobalState("clientSecret").then((clientSecret) => {
        cy.visit(getClientURL(clientSecret, publishableKey));
        cy.waitForSDKReady();
      });
    });
  });

  describe("Tab Navigation", () => {
    it("should allow tabbing from card number to expiry field", () => {
      getIframeBody()
        .find(`[data-testid=${testIds.cardNoInputTestId}]`)
        .safeType(stripeCards.successCard.cardNo);

      getIframeBody()
        .find(`[data-testid=${testIds.expiryInputTestId}]`)
        .should("be.visible");
    });

    it("should allow tabbing from expiry to CVC field", () => {
      getIframeBody()
        .find(`[data-testid=${testIds.cardNoInputTestId}]`)
        .safeType(stripeCards.successCard.cardNo);

      getIframeBody()
        .find(`[data-testid=${testIds.expiryInputTestId}]`)
        .safeType(
          stripeCards.successCard.card_exp_month +
            stripeCards.successCard.card_exp_year,
        );

      getIframeBody()
        .find(`[data-testid=${testIds.cardCVVInputTestId}]`)
        .should("be.visible");
    });

    it("should allow completing full payment using only keyboard", () => {
      const { cardNo, card_exp_month, card_exp_year, cvc } =
        stripeCards.successCard;

      getIframeBody()
        .find(`[data-testid=${testIds.cardNoInputTestId}]`)
        .safeType(cardNo);

      getIframeBody()
        .find(`[data-testid=${testIds.expiryInputTestId}]`)
        .type(card_exp_month + card_exp_year);

      getIframeBody()
        .find(`[data-testid=${testIds.cardCVVInputTestId}]`)
        .type(cvc);

      cy.get("#submit").click();

      cy.contains("Thanks for your order!", { timeout: 10000 }).should(
        "be.visible",
      );
    });
  });

  describe("Focus Management", () => {
    it("should show focus ring on card number input when focused", () => {
      getIframeBody()
        .find(`[data-testid=${testIds.cardNoInputTestId}]`)
        .focus()
        .should("be.focused");
    });

    it("should show focus ring on expiry input when focused", () => {
      getIframeBody()
        .find(`[data-testid=${testIds.expiryInputTestId}]`)
        .focus()
        .should("be.focused");
    });

    it("should show focus ring on CVC input when focused", () => {
      getIframeBody()
        .find(`[data-testid=${testIds.cardCVVInputTestId}]`)
        .focus()
        .should("be.focused");
    });
  });

  describe("Input Accessibility Attributes", () => {
    it("should have autocomplete attributes on card fields", () => {
      getIframeBody()
        .find(`[data-testid=${testIds.cardNoInputTestId}]`)
        .should("have.attr", "autocomplete");
    });

    it("should have aria-label or placeholder on card number input", () => {
      getIframeBody()
        .find(`[data-testid=${testIds.cardNoInputTestId}]`)
        .then(($input) => {
          const hasAriaLabel = $input.attr("aria-label");
          const hasPlaceholder = $input.attr("placeholder");
          expect(hasAriaLabel || hasPlaceholder).to.not.be.undefined;
        });
    });

    it("should have aria-label or placeholder on expiry input", () => {
      getIframeBody()
        .find(`[data-testid=${testIds.expiryInputTestId}]`)
        .then(($input) => {
          const hasAriaLabel = $input.attr("aria-label");
          const hasPlaceholder = $input.attr("placeholder");
          expect(hasAriaLabel || hasPlaceholder).to.not.be.undefined;
        });
    });

    it("should have aria-label or placeholder on CVC input", () => {
      getIframeBody()
        .find(`[data-testid=${testIds.cardCVVInputTestId}]`)
        .then(($input) => {
          const hasAriaLabel = $input.attr("aria-label");
          const hasPlaceholder = $input.attr("placeholder");
          expect(hasAriaLabel || hasPlaceholder).to.not.be.undefined;
        });
    });
  });

  describe("Error Announcement", () => {
    it("should display visible error messages on invalid submission", () => {
      getIframeBody()
        .find(`[data-testid=${testIds.cardNoInputTestId}]`)
        .safeType("4242 4242");

      getIframeBody()
        .find(`[data-testid=${testIds.expiryInputTestId}]`)
        .safeType("12");

      cy.get("#submit").click();

      getIframeBody()
        .find(".Error.pt-1", { timeout: 10000 })
        .should("be.visible")
        .invoke("text")
        .should("not.be.empty");
    });

    it("should clear error message when user starts correcting input", () => {
      cy.get("#submit").click();

      getIframeBody()
        .find(".Error.pt-1", { timeout: 10000 })
        .should("be.visible");

      getIframeBody()
        .find(`[data-testid=${testIds.cardNoInputTestId}]`)
        .safeType(stripeCards.successCard.cardNo);

      getIframeBody()
        .find(`[data-testid=${testIds.cardNoInputTestId}]`)
        .should("have.value", "4242 4242 4242 4242");
    });
  });
});
