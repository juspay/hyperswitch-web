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

  // changeObjectKeyValue(createPaymentBody,"profile_id","YOUR_PROFILE_ID")
   changeObjectKeyValue(createPaymentBody,"customer_id","new_user")


  beforeEach(() => {
    getIframeBody = () => cy.iframe(iframeSelector);
    cy.createPaymentIntent(secretKey, createPaymentBody).then(() => {
      cy.getGlobalState("clientSecret").then((clientSecret) => {

        cy.visit(getClientURL(clientSecret, publishableKey));
      });

    })
  });

it("should complete the card payment successfully", () => {
    // Visit the page with the payment form
    //cy.visit(CLIENT_URL);
    const { cardNo, card_exp_month, card_exp_year, cvc } = stripeCards.successCard;

    // Wait for iframe to load and get its body
    getIframeBody().find('[data-testid=cardNoInput]').type(cardNo); // Example card number
    getIframeBody().find('[data-testid=expiryInput]').type(card_exp_month); // Expiration month
    getIframeBody().find('[data-testid=expiryInput]').type(card_exp_year); // Expiration year
    getIframeBody().find('[data-testid=cvvInput]').type(cvc); // CVV

    // Click on the submit button
    getIframeBody().get("#submit").click();

    // Wait for the response and assert payment success message
    cy.wait(3000); // Adjust wait time based on actual response time
    cy.contains("Thanks for your order!").should("be.visible");
  });


  it("should fail with an invalid card number", () => {
   // cy.visit(CLIENT_URL);
   const { cardNo, card_exp_month, card_exp_year, cvc } = stripeCards.invalidCard;

    getIframeBody().find('[data-testid=cardNoInput]').type(cardNo); // Invalid card number
    getIframeBody().find('[data-testid=expiryInput]').type(card_exp_month); // Expiration month
    getIframeBody().find('[data-testid=expiryInput]').type(card_exp_year); // Expiration year
    getIframeBody().find('[data-testid=cvvInput]').type(cvc); // CVV

    getIframeBody().get("#submit").click();

    cy.wait(3000); // Adjust wait time based on actual response time
    cy.contains("Please enter valid details").should("be.visible"); // Adjust based on actual error message
  });

  it("should show error for expired card year", () => {
    //cy.visit(CLIENT_URL);
    const { cardNo, card_exp_month, card_exp_year, cvc } = stripeCards.invalidYear;

    getIframeBody().find('[data-testid=cardNoInput]').type(cardNo); // Valid card number
    getIframeBody().find('[data-testid=expiryInput]').type(card_exp_month); // Expiration month
    getIframeBody().find('[data-testid=expiryInput]').type(card_exp_year); // Expiration year
    getIframeBody().find('[data-testid=cvvInput]').type(cvc); // CVV

    getIframeBody().get("#submit").click();

    cy.wait(3000); // Adjust wait time based on actual response time
    getIframeBody().find('.Error.pt-1').should('be.visible')
      .and('contain.text', "Your card's expiration year is in the past.");
  });

  it("should show error for incomplete card CVV", () => {
    //cy.visit(CLIENT_URL);
    const{ cardNo, card_exp_month , card_exp_year ,cvc}=stripeCards.invalidCVC

    getIframeBody().find('[data-testid=cardNoInput]').type(cardNo); // Valid card number
    getIframeBody().find('[data-testid=expiryInput]').type(card_exp_month); // Expiration month
    getIframeBody().find('[data-testid=expiryInput]').type(card_exp_year); // Expiration year
    getIframeBody().find('[data-testid=cvvInput]').type(cvc); // Incomplete CVV

    getIframeBody().get("#submit").click();

    cy.wait(3000); // Adjust wait time based on actual response time
    getIframeBody().find('.Error.pt-1').should('be.visible')
      .and('contain.text', "Your card's security code is incomplete.");
  });

});
