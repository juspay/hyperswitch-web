import * as testIds from "../../../src/Utilities/TestUtils.bs";
import { getClientURL, netceteraChallengeTestCard, createPaymentBody, changeObjectKeyValue, connectorProfileIdMapping, connectorEnum } from "../support/utils";
describe("External 3DS using Netcetera Checks", () => {
    let getIframeBody: () => Cypress.Chainable<JQuery<HTMLBodyElement>>;
    const publishableKey = Cypress.env('HYPERSWITCH_PUBLISHABLE_KEY')
    const secretKey = Cypress.env('HYPERSWITCH_SECRET_KEY')
    changeObjectKeyValue(createPaymentBody, "profile_id", connectorProfileIdMapping.get(connectorEnum.NETCETERA))
    changeObjectKeyValue(createPaymentBody, "request_external_three_ds_authentication", true)
    changeObjectKeyValue(createPaymentBody, "authentication_type", "three_ds")
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


    it('If the user completes the challenge, the payment should be successful.', () => {
        cy.wait(2000)
        getIframeBody().find(`[data-testid=${testIds.addNewCardIcon}]`).click()
        getIframeBody().find(`[data-testid=${testIds.cardNoInputTestId}]`).type(netceteraChallengeTestCard)
        getIframeBody().find(`[data-testid=${testIds.expiryInputTestId}]`).type("0444")
        cy.wait(1000)
        getIframeBody().find(`[data-testid=${testIds.cardCVVInputTestId}]`).type("1234")
        getIframeBody().get("#submit").click();
        cy.wait(4000)

        cy.nestedIFrame("#threeDsAuthFrame", ($body) => {
            cy.wrap($body).find('#otp')
                .type('1234')

            cy.wrap($body).find('#sendOtp')
                .click()
            cy.contains("Thanks for your order!").should("be.visible");
        })

    })

    it('If the user closes the challenge, the payment should fail.', () => {
        cy.wait(2000)
        getIframeBody().find(`[data-testid=${testIds.addNewCardIcon}]`).click()
        getIframeBody().find(`[data-testid=${testIds.cardNoInputTestId}]`).type(netceteraChallengeTestCard)
        getIframeBody().find(`[data-testid=${testIds.expiryInputTestId}]`).type("0444")
        cy.wait(1000)
        getIframeBody().find(`[data-testid=${testIds.cardCVVInputTestId}]`).type("1234")
        getIframeBody().get("#submit").click();
        cy.wait(4000)

        cy.nestedIFrame("#threeDsAuthFrame", ($body) => {
            cy.wrap($body)
                .find('#cancel')
                .click()
            cy.contains("Payment Failed!").should("be.visible");
        })
    })


})




