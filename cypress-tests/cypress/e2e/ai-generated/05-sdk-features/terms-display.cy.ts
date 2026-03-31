/**
 * Terms Display Tests
 * Verifies that the terms option controls the visibility of terms text
 * for different payment methods (Auto, Always, Never).
 * Note: Card terms only display for mandate/setup flows (NEW_MANDATE/SETUP_MANDATE).
 */
import * as testIds from "../../../../../src/Utilities/TestUtils.bs";
import {
  getClientURL,
  createPaymentBody,
  changeObjectKeyValue,
} from "../../../support/utils";
import { stripeCards } from "../../../support/cards";

describe("PaymentElement terms Option", () => {
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
      "terms_test_user"
    );
    changeObjectKeyValue(
      createPaymentBody,
      "authentication_type",
      "no_three_ds"
    );
    // Card terms only display for mandate flows, so set setup_future_usage
    changeObjectKeyValue(
      createPaymentBody,
      "setup_future_usage",
      "off_session"
    );
  });

  afterEach(() => {
    // Clean up mandate flag
    delete (createPaymentBody as Record<string, unknown>)["setup_future_usage"];
  });

  describe('terms.card: "always" with mandate flow', () => {
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
                terms: {
                  card: "always",
                  auBecsDebit: "auto",
                  bancontact: "auto",
                  ideal: "auto",
                  sepaDebit: "auto",
                  sofort: "auto",
                  usBankAccount: "auto",
                },
              }
            )
          );
          cy.waitForSDKReady();
        });
      });
    });

    it("should display card terms text when card is selected", () => {
      getIframeBody()
        .find(".TermsTextLabel", { timeout: 10000 })
        .should("be.visible");
    });
  });

  describe('terms.card: "never" with mandate flow', () => {
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
                terms: {
                  card: "never",
                  auBecsDebit: "auto",
                  bancontact: "auto",
                  ideal: "auto",
                  sepaDebit: "auto",
                  sofort: "auto",
                  usBankAccount: "auto",
                },
              }
            )
          );
          cy.waitForSDKReady();
        });
      });
    });

    it("should hide card terms text when card is selected", () => {
      getIframeBody()
        .find(".TermsTextLabel")
        .should("not.exist");
    });
  });

  describe("terms.card: not applicable for non-mandate flow", () => {
    beforeEach(() => {
      // Remove setup_future_usage for this test
      delete (createPaymentBody as Record<string, unknown>)[
        "setup_future_usage"
      ];

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
                terms: {
                  card: "always",
                  auBecsDebit: "auto",
                  bancontact: "auto",
                  ideal: "auto",
                  sepaDebit: "auto",
                  sofort: "auto",
                  usBankAccount: "auto",
                },
              }
            )
          );
          cy.waitForSDKReady();
        });
      });
    });

    it("should not show card terms for non-mandate payment flows", () => {
      // Card terms only appear for mandate (setup_future_usage) flows
      getIframeBody()
        .find(".TermsTextLabel")
        .should("not.exist");
    });
  });
});
