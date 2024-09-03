import * as testIds from "../../../src/Utilities/TestUtils.bs";
import { CLIENT_URL } from "../support/utils";

describe("Card payment flow test", () => {
  // Define the type for getIframeBody function
  let getIframeBody: () => Cypress.Chainable<JQuery<HTMLBodyElement>>;
  const iframeSelector = "#orca-payment-element-iframeRef-orca-elements-payment-element-payment-element";

  beforeEach(() => {
    // Initialize the getIframeBody function
    getIframeBody = () => cy.iframe(iframeSelector);

    // Visit the page with the payment form
    cy.visit(CLIENT_URL);
  });

  it("page loaded successfully", () => {
    cy.visit(CLIENT_URL);
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
    cy.visit(CLIENT_URL);

    // Wait for iframe to load and get its body
    getIframeBody().find('[data-testid=cardNoInput]').type('4000000000003220'); // Example card number
    getIframeBody().find('[data-testid=expiryInput]').type('12'); // Expiration month
    getIframeBody().find('[data-testid=expiryInput]').type('25'); // Expiration year
    getIframeBody().find('[data-testid=cvvInput]').type('123'); // CVV

    // Click on the submit button
    getIframeBody().get("#submit").click();

    // Wait for the response and assert payment success message
    cy.wait(3000); // Adjust wait time based on actual response time
    cy.url().should('include', 'hooks.stripe.com/3d_secure_2');
  });
});
