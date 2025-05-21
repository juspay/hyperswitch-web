import * as testIds from "../../../src/Utilities/TestUtils.bs";
import { getClientURL, amexTestCard, visaTestCard, createPaymentBody } from "../support/utils";

describe("Card CVC Checks", () => {
    let getIframeBody: () => Cypress.Chainable<JQuery<HTMLBodyElement>>;
    const publishableKey = Cypress.env('HYPERSWITCH_PUBLISHABLE_KEY')
    const secretKey = Cypress.env('HYPERSWITCH_SECRET_KEY')
    let iframeSelector =
        "#orca-payment-element-iframeRef-orca-elements-payment-element-payment-element";


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
        cy.get(
            "#orca-payment-element-iframeRef-orca-elements-payment-element-payment-element"
        )
            .should("be.visible")
            .its("0.contentDocument")
            .its("body");
    });


    it('user can enter 4 digit cvc in card form', () => {
        cy.wait(2000)
        getIframeBody().find(`[data-testid=${testIds.addNewCardIcon}]`).click()
        getIframeBody().find(`[data-testid=${testIds.cardNoInputTestId}]`).type(amexTestCard)
        getIframeBody().find(`[data-testid=${testIds.expiryInputTestId}]`).type("0444")
        getIframeBody().find(`[data-testid=${testIds.cardCVVInputTestId}]`).type("1234").then(() => {
            getIframeBody().find(`[data-testid=${testIds.cardCVVInputTestId}]`).should('have.value', '1234');
        })


    })

    it('removing cvc and expiry on card brand change or after clearing card number', () => {
        cy.wait(2000)
        getIframeBody().find(`[data-testid=${testIds.addNewCardIcon}]`).click()
        getIframeBody().find(`[data-testid=${testIds.cardNoInputTestId}]`).type(amexTestCard)
        getIframeBody().find(`[data-testid=${testIds.expiryInputTestId}]`).type("0444")
        getIframeBody().find(`[data-testid=${testIds.cardCVVInputTestId}]`).type("2412")
        getIframeBody().find(`[data-testid=${testIds.cardNoInputTestId}]`).clear()
        getIframeBody().find(`[data-testid=${testIds.cardCVVInputTestId}]`).should('have.value', '');
        getIframeBody().find(`[data-testid=${testIds.expiryInputTestId}]`).should('have.value', '');

    })
    
    it('user can enter 3 digit cvc on saved payment methods screen', () => {
        getIframeBody().find(`[data-testid=${testIds.cardCVVInputTestId}]`).type('123').then(() => {
            getIframeBody().find(`[data-testid=${testIds.cardCVVInputTestId}]`).should('have.value', '123');
        })

    })

    it('user can enter 3 digit cvc in card form', () => {
        cy.wait(2000)
        getIframeBody().find(`[data-testid=${testIds.addNewCardIcon}]`).click()
        getIframeBody().find(`[data-testid=${testIds.cardNoInputTestId}]`).type(visaTestCard)
        getIframeBody().find(`[data-testid=${testIds.expiryInputTestId}]`).type("0444")
        getIframeBody().find(`[data-testid=${testIds.cardCVVInputTestId}]`).type("123").then(() => {
            getIframeBody().find(`[data-testid=${testIds.cardCVVInputTestId}]`).should('have.value', '123');
        })
    })

    it('user can enter 4 digit cvc on saved payment methods screen', () => {
        cy.wait(2000)
        getIframeBody()
            .contains('div', '4 digit cvc t..')
            .should('exist')
            .trigger('click')
        cy.wait(1000)

        getIframeBody().find(`[data-testid=${testIds.cardCVVInputTestId}]`).type("1234").then(() => {
            getIframeBody().find(`[data-testid=${testIds.cardCVVInputTestId}]`).should('have.value', '1234');
        })

    })

})




