import * as testIds from "../../../src/Utilities/TestUtils.bs";
import { getClientURL, createPaymentBody, changeObjectKeyValue } from "../support/utils";
import { stripeCards } from "cypress/support/cards";

describe("Manual Capture - Stripe Card Payment", () => {
  const publishableKey = Cypress.env("HYPERSWITCH_PUBLISHABLE_KEY");
  const secretKey = Cypress.env("HYPERSWITCH_SECRET_KEY");
  let getIframeBody: () => Cypress.Chainable<JQuery<HTMLBodyElement>>;
  const iframeSelector =
    "#orca-payment-element-iframeRef-orca-elements-payment-element-payment-element";

  beforeEach(() => {
    getIframeBody = () => cy.iframe(iframeSelector);

    // Set a unique customer_id or use "manual_capture_user"
    changeObjectKeyValue(createPaymentBody, "customer_id", "manual_capture_user");

    // Enable manual capture
    changeObjectKeyValue(createPaymentBody, "capture_method", "manual");

    cy.createPaymentIntent(secretKey, createPaymentBody).then(() => {
      cy.getGlobalState("clientSecret").then((clientSecret) => {
        cy.visit(getClientURL(clientSecret, publishableKey));
      });
    });
  });

 it("should successfully process a Stripe card with manual capture enabled", () => {
  const { cardNo, card_exp_month, card_exp_year, cvc } = stripeCards.successCard;

  // Add .should("be.visible") to ensure elements are interactable
  getIframeBody()
    .find(`[data-testid=${testIds.cardNoInputTestId}]`)
    .should("be.visible")
    .type(cardNo);

  getIframeBody()
    .find(`[data-testid=${testIds.expiryInputTestId}]`)
    .should("be.visible")
    .type(card_exp_month)
    .type(card_exp_year);

  getIframeBody()
    .find(`[data-testid=${testIds.cardCVVInputTestId}]`)
    .should("be.visible")
    .type(cvc);

  cy.wait(1000); // Optional wait for UI stability
  getIframeBody().get("#submit").click();

  cy.log("Waiting for success message...");

  // Increased timeout and fallback logs
  cy.contains("Thanks for your order!", { timeout: 10000 }).should("be.visible");

  cy.get("body").then(($body) => {
    if (!$body.text().includes("Thanks for your order!")) {
      cy.log("Page content: ", $body.text());
    }
  });
});

