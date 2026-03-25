/**
 * Tests for compact saved card view with hideExpiryDate enabled.
 *
 * Prerequisite: Set hideExpiryDate: true in
 * Hyperswitch-React-Demo-App/src/utils.js → paymentElementOptions.layout.savedMethodCustomization
 */
import * as testIds from "../../../src/Utilities/TestUtils.bs";
import { getClientURL, createPaymentBody } from "../support/utils";

describe("Compact saved card view (hideExpiryDate: true)", () => {
  const publishableKey = Cypress.env("HYPERSWITCH_PUBLISHABLE_KEY");
  const secretKey = Cypress.env("HYPERSWITCH_SECRET_KEY");
  let getIframeBody: () => Cypress.Chainable<JQuery<HTMLBodyElement>>;
  let iframeSelector =
    "#orca-payment-element-iframeRef-orca-elements-payment-element-payment-element";

  beforeEach(() => {
    getIframeBody = () => cy.iframe(iframeSelector);
    cy.createPaymentIntent(secretKey, createPaymentBody).then(() => {
      cy.getGlobalState("clientSecret").then((clientSecret) => {
        cy.visit(getClientURL(clientSecret, publishableKey));
      });
    });
  });

  it("expiry date should not be visible on saved cards", () => {
    getIframeBody()
      .find(`[data-testid=${testIds.addNewCardIcon}]`)
      .then(($element) => {
        if ($element.length > 0) {
          // Saved cards exist — verify expiry is hidden
          getIframeBody().contains("Expiry").should("not.exist");
        } else {
          cy.log("No saved cards found, skipping expiry visibility check");
        }
      });
  });

  it("CVC input should be visible on saved card selection", () => {
    getIframeBody()
      .find(`[data-testid=${testIds.addNewCardIcon}]`)
      .then(($element) => {
        if ($element.length > 0) {
          getIframeBody()
            .find(`[data-testid=${testIds.cardCVVInputTestId}]`)
            .should("be.visible");
        } else {
          cy.log("No saved cards found, skipping CVC visibility check");
        }
      });
  });

  it("user can type CVC in compact saved card view", () => {
    getIframeBody()
      .find(`[data-testid=${testIds.addNewCardIcon}]`)
      .then(($element) => {
        if ($element.length > 0) {
          getIframeBody()
            .find(`[data-testid=${testIds.cardCVVInputTestId}]`)
            .type("123")
            .then(() => {
              getIframeBody()
                .find(`[data-testid=${testIds.cardCVVInputTestId}]`)
                .should("have.value", "123");
            });
        } else {
          cy.log("No saved cards found, skipping CVC input check");
        }
      });
  });

  it("should display error when CVC is empty on submit", () => {
    getIframeBody()
      .find(`[data-testid=${testIds.addNewCardIcon}]`)
      .then(($element) => {
        if ($element.length > 0) {
          getIframeBody().get("#submit").click();
          getIframeBody()
            .contains("CVC Number cannot be empty")
            .should("be.visible");
        } else {
          cy.log("No saved cards found, skipping CVC error check");
        }
      });
  });

  it("should complete payment with saved card in compact view", () => {
    getIframeBody()
      .find(`[data-testid=${testIds.addNewCardIcon}]`)
      .then(($element) => {
        if ($element.length > 0) {
          getIframeBody()
            .find(`[data-testid=${testIds.cardCVVInputTestId}]`)
            .type("123");
          getIframeBody().get("#submit").click();
          cy.wait(2000);
          cy.contains("Thanks for your order!").should("be.visible");
        } else {
          cy.log("No saved cards found, skipping payment completion check");
        }
      });
  });
});
