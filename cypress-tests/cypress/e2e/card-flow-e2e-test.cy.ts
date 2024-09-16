import * as testIds from "../../../src/Utilities/TestUtils.bs";
import { getClientURL } from "../support/utils";


describe("Card payment flow test", () => {

  const publishableKey=Cypress.env('HYPERSWITCH_PUBLISHABLE_KEY')
  const secretKey=Cypress.env('HYPERSWITCH_SECRET_KEY')
  let getIframeBody : () => Cypress.Chainable<JQuery<HTMLBodyElement>>;
  let iframeSelector =
      "#orca-payment-element-iframeRef-orca-elements-payment-element-payment-element";
  beforeEach(() => {
    getIframeBody = () => cy.iframe(iframeSelector);


    cy.createPaymentIntent(secretKey).then(()=>{
     cy.getGlobalState("clientSecret").then((clientSecret)=>{

      cy.visit(getClientURL(clientSecret,publishableKey));
      });
     
    })
  });


  it("title rendered correctly", () => {
    cy.contains("Hyperswitch Unified Checkout").should("be.visible");
  });

  it("orca-payment-element iframe loaded", () => {
    cy.get(
      "#orca-payment-element-iframeRef-orca-elements-payment-element-payment-element"
    )
      .should("be.visible")
      .its("0.contentDocument")
      .its("body");
  });

  it('should check if cards are saved', () => {
    // Visit the page where the test will be performed
    getIframeBody().find(`[data-testid=${testIds.addNewCardIcon}]`)
    .then($element => {
      if ($element.length > 0) {
        getIframeBody().find('[data-testid=cvvInput]').type('123');
        getIframeBody().get("#submit").click();
        cy.wait(2000);
        cy.contains("Thanks for your order!").should("be.visible");
      } else {
        cy.log(' new card card flow');
      }
    });
  });
});
