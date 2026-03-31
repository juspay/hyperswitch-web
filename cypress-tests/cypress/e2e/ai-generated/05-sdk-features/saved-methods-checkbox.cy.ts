/**
 * Saved Payment Methods Checkbox Tests
 * Verifies that displaySavedPaymentMethodsCheckbox controls the visibility
 * of the "save payment method" checkbox in the payment element.
 *
 * The save card checkbox shows when:
 * - Customer is not a guest (customer_id is set)
 * - No existing mandate_payment
 * - Payment type is not SETUP_MANDATE
 * - displaySavedPaymentMethodsCheckbox is true
 *
 * The Checkbox component uses CSS class "Checkbox" and role="checkbox".
 * It does not have a data-testid attribute.
 */
import * as testIds from "../../../../../src/Utilities/TestUtils.bs";
import {
  getClientURL,
  createPaymentBody,
  changeObjectKeyValue,
} from "../../../support/utils";
import { stripeCards } from "../../../support/cards";

describe("PaymentElement displaySavedPaymentMethodsCheckbox Option", () => {
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
      "checkbox_test_user"
    );
    changeObjectKeyValue(
      createPaymentBody,
      "authentication_type",
      "no_three_ds"
    );
  });

  describe("displaySavedPaymentMethodsCheckbox: true (default)", () => {
    beforeEach(() => {
      cy.createPaymentIntent(secretKey, createPaymentBody).then(() => {
        cy.getGlobalState("clientSecret").then((clientSecret) => {
          cy.visit(
            getClientURL(
              clientSecret,
              publishableKey,
              undefined,
              undefined,
              undefined,
              {
                displaySavedPaymentMethodsCheckbox: true,
              }
            )
          );
          cy.waitForSDKReady();
        });
      });
    });

    it("should display the save card checkbox", () => {
      // Wait for payment method list to load
      getIframeBody()
        .find(`[data-testid=${testIds.cardNoInputTestId}]`, { timeout: 10000 })
        .should("be.visible");

      // The checkbox uses role="checkbox" and CSS class "Checkbox"
      getIframeBody()
        .find('[role="checkbox"]', { timeout: 10000 })
        .should("exist");
    });
  });

  describe("displaySavedPaymentMethodsCheckbox: false", () => {
    beforeEach(() => {
      cy.createPaymentIntent(secretKey, createPaymentBody).then(() => {
        cy.getGlobalState("clientSecret").then((clientSecret) => {
          cy.visit(
            getClientURL(
              clientSecret,
              publishableKey,
              undefined,
              undefined,
              undefined,
              {
                displaySavedPaymentMethodsCheckbox: false,
              }
            )
          );
          cy.waitForSDKReady();
        });
      });
    });

    it("should hide the save card checkbox", () => {
      // Wait for payment form to load
      getIframeBody()
        .find(`[data-testid=${testIds.cardNoInputTestId}]`, { timeout: 10000 })
        .should("be.visible");

      // The checkbox should not be present
      getIframeBody()
        .find('[role="checkbox"]')
        .should("not.exist");
    });
  });
});
