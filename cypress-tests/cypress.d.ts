declare namespace Cypress {
  interface Chainable {
    selectPaymentMethod(
      getIframeBody: () => Chainable<JQuery<HTMLBodyElement>>,
      methodName: string,
    ): Chainable<void>;
    selectPaymentMethodOrSkip(
      getIframeBody: () => Chainable<JQuery<HTMLBodyElement>>,
      methodName: string,
    ): Chainable<boolean>;
  }
}
