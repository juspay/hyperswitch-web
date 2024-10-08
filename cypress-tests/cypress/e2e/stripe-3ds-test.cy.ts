import * as testIds from "../../../src/Utilities/TestUtils.bs";
import { getClientURL } from "../support/utils";
import { createPaymentBody } from "../support/utils";
import { changeObjectKeyValue } from "../support/utils";
import { stripeCards } from "cypress/support/cards";

describe("Card payment flow test", () => {

  const publishableKey = Cypress.env('HYPERSWITCH_PUBLISHABLE_KEY')
  const secretKey = Cypress.env('HYPERSWITCH_SECRET_KEY')
  let getIframeBody: () => Cypress.Chainable<JQuery<HTMLBodyElement>>;
  let iframeSelector =
    "#orca-payment-element-iframeRef-orca-elements-payment-element-payment-element";

  changeObjectKeyValue(createPaymentBody,"authentication_type","three_ds")
  changeObjectKeyValue(createPaymentBody,"customer_id","new_user")


  beforeEach(() => {
    getIframeBody = () => cy.iframe(iframeSelector);
    cy.createPaymentIntent(secretKey, createPaymentBody).then(() => {
      cy.getGlobalState("clientSecret").then((clientSecret) => {

        cy.visit(getClientURL(clientSecret, publishableKey));
      });

    })
  });
  
  it("title rendered correctly", () => {
    cy.contains("Hyperswitch Unified Checkout").should("be.visible");
  });

  it("orca-payment-element iframe loaded", () => {
    cy.get(iframeSelector)
      .should("be.visible")
      .its("0.contentDocument")
      .its("body");
  });

  it("should complete the card payment successfully", () => {
    // Visit the page with the payment form
const{ cardNo,cvc, card_exp_month, card_exp_year}=stripeCards.threeDSCard
    // Wait for iframe to load and get its body
    getIframeBody().find('[data-testid=cardNoInput]').type(cardNo); // Example card number
    getIframeBody().find('[data-testid=expiryInput]').type(card_exp_month); // Expiration month
    getIframeBody().find('[data-testid=expiryInput]').type(card_exp_year); // Expiration year
    getIframeBody().find('[data-testid=cvvInput]').type(cvc); // CVV

    // Click on the submit button
    getIframeBody().get("#submit").click();

    // Wait for the response and assert payment success message
    cy.wait(3000); // Adjust wait time based on actual response time
    cy.url().should('include', 'hooks.stripe.com/3d_secure_2');
  });
});

