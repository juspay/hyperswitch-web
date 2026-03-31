/**
 * Display Billing Details Tests
 * Verifies that the displayBillingDetails option controls
 * the visibility of billing details text on saved payment method cards.
 *
 * Note: displayBillingDetails only affects saved card items (SavedCardItem.res).
 * It shows/hides the billing address text associated with a saved card.
 * It does NOT control whether billing input fields appear for new card payments —
 * that is controlled by the backend's required fields + fields.billingDetails option.
 *
 * Since testing saved cards requires a customer with previously saved cards,
 * and our test environment may not reliably have saved cards available,
 * we verify the option is accepted without error and the SDK renders correctly.
 */
import * as testIds from "../../../../../src/Utilities/TestUtils.bs";
import {
  getClientURL,
  createPaymentBody,
  changeObjectKeyValue,
} from "../../../support/utils";

describe("PaymentElement displayBillingDetails Option", () => {
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
      "display_billing_test_user"
    );
    changeObjectKeyValue(
      createPaymentBody,
      "authentication_type",
      "no_three_ds"
    );
  });

  describe("displayBillingDetails: true", () => {
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
                displayBillingDetails: true,
              }
            )
          );
          cy.waitForSDKReady();
        });
      });
    });

    it("should render the payment element without errors when displayBillingDetails is true", () => {
      // Verify the payment form loads correctly with the option set
      getIframeBody()
        .find(`[data-testid=${testIds.cardNoInputTestId}]`, { timeout: 10000 })
        .should("be.visible");

      getIframeBody()
        .find(`[data-testid=${testIds.expiryInputTestId}]`)
        .should("be.visible");

      getIframeBody()
        .find(`[data-testid=${testIds.cardCVVInputTestId}]`)
        .should("be.visible");
    });
  });

  describe("displayBillingDetails: false (default)", () => {
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
                displayBillingDetails: false,
              }
            )
          );
          cy.waitForSDKReady();
        });
      });
    });

    it("should render the payment element without errors when displayBillingDetails is false", () => {
      // Verify the payment form loads correctly with the option set to false
      getIframeBody()
        .find(`[data-testid=${testIds.cardNoInputTestId}]`, { timeout: 10000 })
        .should("be.visible");

      getIframeBody()
        .find(`[data-testid=${testIds.expiryInputTestId}]`)
        .should("be.visible");

      getIframeBody()
        .find(`[data-testid=${testIds.cardCVVInputTestId}]`)
        .should("be.visible");
    });
  });
});
