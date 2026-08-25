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
    pollPaymentStatus(
      secretKey: string,
      paymentId: string,
      expectedStatus: string,
      options?: { timeoutMs?: number; intervalMs?: number },
    ): Chainable<any>;
  }
}
