import {
  getClientURL,
  createPaymentBody,
  changeObjectKeyValue,
} from "../../support/utils";

describe("Dynamic Fields - Billing Address Test", () => {
  let getIframeBody: () => Cypress.Chainable<JQuery<HTMLBodyElement>>;
  const publishableKey = Cypress.env("HYPERSWITCH_PUBLISHABLE_KEY");
  const secretKey = Cypress.env("HYPERSWITCH_SECRET_KEY");
  const iframeSelector =
    "#orca-payment-element-iframeRef-orca-elements-payment-element-payment-element";

  beforeEach(() => {
    getIframeBody = () => cy.iframe(iframeSelector);
  });

  it("should render billing address fields when billing address is not sent in createPaymentBody", () => {
    // Remove billing address from createPaymentBody using changeObjectKeyValue
    changeObjectKeyValue(
      createPaymentBody,
      "billing",
      {},
    );

     changeObjectKeyValue(
      createPaymentBody,
      "customer_id","new_customer_id"
    );

    cy.createPaymentIntent(secretKey, createPaymentBody).then(() => {
      cy.getGlobalState("clientSecret").then((clientSecret) => {
        cy.visit(getClientURL(clientSecret, publishableKey));
      });
    });

    // Wait for the iframe to load
    cy.get(iframeSelector)
      .should("be.visible")
      .its("0.contentDocument")
      .its("body");

    cy.wait(2000);

    // Verify that billing address fields are rendered
    getIframeBody().find('input[name="line1"]').should("be.visible");
    getIframeBody().find('input[name="city"]').should("be.visible");
    getIframeBody().find('input[name="postal"]').should("be.visible");

    // State and country are dropdowns, check for visibility
    getIframeBody().find('.billing-section').should("be.visible");
    getIframeBody().contains("Billing Details").should("be.visible");
  });
});