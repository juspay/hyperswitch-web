import { getClientURL, createPaymentBody, deleteObjectKey, changeObjectKeyValue, generateRandomString, connectorProfileIdMapping, connectorEnum } from "../support/utils";

describe("Dynamic Field Test", () => {
    let getIframeBody;
    let globalClientSecret;
    const publishableKey = Cypress.env('HYPERSWITCH_PUBLISHABLE_KEY');
    const secretKey = Cypress.env('HYPERSWITCH_SECRET_KEY');
    const iframeSelector = "#orca-payment-element-iframeRef-orca-elements-payment-element-payment-element";
        changeObjectKeyValue(createPaymentBody, "profile_id", connectorProfileIdMapping.get(connectorEnum.TRUSTPAY))
    deleteObjectKey(createPaymentBody, "billing");
    changeObjectKeyValue(createPaymentBody, "customer_id", `hyperswitch_sdk_demo_id${generateRandomString()}`);
    
    beforeEach(() => {
        getIframeBody = () => cy.iframe(iframeSelector);
        cy.createPaymentIntent(secretKey, createPaymentBody).then(() => {
            cy.getGlobalState("clientSecret").then((clientSecret) => {
                globalClientSecret = clientSecret;
                cy.visit(getClientURL(clientSecret, publishableKey));
            });
        });
    });

    it("should check that required address fields are set null for payment_method_type as 'debit'", () => {
        cy.intercept('GET', `https://sandbox.hyperswitch.io/account/payment_methods?client_secret=${globalClientSecret}`).as('getPaymentMethods');
        cy.wait('@getPaymentMethods').then(({ response }) => {
            expect(response.statusCode).to.eq(200);
            
            const paymentMethods = response.body.payment_methods;
            
            const debitMethod = paymentMethods.find(method => 
                method.payment_method_types.some(type => type.payment_method_type === 'debit')
            );

            const paypalMethod = paymentMethods.find(method => 
                method.payment_method_types.some(type => type.payment_method_type === 'paypal')
            );

            expect(debitMethod).to.not.be.undefined;
            
            const debitRequiredFields = debitMethod.payment_method_types.find(type => type.payment_method_type === 'debit').required_fields;
            

            expect(debitRequiredFields).to.have.property('billing.address.country');
            expect(debitRequiredFields['billing.address.country'].value).to.be.null;

            expect(debitRequiredFields).to.have.property('billing.address.line1');
            expect(debitRequiredFields['billing.address.line1'].value).to.be.null;

            expect(debitRequiredFields).to.have.property('billing.address.zip');
            expect(debitRequiredFields['billing.address.zip'].value).to.be.null;

            expect(debitRequiredFields).to.have.property('billing.address.last_name');
            expect(debitRequiredFields['billing.address.last_name'].value).to.be.null;

            expect(debitRequiredFields).to.have.property('billing.address.city');
            expect(debitRequiredFields['billing.address.city'].value).to.be.null;


        });
    });
});
