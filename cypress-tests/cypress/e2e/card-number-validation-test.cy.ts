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

    it("should fail with an undetectable card brand and invalid card number", () => {
        const { card_exp_month, card_exp_year, cvc } = stripeCards.successCard;

        getIframeBody().find(`[data-testid=${testIds.cardNoInputTestId}]`).type("111111"); 
        getIframeBody().find(`[data-testid=${testIds.expiryInputTestId}]`).type(card_exp_month); 
        getIframeBody().find(`[data-testid=${testIds.expiryInputTestId}]`).type(card_exp_year); 
        getIframeBody().find(`[data-testid=${testIds.cardCVVInputTestId}]`).type(cvc); 

        getIframeBody().get("#submit").click();

        getIframeBody().find('.Error.pt-1').should('be.visible')
        .and('contain.text', "Please enter a valid card number.");       
        getIframeBody().find(`[data-testid=${testIds.cardNoInputTestId}]`).click(); 
        getIframeBody().find('.Error.pt-1').should('not.exist');

    });

    it("should fail with a detectable but invalid card number", () => {
        const { card_exp_month, card_exp_year, cvc } = stripeCards.successCard;
 
        getIframeBody().find(`[data-testid=${testIds.cardNoInputTestId}]`).type("424242"); 
        getIframeBody().find(`[data-testid=${testIds.expiryInputTestId}]`).type(card_exp_month); 
        getIframeBody().find(`[data-testid=${testIds.expiryInputTestId}]`).type(card_exp_year); 
        getIframeBody().find(`[data-testid=${testIds.cardCVVInputTestId}]`).type(cvc); 
 
        getIframeBody().get("#submit").click();
         
        getIframeBody().find('.Error.pt-1').should('be.visible')
        .and('contain.text', "Card number is invalid.");
        getIframeBody().find(`[data-testid=${testIds.cardNoInputTestId}]`).click(); 
        getIframeBody().find('.Error.pt-1').should('not.exist');
    });

    it("should fail with an unsupported card brand (RuPay)", () => {
        const { card_exp_month, card_exp_year, cvc } = stripeCards.successCard;
 
        getIframeBody().find(`[data-testid=${testIds.cardNoInputTestId}]`).type("6082015309577308"); 
        getIframeBody().find(`[data-testid=${testIds.expiryInputTestId}]`).type(card_exp_month); 
        getIframeBody().find(`[data-testid=${testIds.expiryInputTestId}]`).type(card_exp_year); 
        getIframeBody().find(`[data-testid=${testIds.cardCVVInputTestId}]`).type(cvc); 
 
        getIframeBody().get("#submit").click();
        
        getIframeBody().find('.Error.pt-1').should('be.visible')
        .and('contain.text', "RuPay is not supported at the moment.");
        getIframeBody().find(`[data-testid=${testIds.cardNoInputTestId}]`).click(); 
        getIframeBody().find('.Error.pt-1').should('not.exist');
    });

    it("should fail with an empty card number", () => {
        const { card_exp_month, card_exp_year, cvc } = stripeCards.successCard;
 
        getIframeBody().find(`[data-testid=${testIds.expiryInputTestId}]`).type(card_exp_month); 
        getIframeBody().find(`[data-testid=${testIds.expiryInputTestId}]`).type(card_exp_year); 
        getIframeBody().find(`[data-testid=${testIds.cardCVVInputTestId}]`).type(cvc); 
 
        getIframeBody().get("#submit").click();
       
        getIframeBody().find('.Error.pt-1').should('be.visible')
        .and('contain.text', "Card Number cannot be empty");
    });

});
