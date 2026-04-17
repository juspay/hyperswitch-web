export {}; // indicate that file is a module

export type CustomerData = {
  cardNo: string;
  cardExpiry: string;
  cardCVV: string;
  cardHolderName: string;
  email: string;
  address: string;
  city: string;
  country: string;
  state: string;
  postalCode: string;
  threeDSCardNo: string;
};

declare global {
  namespace Cypress {
    interface Chainable {
      enterValueInIframe(
        selector: string,
        value: string,
      ): Chainable<JQuery<HTMLElement>>;
      selectValueInIframe(
        selector: string,
        value: string,
      ): Chainable<JQuery<HTMLElement>>;
      hardReload(): Chainable<JQuery<HTMLElement>>;
      testDynamicFields(
        customerData: CustomerData,
        testIdsToRemoveArr: string[],
        isThreeDSEnabled: boolean,
        publishableKey: string,
      ): Chainable<JQuery<HTMLElement>>;
      createPaymentIntent(
        secretKey: string,
        createPaymentBody: Record<string, any>,
      ): Chainable<Response<any>>;
      getGlobalState(key: string): Chainable<string>;
      nestedIFrame(
        selector: string,
        callback: (body: Chainable<JQuery<HTMLElement>>) => void,
      ): Chainable<void>;
      // New smart wait utilities
      waitForSDKReady(): Chainable<JQuery<HTMLBodyElement>>;
      safeType(text: string, options?: Partial<Cypress.TypeOptions>): Chainable<JQuery<HTMLElement>>;
      safeClick(): Chainable<JQuery<HTMLElement>>;
      enterCardDetails(cardDetails: any): Chainable<void>;
    }
  }
}
