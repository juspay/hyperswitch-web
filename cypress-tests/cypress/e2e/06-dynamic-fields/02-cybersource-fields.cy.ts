import {
  getClientURL,
  createPaymentBody,
  changeObjectKeyValue,
  removeObjectKey,
  connectorEnum,
  connectorProfileIdMapping,
} from "../../support/utils";
import { cybersourceCards } from "../../support/cards";

describe("Dynamic Fields - Cybersource Connector Test", () => {
  let getIframeBody: () => Cypress.Chainable<JQuery<HTMLBodyElement>>;
  const publishableKey = Cypress.env("HYPERSWITCH_PUBLISHABLE_KEY");
  const secretKey = Cypress.env("HYPERSWITCH_SECRET_KEY");
  const iframeSelector =
    "#orca-payment-element-iframeRef-orca-elements-payment-element-payment-element";

     const billingAddressBody = createPaymentBody.billing.address;

  beforeEach(() => {
    getIframeBody = () => cy.iframe(iframeSelector);
  });

  it("should render billing address fields dynamically and complete payment with Cybersource when billing is not sent in create call", () => {
    // Set Cybersource as the connector
    changeObjectKeyValue(
      createPaymentBody,
      "profile_id",
      connectorProfileIdMapping.get(connectorEnum.CYBERSOURCE),
    );

    // Remove billing address from createPaymentBody to trigger dynamic fields
    removeObjectKey(createPaymentBody, "billing");

    changeObjectKeyValue(
      createPaymentBody,
      "customer_id",
      "new_customer_id",
    );

    changeObjectKeyValue(
      createPaymentBody,
      "authentication_type",
      "no_three_ds",
    );

   changeObjectKeyValue(billingAddressBody, "first_name", "john");
    changeObjectKeyValue(billingAddressBody, "last_name", "doe");
    

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

    // Verify that billing address fields are rendered dynamically
    getIframeBody().find('input[name="line1"]').should("be.visible");
    getIframeBody().find('input[name="city"]').should("be.visible");
    getIframeBody().find('input[name="postal"]').should("be.visible");
    getIframeBody().contains("Billing Details").should("be.visible");

    // Fill in card details
    const { cardNo, card_exp_month, card_exp_year, cvc } =
      cybersourceCards.successCard;

    getIframeBody().find("[data-testid=cardNoInput]").type(cardNo);
    getIframeBody().find("[data-testid=expiryInput]").type(card_exp_month);
    getIframeBody().find("[data-testid=expiryInput]").type(card_exp_year);
    getIframeBody().find("[data-testid=cvvInput]").type(cvc);

    // Fill in dynamic billing address fields
    getIframeBody().find('input[name="line1"]').type("1467 Harrison Street");

    getIframeBody().find('input[name="city"]').type("San Francisco");

    // Fill in postal code
    getIframeBody().find('input[name="postal"]').type("94122");

    // Submit the payment
    getIframeBody().get("#submit").click();

    cy.wait(3000);

    // Verify payment success
    cy.contains("Thanks for your order!").should("be.visible");
  });

  it("should render billing address fields dynamically and fail with invalid card for Cybersource", () => {
    // Set Cybersource as the connector
    changeObjectKeyValue(
      createPaymentBody,
      "profile_id",
      connectorProfileIdMapping.get(connectorEnum.CYBERSOURCE),
    );

    // Remove billing address from createPaymentBody to trigger dynamic fields
    removeObjectKey(createPaymentBody, "billing");

    changeObjectKeyValue(
      createPaymentBody,
      "customer_id",
      "new_customer_id",
    );

    changeObjectKeyValue(
      createPaymentBody,
      "authentication_type",
      "no_three_ds",
    );

    changeObjectKeyValue(createPaymentBody, "first_name", "john");
    changeObjectKeyValue(createPaymentBody, "last_name", "doe");

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

    // Verify that billing address fields are rendered dynamically
    getIframeBody().find('input[name="line1"]').should("be.visible");
    getIframeBody().find('input[name="city"]').should("be.visible");
    getIframeBody().find('input[name="postal"]').should("be.visible");

    // Fill in card details with invalid card
    const { cardNo, card_exp_month, card_exp_year, cvc } =
      cybersourceCards.invalidCard;

    getIframeBody().find("[data-testid=cardNoInput]").type(cardNo);
    getIframeBody().find("[data-testid=expiryInput]").type(card_exp_month);
    getIframeBody().find("[data-testid=expiryInput]").type(card_exp_year);
    getIframeBody().find("[data-testid=cvvInput]").type(cvc);

    // Fill in dynamic billing address fields
    getIframeBody().find('input[name="line1"]').type("1467 Harrison Street");
    getIframeBody().find('input[name="city"]').type("San Francisco");
    getIframeBody().find('input[name="postal"]').type("94122");

    // Submit the payment
    getIframeBody().get("#submit").click();

    cy.wait(3000);

    // Verify payment failure
    cy.contains("Please enter valid details").should("be.visible");
  });
});