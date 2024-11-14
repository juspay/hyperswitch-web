import * as testIds from "../../../src/Utilities/TestUtils.bs";
import { getClientURL } from "../support/utils";
import { createPaymentBody } from "../support/utils";
import { changeObjectKeyValue } from "../support/utils";
import { stripeCards } from "cypress/support/cards";

describe("Card number validation test", () => {

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
        const { cardNo, card_exp_month, card_exp_year, cvc } = stripeCards.successCard;

        getIframeBody().find('[data-testid=cardNoInput]').type(cardNo);
        getIframeBody().find('[data-testid=expiryInput]').type(card_exp_month); 
        getIframeBody().find('[data-testid=expiryInput]').type(card_exp_year); 
        getIframeBody().find('[data-testid=cvvInput]').type(cvc); 

        getIframeBody().get("#submit").click();

        cy.wait(3000); 
        cy.contains("Thanks for your order!").should("be.visible");
    });

    it("should fail with an undetectable card brand", () => {
        const { card_exp_month, card_exp_year, cvc } = stripeCards.successCard;

        getIframeBody().find('[data-testid=cardNoInput]').type("111111"); 
        getIframeBody().find('[data-testid=expiryInput]').type(card_exp_month); 
        getIframeBody().find('[data-testid=expiryInput]').type(card_exp_year); 
        getIframeBody().find('[data-testid=cvvInput]').type(cvc); 

        getIframeBody().get("#submit").click();

        cy.wait(3000); 

        getIframeBody().find('.Error.pt-1').should('be.visible')
        .and('contain.text', "Please enter a valid card number.");
    });

    it("should fail with a detectable but invalid card number", () => {
        const { card_exp_month, card_exp_year, cvc } = stripeCards.successCard;
 
        getIframeBody().find('[data-testid=cardNoInput]').type("424242"); 
        getIframeBody().find('[data-testid=expiryInput]').type(card_exp_month); 
        getIframeBody().find('[data-testid=expiryInput]').type(card_exp_year); 
        getIframeBody().find('[data-testid=cvvInput]').type(cvc); 
 
        getIframeBody().get("#submit").click();
 
        cy.wait(3000); 
 
        getIframeBody().find('.Error.pt-1').should('be.visible')
        .and('contain.text', "Card number is invalid.");
    });

    it("should fail with an unsupported card brand (RuPay)", () => {
        const { card_exp_month, card_exp_year, cvc } = stripeCards.successCard;
 
        getIframeBody().find('[data-testid=cardNoInput]').type("6082015309577308"); 
        getIframeBody().find('[data-testid=expiryInput]').type(card_exp_month); 
        getIframeBody().find('[data-testid=expiryInput]').type(card_exp_year); 
        getIframeBody().find('[data-testid=cvvInput]').type(cvc); 
 
        getIframeBody().get("#submit").click();
 
        cy.wait(3000); 
 
        getIframeBody().find('.Error.pt-1').should('be.visible')
        .and('contain.text', "RuPay is not supported at the moment.");
    });

    it("should fail with an empty card number", () => {
        const { card_exp_month, card_exp_year, cvc } = stripeCards.successCard;
 
        getIframeBody().find('[data-testid=expiryInput]').type(card_exp_month); 
        getIframeBody().find('[data-testid=expiryInput]').type(card_exp_year); 
        getIframeBody().find('[data-testid=cvvInput]').type(cvc); 
 
        getIframeBody().get("#submit").click();
 
        cy.wait(3000); 
 
        getIframeBody().find('.Error.pt-1').should('be.visible')
        .and('contain.text', "Card Number cannot be empty");
    });

});
