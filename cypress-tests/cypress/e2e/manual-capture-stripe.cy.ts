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

    getIframeBody().find(`[data-testid=${testIds.cardNoInputTestId}]`).type(cardNo);
    getIframeBody().find(`[data-testid=${testIds.expiryInputTestId}]`).type(card_exp_month);
    getIframeBody().find(`[data-testid=${testIds.expiryInputTestId}]`).type(card_exp_year);
    getIframeBody().find(`[data-testid=${testIds.cardCVVInputTestId}]`).type(cvc);

    cy.wait(2000); // wait for Stripe validation or loading states if needed

    getIframeBody().get("#submit").click();

    cy.contains("Thanks for your order!").should("be.visible");
  });
});
