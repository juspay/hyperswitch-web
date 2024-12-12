import * as testIds from "../../../src/Utilities/TestUtils.bs";
import {
  getClientURL,
  createPaymentBody,
  changeObjectKeyValue,
  connectorProfileIdMapping,
  connectorEnum,
  adyenTestCardDetails,
} from "../support/utils";

describe("Adyen Card payment flow test", () => {
  const publishableKey = Cypress.env("HYPERSWITCH_PUBLISHABLE_KEY");
  const secretKey = Cypress.env("HYPERSWITCH_SECRET_KEY");
  let getIframeBody: () => Cypress.Chainable<JQuery<HTMLBodyElement>>;
  const iframeSelector =
    "#orca-payment-element-iframeRef-orca-elements-payment-element-payment-element";
  const adyenIframeSelector = ".adyen-checkout__iframe--threeDSIframe";

  changeObjectKeyValue(
    createPaymentBody,
    "profile_id",
    connectorProfileIdMapping.get(connectorEnum.ADYEN)
  );

  beforeEach(() => {
    getIframeBody = () => cy.iframe(iframeSelector);
    cy.createPaymentIntent(secretKey, createPaymentBody).then(() => {
      cy.getGlobalState("clientSecret").then((clientSecret) => {
        cy.visit(getClientURL(clientSecret, publishableKey));
      });
    });
  });

  it("title rendered correctly", () => {
    cy.contains("Hyperswitch Unified Checkout").should("be.visible");
  });

  it("orca-payment-element iframe loaded", () => {
    cy.frameLoaded(iframeSelector);
  });

  it("submit payment form and make successful payment", () => {
    getIframeBody().find(`[data-testid=${testIds.addNewCardIcon}]`).click();
    getIframeBody()
      .find(`[data-testid=${testIds.cardNoInputTestId}]`)
      .type(adyenTestCardDetails.cardNumber);
    getIframeBody()
      .find(`[data-testid=${testIds.expiryInputTestId}]`)
      .type(adyenTestCardDetails.expiryDate);
    getIframeBody()
      .find(`[data-testid=${testIds.cardCVVInputTestId}]`)
      .type(adyenTestCardDetails.cvv);

    getIframeBody().get("#submit").click();

    cy.contains("Thanks for your order!").should("be.visible");
  });
});
