import { getClientURL, createPaymentBodyWithoutBillingAddress } from "../support/utils";

describe("Dynamic Field Test", () => {
    let getIframeBody;
    let globalClientSecret;
    const publishableKey = Cypress.env('HYPERSWITCH_PUBLISHABLE_KEY');
    const secretKey = Cypress.env('HYPERSWITCH_SECRET_KEY');
    const iframeSelector = "#orca-payment-element-iframeRef-orca-elements-payment-element-payment-element";

    beforeEach(() => {
        getIframeBody = () => cy.iframe(iframeSelector);
        cy.createPaymentIntent(secretKey, createPaymentBodyWithoutBillingAddress).then(() => {
            cy.getGlobalState("clientSecret").then((clientSecret) => {
                globalClientSecret = clientSecret;
                cy.visit(getClientURL(clientSecret, publishableKey));
            });
        });
    });

    it("should check that required address fields are set null for 'payment_method_type' = 'debit'", () => {
        cy.intercept('GET', `https://sandbox.hyperswitch.io/account/payment_methods?client_secret=${globalClientSecret}`).as('getPaymentMethods');
        
        cy.wait('@getPaymentMethods').then(({ response }) => {
            expect(response.statusCode).to.eq(200);
            
            const paymentMethods = response.body.payment_methods;
            
            const debitMethod = paymentMethods.find(method => 
                method.payment_method_types.some(type => type.payment_method_type === 'debit')
            );

            expect(debitMethod).to.not.be.undefined;
            
            const requiredFields = debitMethod.payment_method_types.find(type => type.payment_method_type === 'debit').required_fields;
            
            expect(requiredFields).to.have.property('billing.address.state');
            expect(requiredFields['billing.address.state'].value).to.be.null;

            expect(requiredFields).to.have.property('billing.address.country');
            expect(requiredFields['billing.address.country'].value).to.be.null;

            expect(requiredFields).to.have.property('billing.address.line1');
            expect(requiredFields['billing.address.line1'].value).to.be.null;

            expect(requiredFields).to.have.property('billing.address.zip');
            expect(requiredFields['billing.address.zip'].value).to.be.null;

            expect(requiredFields).to.have.property('billing.address.last_name');
            expect(requiredFields['billing.address.last_name'].value).to.be.null;

            expect(requiredFields).to.have.property('billing.address.city');
            expect(requiredFields['billing.address.city'].value).to.be.null;

        });
    });
});
