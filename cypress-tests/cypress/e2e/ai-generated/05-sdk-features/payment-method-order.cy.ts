/**
 * Payment Method Order Tests
 * Verifies that the paymentMethodOrder option controls the ordering
 * of payment method tabs/accordion items in the payment element.
 */
import * as testIds from "../../../../../src/Utilities/TestUtils.bs";
import {
  getClientURL,
  createPaymentBody,
  changeObjectKeyValue,
} from "../../../support/utils";

describe("PaymentElement paymentMethodOrder Option", () => {
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
      "pm_order_test_user"
    );
    changeObjectKeyValue(
      createPaymentBody,
      "authentication_type",
      "no_three_ds"
    );
  });

  describe("custom payment method order with tabs layout", () => {
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
                paymentMethodOrder: ["card", "klarna", "google_pay"],
              }
            )
          );
          cy.waitForSDKReady();
        });
      });
    });

    it("should render card as the first payment method tab", () => {
      getIframeBody()
        .find(`[data-testid=${testIds.paymentMethodListTestId}]`, {
          timeout: 10000,
        })
        .should("be.visible");

      // The first tab should be the Card tab
      getIframeBody()
        .find(".Tab")
        .first()
        .should("contain.text", "Card");
    });

    it("should render payment methods in the specified order", () => {
      getIframeBody()
        .find(`[data-testid=${testIds.paymentMethodListTestId}]`, {
          timeout: 10000,
        })
        .should("be.visible");

      // Verify tabs exist and card is first
      getIframeBody()
        .find(".Tab")
        .then(($tabs) => {
          const tabTexts = [...$tabs].map((tab) =>
            tab.textContent?.trim().toLowerCase()
          );
          // Card should appear before any other payment method
          const cardIndex = tabTexts.findIndex((text) =>
            text?.includes("card")
          );
          expect(cardIndex).to.equal(0);
        });
    });
  });

  describe("default payment method order (no custom order)", () => {
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

    it("should render payment methods in default order", () => {
      getIframeBody()
        .find(`[data-testid=${testIds.paymentMethodListTestId}]`, {
          timeout: 10000,
        })
        .should("be.visible");

      // At minimum, tabs should render
      getIframeBody().find(".Tab").should("have.length.greaterThan", 0);
    });
  });
});
