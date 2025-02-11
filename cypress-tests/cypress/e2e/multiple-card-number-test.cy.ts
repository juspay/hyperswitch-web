import * as testIds from "../../../src/Utilities/TestUtils.bs";
import { getClientURL } from "../support/utils";
import { createPaymentBody } from "../support/utils";
import { changeObjectKeyValue } from "../support/utils";
import {  stripeCards } from "cypress/support/cards";

describe("Multiple Card number validation test", () => {

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


    it("19 digit unionpay card", () => {
        const { cardNo, card_exp_month, card_exp_year, cvc } = stripeCards.unionPay19;
    
        getIframeBody().find(`[data-testid=${testIds.cardNoInputTestId}]`).type(cardNo); 
        getIframeBody().find(`[data-testid=${testIds.expiryInputTestId}]`).type(card_exp_month); 
        getIframeBody().find(`[data-testid=${testIds.expiryInputTestId}]`).type(card_exp_year); 
        getIframeBody().find(`[data-testid=${testIds.cardCVVInputTestId}]`).type(cvc); 
        cy.wait(2000);
    
        getIframeBody().get("#submit").click();
    
        
        cy.contains("Thanks for your order!").should("be.visible");
      });


      it("16 digit master card", () => {
        const { cardNo, card_exp_month, card_exp_year, cvc } = stripeCards.masterCard16;
    
        getIframeBody().find(`[data-testid=${testIds.cardNoInputTestId}]`).type(cardNo); 
        getIframeBody().find(`[data-testid=${testIds.expiryInputTestId}]`).type(card_exp_month); 
        getIframeBody().find(`[data-testid=${testIds.expiryInputTestId}]`).type(card_exp_year); 
        getIframeBody().find(`[data-testid=${testIds.cardCVVInputTestId}]`).type(cvc); 
    
        getIframeBody().get("#submit").click();
    
        
        cy.contains("Thanks for your order!").should("be.visible");
      });

      it("15 digit american express card", () => {
        const { cardNo, card_exp_month, card_exp_year, cvc } = stripeCards.amexCard15;
    
        getIframeBody().find(`[data-testid=${testIds.cardNoInputTestId}]`).type(cardNo); 
        getIframeBody().find(`[data-testid=${testIds.expiryInputTestId}]`).type(card_exp_month); 
        getIframeBody().find(`[data-testid=${testIds.expiryInputTestId}]`).type(card_exp_year); 
        getIframeBody().find(`[data-testid=${testIds.cardCVVInputTestId}]`).type(cvc); 
    
        getIframeBody().get("#submit").click();
    
        
        cy.contains("Thanks for your order!").should("be.visible");
      });

      it("14 digit diners club card", () => {
        const { cardNo, card_exp_month, card_exp_year, cvc } = stripeCards.dinersClubCard14;
    
        getIframeBody().find(`[data-testid=${testIds.cardNoInputTestId}]`).type(cardNo); 
        getIframeBody().find(`[data-testid=${testIds.expiryInputTestId}]`).type(card_exp_month); 
        getIframeBody().find(`[data-testid=${testIds.expiryInputTestId}]`).type(card_exp_year); 
        getIframeBody().find(`[data-testid=${testIds.cardCVVInputTestId}]`).type(cvc); 
    
        getIframeBody().get("#submit").click();
    
        
        cy.contains("Thanks for your order!").should("be.visible");
      });

});