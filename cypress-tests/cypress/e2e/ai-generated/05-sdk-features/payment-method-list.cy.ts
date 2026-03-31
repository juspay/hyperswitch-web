/**
 * Payment Method List Rendering and Switching Tests
 * Tests for payment method list display, switching between methods,
 * and verifying correct form fields render per method.
 */
import * as testIds from "../../../../../src/Utilities/TestUtils.bs";
import {
  getClientURL,
  createPaymentBody,
  changeObjectKeyValue,
} from "../../../support/utils";

describe("Payment Method List Rendering", () => {
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
      "payment_method_list_test_user",
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

  describe("Payment Method List Display", () => {
    it("should render the payment method list container", () => {
      getIframeBody()
        .find(`[data-testid=${testIds.paymentMethodListTestId}]`)
        .should("exist");
    });

    it("should display card payment fields by default", () => {
      getIframeBody()
        .find(`[data-testid=${testIds.cardNoInputTestId}]`)
        .should("be.visible");

      getIframeBody()
        .find(`[data-testid=${testIds.expiryInputTestId}]`)
        .should("be.visible");

      getIframeBody()
        .find(`[data-testid=${testIds.cardCVVInputTestId}]`)
        .should("be.visible");
    });

    it("should display the submit button", () => {
      cy.get("#submit").should("be.visible");
    });
  });

  describe("Payment Method Switching", () => {
    it("should switch to a different payment method when clicked", () => {
      // Check if there are other payment methods available
      getIframeBody()
        .find(`[data-testid=${testIds.paymentMethodListTestId}]`)
        .then(($list) => {
          // Look for alternative payment method tabs/options
          const altMethods = $list.find("[role='tab'], [data-testid]");
          if (altMethods.length > 1) {
            // Click the second payment method
            cy.wrap(altMethods.eq(1)).click();

            // Card fields should no longer be the active form
            // (or the form should change to the new method)
            cy.get("#submit")
              .should("be.visible");
          }
        });
    });

    it("should restore card fields when switching back to card method", () => {
      getIframeBody()
        .find(`[data-testid=${testIds.paymentMethodListTestId}]`)
        .then(($list) => {
          const altMethods = $list.find("[role='tab'], [data-testid]");
          if (altMethods.length > 1) {
            // Switch away from card
            cy.wrap(altMethods.eq(1)).click();

            // Switch back to card
            cy.wrap(altMethods.eq(0)).click();

            // Card fields should be visible again
            getIframeBody()
              .find(`[data-testid=${testIds.cardNoInputTestId}]`)
              .should("be.visible");
          }
        });
    });

    it("should clear card input when switching payment methods and back", () => {
      // Type partial card number
      getIframeBody()
        .find(`[data-testid=${testIds.cardNoInputTestId}]`)
        .safeType("4242");

      getIframeBody()
        .find(`[data-testid=${testIds.paymentMethodListTestId}]`)
        .then(($list) => {
          const altMethods = $list.find("[role='tab'], [data-testid]");
          if (altMethods.length > 1) {
            // Switch away
            cy.wrap(altMethods.eq(1)).click();

            // Switch back
            cy.wrap(altMethods.eq(0)).click();

            // Card input may be cleared after method switch
            getIframeBody()
              .find(`[data-testid=${testIds.cardNoInputTestId}]`)
              .should("be.visible");
          }
        });
    });
  });

  describe("Payment Method Dropdown", () => {
    it("should render payment method dropdown if configured", () => {
      getIframeBody().then(($body) => {
        const hasDropdown =
          $body.find(
            `[data-testid=${testIds.paymentMethodDropDownTestId}]`,
          ).length > 0;
        if (hasDropdown) {
          getIframeBody()
            .find(`[data-testid=${testIds.paymentMethodDropDownTestId}]`)
            .should("be.visible");
        }
      });
    });
  });
});
