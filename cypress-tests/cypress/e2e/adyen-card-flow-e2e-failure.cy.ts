import * as testIds from "../../../src/Utilities/TestUtils.bs"; 
import {  
  getClientURL,  
  createPaymentBody,  
  changeObjectKeyValue,  
  connectorProfileIdMapping,
  connectorEnum,
  adyenTestCard  
} from "../support/utils";  

describe("Adyen Card payment flow test - Failure Cases", () => {
  const publishableKey = Cypress.env("HYPERSWITCH_PUBLISHABLE_KEY");
  const secretKey = Cypress.env("HYPERSWITCH_SECRET_KEY");
  let getIframeBody: () => Cypress.Chainable<JQuery<HTMLBodyElement>>;
  const iframeSelector = "#orca-payment-element-iframeRef-orca-elements-payment-element-payment-element";

  changeObjectKeyValue(createPaymentBody, "profile_id", connectorProfileIdMapping.get(connectorEnum.ADYEN));

  beforeEach(() => {
    getIframeBody = () => cy.iframe(iframeSelector);
    cy.createPaymentIntent(secretKey, createPaymentBody).then(() => {
      cy.getGlobalState("clientSecret").then((clientSecret) => {
        cy.visit(getClientURL(clientSecret, publishableKey));
      });
    });
  });

  // 1. Verify title is rendered
  it("title rendered correctly", () => {
    cy.contains("Hyperswitch Unified Checkout").should("be.visible");
  });

  // 2. Verify if iframe is loaded
  it("orca-payment-element iframe loaded", () => {
    cy.frameLoaded(iframeSelector);
  });

  // 3. Simulate payment failure
  it("submit payment form and make failed payment", () => {
    getIframeBody().find(`[data-testid=${testIds.addNewCardIcon}]`).click();

    getIframeBody().find(`[data-testid=${testIds.cardNoInputTestId}]`).type(adyenTestCard);
    getIframeBody().find(`[data-testid=${testIds.expiryInputTestId}]`).type("0424");
    getIframeBody().find(`[data-testid=${testIds.cardCVVInputTestId}]`).type("123");

    getIframeBody().find("#submit").click();

    cy.contains("Payment Failed!").should("be.visible");
  });
});
