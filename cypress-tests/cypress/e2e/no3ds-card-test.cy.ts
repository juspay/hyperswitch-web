import * as testIds from "../../../src/Utilities/TestUtils.bs";
import { CLIENT_URL } from "../support/utils";

// Define a type for the getIframeBody function
type GetIframeBody = () => Cypress.Chainable<JQuery<HTMLBodyElement>>;

describe("Card payment flow test", () => {
  let getIframeBody: GetIframeBody;
  const iframeSelector = "#orca-payment-element-iframeRef-orca-elements-payment-element-payment-element";

  before(() => {
    // Initialize the getIframeBody function
    getIframeBody = () => cy.iframe(iframeSelector);
    cy.visit(CLIENT_URL);
  });

  it("orca-payment-element iframe loaded", () => {
    cy.get(iframeSelector)
      .should("be.visible")
      .its("0.contentDocument")
      .its("body");
  });

  it("should complete the card payment successfully", () => {
    // Visit the page with the payment form
    cy.visit(CLIENT_URL);

    // Wait for iframe to load and get its body
    getIframeBody().find('[data-testid=cardNoInput]').type('4242424242424242'); // Example card number
    getIframeBody().find('[data-testid=expiryInput]').type('12'); // Expiration month
    getIframeBody().find('[data-testid=expiryInput]').type('25'); // Expiration year
    getIframeBody().find('[data-testid=cvvInput]').type('123'); // CVV

    // Click on the submit button
    getIframeBody().get("#submit").click();

    // Wait for the response and assert payment success message
    cy.wait(3000); // Adjust wait time based on actual response time
    cy.contains("Thanks for your order!").should("be.visible");
  });

  it("should fail with an invalid card number", () => {
    cy.visit(CLIENT_URL);

    getIframeBody().find('[data-testid=cardNoInput]').type('1234567812345678'); // Invalid card number
    getIframeBody().find('[data-testid=expiryInput]').type('12'); // Expiration month
    getIframeBody().find('[data-testid=expiryInput]').type('25'); // Expiration year
    getIframeBody().find('[data-testid=cvvInput]').type('123'); // CVV

    getIframeBody().get("#submit").click();

    cy.wait(3000); // Adjust wait time based on actual response time
    cy.contains("Please enter valid details").should("be.visible"); // Adjust based on actual error message
  });

  it("should show error for expired card year", () => {
    cy.visit(CLIENT_URL);

    getIframeBody().find('[data-testid=cardNoInput]').type('4242424242424242'); // Valid card number
    getIframeBody().find('[data-testid=expiryInput]').type('12'); // Expiration month
    getIframeBody().find('[data-testid=expiryInput]').type('20'); // Expiration year
    getIframeBody().find('[data-testid=cvvInput]').type('123'); // CVV

    getIframeBody().get("#submit").click();

    cy.wait(3000); // Adjust wait time based on actual response time
    getIframeBody().find('.Error.pt-1').should('be.visible')
      .and('contain.text', "Your card's expiration year is in the past.");
  });

  it("should show error for incomplete card CVV", () => {
    cy.visit(CLIENT_URL);

    getIframeBody().find('[data-testid=cardNoInput]').type('4242424242424242'); // Valid card number
    getIframeBody().find('[data-testid=expiryInput]').type('12'); // Expiration month
    getIframeBody().find('[data-testid=expiryInput]').type('25'); // Expiration year
    getIframeBody().find('[data-testid=cvvInput]').type('12'); // Incomplete CVV

    getIframeBody().get("#submit").click();

    cy.wait(3000); // Adjust wait time based on actual response time
    getIframeBody().find('.Error.pt-1').should('be.visible')
      .and('contain.text', "Your card's security code is incomplete.");
  });
});
