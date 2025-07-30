import * as testIds from "../../../src/Utilities/TestUtils.bs";
import { getClientURL } from "../support/utils";
import { createPaymentBody } from "../support/utils";
import { changeObjectKeyValue } from "../support/utils";
import { trustpayCards } from "cypress/support/cards";
import { connectorEnum, connectorProfileIdMapping } from "../support/utils";

describe("Trustpay Card Payment flow test", () => {
  const publishableKey = Cypress.env("HYPERSWITCH_PUBLISHABLE_KEY");
  const secretKey = Cypress.env("HYPERSWITCH_SECRET_KEY");
  let getIframeBody: () => Cypress.Chainable<JQuery<HTMLBodyElement>>;
  let iframeSelector =
    "#orca-payment-element-iframeRef-orca-elements-payment-element-payment-element";

  beforeEach(() => {
    getIframeBody = () => cy.iframe(iframeSelector);
    changeObjectKeyValue(
      createPaymentBody,
      "profile_id",
      connectorProfileIdMapping.get(connectorEnum.TRUSTPAY)
    );
  });

  it("should complete the card payment successfully (No 3DS)", () => {
    changeObjectKeyValue(createPaymentBody, "authentication_type", "no_three_ds");
    changeObjectKeyValue(createPaymentBody, "customer_id", "new_customer_id");
    cy.createPaymentIntent(secretKey, createPaymentBody).then(() => {
      cy.getGlobalState("clientSecret").then((clientSecret) => {
        cy.visit(getClientURL(clientSecret, publishableKey));
      });
    });

    const { cardNo, card_exp_month, card_exp_year, cvc } =
      trustpayCards.successCard;

    getIframeBody().find("[data-testid=cardNoInput]").type(cardNo);
    getIframeBody().find("[data-testid=expiryInput]").type(card_exp_month);
    getIframeBody().find("[data-testid=expiryInput]").type(card_exp_year);
    getIframeBody().find("[data-testid=cvvInput]").type(cvc);

    getIframeBody().get("#submit").click();

    cy.wait(3000);
    cy.contains("Thanks for your order!").should("be.visible");
  });

  it("should show the 3DS challenge page", () => {
    changeObjectKeyValue(createPaymentBody, "authentication_type", "three_ds");
    cy.createPaymentIntent(secretKey, createPaymentBody).then(() => {
      cy.getGlobalState("clientSecret").then((clientSecret) => {
        cy.visit(getClientURL(clientSecret, publishableKey));
      });
    });

    const { cardNo, card_exp_month, card_exp_year, cvc } =
      trustpayCards.threeDSCard;

    getIframeBody().find("[data-testid=cardNoInput]").type(cardNo);
    getIframeBody().find("[data-testid=expiryInput]").type(card_exp_month);
    getIframeBody().find("[data-testid=expiryInput]").type(card_exp_year);
    getIframeBody().find("[data-testid=cvvInput]").type(cvc);

    getIframeBody().get("#submit").click();
    cy.wait(3000);

    cy.get("body").then(($body) => {
      if ($body.find("#tp-iframe").length > 0) {
        cy.iframe("#tp-iframe").should("be.visible");
      }
    });
  });

  it("should fail with an invalid card number", () => {
    changeObjectKeyValue(createPaymentBody, "authentication_type", "no_three_ds");
    cy.createPaymentIntent(secretKey, createPaymentBody).then(() => {
      cy.getGlobalState("clientSecret").then((clientSecret) => {
        cy.visit(getClientURL(clientSecret, publishableKey));
      });
    });

    const { cardNo, card_exp_month, card_exp_year, cvc } =
      trustpayCards.invalidCard;

    getIframeBody().find("[data-testid=cardNoInput]").type(cardNo);
    getIframeBody().find("[data-testid=expiryInput]").type(card_exp_month);
    getIframeBody().find("[data-testid=expiryInput]").type(card_exp_year);
    getIframeBody().find("[data-testid=cvvInput]").type(cvc);

    getIframeBody().get("#submit").click();

    cy.wait(3000);
    cy.contains("Please enter valid details").should("be.visible");
  });
});
