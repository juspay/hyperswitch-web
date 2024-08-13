
export {}; // indicate that file is a module

export type CustomerData = {
    cardNo: string
    cardExpiry: string
    cardCVV: string
    cardHolderName: string
    email: string
    address: string
    city: string
    country: string
    state: string
    postalCode: string
    threeDSCardNo: string
}

declare global {
    namespace Cypress {
        interface Chainable {
            enterValueInIframe(selector: string, value: string): Chainable<JQuery<HTMLElement>>
            selectValueInIframe(selector: string, value: string): Chainable<JQuery<HTMLElement>>
            hardReload(): Chainable<JQuery<HTMLElement>>
            testDynamicFields(
                customerData: CustomerData, testIdsToRemoveArr: string[], isThreeDSEnabled: boolean
            ): Chainable<JQuery<HTMLElement>>
            createPaymentIntent(): Chainable<Response<any>>
            getGlobalState(key: number): Chainable<Response<any>>
        }
    }
}