/**
 * Stripe 3DS Card Payment Tests
 * Tests for 3D Secure authentication with Stripe
 */
import * as testIds from "../../../../src/Utilities/TestUtils.bs";
import { getClientURL, createPaymentBody, changeObjectKeyValue } from "../../support/utils";
import { stripeCards } from "../../support/cards";

describe("Stripe 3DS Card Payment", () => {
  const publishableKey = Cypress.env("HYPERSWITCH_PUBLISHABLE_KEY");
  const secretKey = Cypress.env("HYPERSWITCH_SECRET_KEY");
  let getIframeBody: () => Cypress.Chainable<JQuery<HTMLBodyElement>>;
  const iframeSelector =
    "#orca-payment-element-iframeRef-orca-elements-payment-element-payment-element";

  changeObjectKeyValue(createPaymentBody, "authentication_type", "three_ds");
  changeObjectKeyValue(createPaymentBody, "customer_id", "stripe_3ds_test_user");

  beforeEach(() => {
    getIframeBody = () => cy.iframe(iframeSelector);
    cy.createPaymentIntent(secretKey, createPaymentBody).then(() => {
      cy.getGlobalState("clientSecret").then((clientSecret) => {
        cy.visit(getClientURL(clientSecret, publishableKey));
      });
    });
  });

  it("should complete the 3DS card payment successfully", () => {
    const { cardNo, cvc, card_exp_month, card_exp_year } = stripeCards.threeDSCard;
    
    getIframeBody().find("[data-testid=cardNoInput]").type(cardNo);
    getIframeBody().find("[data-testid=expiryInput]").type(card_exp_month);
    getIframeBody().find("[data-testid=expiryInput]").type(card_exp_year);
    getIframeBody().find("[data-testid=cvvInput]").type(cvc);

    getIframeBody()
      .get("#submit")
      .click()
      .then(() => {
        cy.url().should("include", "hooks.stripe.com/3d_secure_2");
      });
  });

  it("should redirect to 3DS authentication page", () => {
    const { cardNo, cvc, card_exp_month, card_exp_year } = stripeCards.threeDSCard;
    
    getIframeBody().find("[data-testid=cardNoInput]").type(cardNo);
    getIframeBody().find("[data-testid=expiryInput]").type(card_exp_month);
    getIframeBody().find("[data-testid=expiryInput]").type(card_exp_year);
    getIframeBody().find("[data-testid=cvvInput]").type(cvc);

    getIframeBody().get("#submit").click();
    
    cy.wait(3000);
    cy.url().should("include", "stripe.com");
  });
});
