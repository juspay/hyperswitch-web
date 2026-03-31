/**
 * ReadOnly Mode Tests
 * Verifies that when readOnly option is true, all payment form inputs are disabled
 * and cannot accept user input.
 */
import * as testIds from "../../../../../src/Utilities/TestUtils.bs";
import {
  getClientURL,
  createPaymentBody,
  changeObjectKeyValue,
} from "../../../support/utils";

describe("PaymentElement readOnly Option", () => {
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
      "readonly_test_user"
    );
    changeObjectKeyValue(
      createPaymentBody,
      "authentication_type",
      "no_three_ds"
    );
  });

  describe("readOnly: true", () => {
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
              { readOnly: true }
            )
          );
          cy.waitForSDKReady();
        });
      });
    });

    it("should render card number input as disabled", () => {
      getIframeBody()
        .find(`[data-testid=${testIds.cardNoInputTestId}]`)
        .should("exist")
        .should("have.attr", "disabled");
    });

    it("should render expiry input as disabled", () => {
      getIframeBody()
        .find(`[data-testid=${testIds.expiryInputTestId}]`)
        .should("exist")
        .should("have.attr", "disabled");
    });

    it("should render CVV input as disabled", () => {
      getIframeBody()
        .find(`[data-testid=${testIds.cardCVVInputTestId}]`)
        .should("exist")
        .should("have.attr", "disabled");
    });

    it("should not allow typing in card number field", () => {
      getIframeBody()
        .find(`[data-testid=${testIds.cardNoInputTestId}]`)
        .should("have.attr", "disabled")
        .then(() => {
          getIframeBody()
            .find(`[data-testid=${testIds.cardNoInputTestId}]`)
            .should("have.value", "");
        });
    });
  });

  describe("readOnly: false (default)", () => {
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
              { readOnly: false }
            )
          );
          cy.waitForSDKReady();
        });
      });
    });

    it("should render card number input as enabled", () => {
      getIframeBody()
        .find(`[data-testid=${testIds.cardNoInputTestId}]`)
        .should("exist")
        .should("not.have.attr", "disabled");
    });

    it("should render expiry input as enabled", () => {
      getIframeBody()
        .find(`[data-testid=${testIds.expiryInputTestId}]`)
        .should("exist")
        .should("not.have.attr", "disabled");
    });

    it("should render CVV input as enabled", () => {
      getIframeBody()
        .find(`[data-testid=${testIds.cardCVVInputTestId}]`)
        .should("exist")
        .should("not.have.attr", "disabled");
    });

    it("should allow typing in card number field", () => {
      getIframeBody()
        .find(`[data-testid=${testIds.cardNoInputTestId}]`)
        .safeType("4242424242424242");

      getIframeBody()
        .find(`[data-testid=${testIds.cardNoInputTestId}]`)
        .should("have.value", "4242 4242 4242 4242");
    });
  });
});
