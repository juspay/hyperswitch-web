/**
 * Wallets Visibility Toggle Tests
 * Verifies that the wallets option (applePay, googlePay, payPal, etc.)
 * controls the visibility of wallet payment buttons.
 * Note: Actual wallet functionality requires device capabilities;
 * these tests verify the visibility toggle logic via "never" mode.
 */
import {
  getClientURL,
  createPaymentBody,
  changeObjectKeyValue,
} from "../../../support/utils";

describe("PaymentElement wallets Visibility Option", () => {
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
      "wallets_visibility_test_user"
    );
    changeObjectKeyValue(
      createPaymentBody,
      "authentication_type",
      "no_three_ds"
    );
  });

  describe("all wallets set to never", () => {
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
                wallets: {
                  walletReturnUrl: "http://localhost:9060",
                  applePay: "never",
                  googlePay: "never",
                  payPal: "never",
                  klarna: "never",
                  paze: "never",
                  samsungPay: "never",
                  style: {
                    theme: "dark",
                    type: "default",
                    height: 55,
                  },
                },
              }
            )
          );
          cy.waitForSDKReady();
        });
      });
    });

    it("should not render Apple Pay button", () => {
      getIframeBody()
        .find("[data-testid=apple-pay-button]")
        .should("not.exist");
    });

    it("should not render Google Pay button", () => {
      getIframeBody()
        .find("[data-testid=google-pay-button]")
        .should("not.exist");
    });

    it("should not render PayPal button", () => {
      getIframeBody()
        .find("[data-testid=paypal-button]")
        .should("not.exist");
    });

    it("should not render any wallet section divider", () => {
      // When all wallets are hidden, the OR divider should also not appear
      getIframeBody()
        .find(".Or")
        .should("not.exist");
    });
  });

  describe("wallets set to auto (default)", () => {
    beforeEach(() => {
      cy.createPaymentIntent(secretKey, createPaymentBody).then(() => {
        cy.getGlobalState("clientSecret").then((clientSecret) => {
          cy.visit(getClientURL(clientSecret, publishableKey));
          cy.waitForSDKReady();
        });
      });
    });

    it("should render the payment element with card form available", () => {
      // Card form should always be available regardless of wallet settings
      getIframeBody()
        .find("[data-testid=cardNoInput]", { timeout: 10000 })
        .should("exist");
    });
  });

  describe("selective wallet visibility (googlePay: never, others: auto)", () => {
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
                wallets: {
                  walletReturnUrl: "http://localhost:9060",
                  applePay: "auto",
                  googlePay: "never",
                  payPal: "auto",
                  klarna: "auto",
                  paze: "auto",
                  samsungPay: "auto",
                  style: {
                    theme: "dark",
                    type: "default",
                    height: 55,
                  },
                },
              }
            )
          );
          cy.waitForSDKReady();
        });
      });
    });

    it("should not render Google Pay button when set to never", () => {
      getIframeBody()
        .find("[data-testid=google-pay-button]")
        .should("not.exist");
    });
  });
});
