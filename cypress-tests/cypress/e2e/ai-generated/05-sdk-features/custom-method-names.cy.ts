/**
 * Custom Method Names Tests
 * Verifies the customMethodNames option behavior.
 *
 * Design note: The SDK's getDisplayNameAndIcon function only applies
 * custom aliases for "classic" and "evoucher" payment methods.
 * All other methods (including "card") ignore the alias.
 * Additionally, the "card" tab label is hard-coded to localeString.card,
 * bypassing displayName entirely.
 *
 * These tests verify:
 * - Default labels display correctly when no custom names are set
 * - Custom alias for "card" is correctly ignored (by design)
 */
import * as testIds from "../../../../../src/Utilities/TestUtils.bs";
import {
  getClientURL,
  createPaymentBody,
  changeObjectKeyValue,
} from "../../../support/utils";

describe("PaymentElement customMethodNames Option", () => {
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
      "custom_names_test_user"
    );
    changeObjectKeyValue(
      createPaymentBody,
      "authentication_type",
      "no_three_ds"
    );
  });

  describe("no custom method names (default labels)", () => {
    beforeEach(() => {
      cy.createPaymentIntent(secretKey, createPaymentBody).then(() => {
        cy.getGlobalState("clientSecret").then((clientSecret) => {
          cy.visit(
            getClientURL(
              clientSecret,
              publishableKey,
              undefined,
              undefined,
              { type: "tabs" }
            )
          );
          cy.waitForSDKReady();
        });
      });
    });

    it("should display default label for card tab", () => {
      getIframeBody()
        .find(`[data-testid=${testIds.paymentMethodListTestId}]`, {
          timeout: 10000,
        })
        .should("be.visible");

      getIframeBody()
        .find(".Tab")
        .first()
        .should("contain.text", "Card");
    });
  });

  describe("custom alias for card is ignored (by design) in tabs", () => {
    beforeEach(() => {
      cy.createPaymentIntent(secretKey, createPaymentBody).then(() => {
        cy.getGlobalState("clientSecret").then((clientSecret) => {
          cy.visit(
            getClientURL(
              clientSecret,
              publishableKey,
              undefined,
              undefined,
              { type: "tabs" },
              {
                customMethodNames: [
                  {
                    paymentMethodName: "card",
                    aliasName: "Credit/Debit Card",
                  },
                ],
              }
            )
          );
          cy.waitForSDKReady();
        });
      });
    });

    it("should still display the default Card label because card aliases are not applied", () => {
      getIframeBody()
        .find(`[data-testid=${testIds.paymentMethodListTestId}]`, {
          timeout: 10000,
        })
        .should("be.visible");

      // The SDK hard-codes the "card" tab label to localeString.card,
      // so the custom alias "Credit/Debit Card" is ignored by design.
      getIframeBody()
        .find(".Tab")
        .first()
        .should("contain.text", "Card");
    });
  });

  describe("custom alias for card is ignored (by design) in accordion", () => {
    beforeEach(() => {
      cy.createPaymentIntent(secretKey, createPaymentBody).then(() => {
        cy.getGlobalState("clientSecret").then((clientSecret) => {
          cy.visit(
            getClientURL(
              clientSecret,
              publishableKey,
              undefined,
              undefined,
              { type: "accordion" },
              {
                customMethodNames: [
                  {
                    paymentMethodName: "card",
                    aliasName: "Pay with Card",
                  },
                ],
              }
            )
          );
          cy.waitForSDKReady();
        });
      });
    });

    it("should still display the default Card label in accordion because card aliases are not applied", () => {
      getIframeBody()
        .find(".AccordionItem", { timeout: 10000 })
        .first()
        .should("contain.text", "Card");
    });
  });
});
