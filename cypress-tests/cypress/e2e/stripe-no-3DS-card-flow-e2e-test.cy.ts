import * as testIds from "../../../src/Utilities/TestUtils.bs";
import { getClientURL } from "../support/utils";
import { createPaymentBody } from "../support/utils";
import { changeObjectKeyValue } from "../support/utils";
import { stripeCards } from "cypress/support/cards";

describe("Card payment flow test", () => {
  const publishableKey = Cypress.env("HYPERSWITCH_PUBLISHABLE_KEY");
  const secretKey = Cypress.env("HYPERSWITCH_SECRET_KEY");
  let getIframeBody: () => Cypress.Chainable<JQuery<HTMLBodyElement>>;
  let iframeSelector =
    "#orca-payment-element-iframeRef-orca-elements-payment-element-payment-element";

  // changeObjectKeyValue(createPaymentBody,"profile_id","YOUR_PROFILE_ID")
  changeObjectKeyValue(createPaymentBody, "customer_id", "new_user");

  beforeEach(() => {
    getIframeBody = () => cy.iframe(iframeSelector);
    cy.createPaymentIntent(secretKey, createPaymentBody).then(() => {
      cy.getGlobalState("clientSecret").then((clientSecret) => {
        cy.visit(getClientURL(clientSecret, publishableKey));
      });
    });
  });

  it("should complete the card payment successfully", () => {
    const { cardNo, card_exp_month, card_exp_year, cvc } =
      stripeCards.successCard;

    getIframeBody().find("[data-testid=cardNoInput]").type(cardNo);
    getIframeBody().find("[data-testid=expiryInput]").type(card_exp_month);
    getIframeBody().find("[data-testid=expiryInput]").type(card_exp_year);
    getIframeBody().find("[data-testid=cvvInput]").type(cvc);

    getIframeBody().get("#submit").click();

    cy.wait(3000);
    cy.contains("Thanks for your order!").should("be.visible");
  });

  it("should fail with an invalid card number", () => {
    const { cardNo, card_exp_month, card_exp_year, cvc } =
      stripeCards.invalidCard;

    getIframeBody().find("[data-testid=cardNoInput]").type(cardNo);
    getIframeBody().find("[data-testid=expiryInput]").type(card_exp_month);
    getIframeBody().find("[data-testid=expiryInput]").type(card_exp_year);
    getIframeBody().find("[data-testid=cvvInput]").type(cvc);

    getIframeBody().get("#submit").click();

    cy.wait(3000);
    cy.contains("Please enter valid details").should("be.visible");
  });

  it("should show error for expired card year", () => {
    const { cardNo, card_exp_month, card_exp_year, cvc } =
      stripeCards.successCard;

    getIframeBody().find("[data-testid=cardNoInput]").type(cardNo);
    getIframeBody().find("[data-testid=expiryInput]").type(card_exp_month);
    getIframeBody().find("[data-testid=expiryInput]").type("10");
    getIframeBody().find("[data-testid=cvvInput]").type(cvc);

    getIframeBody().get("#submit").click();

    cy.wait(3000);
    getIframeBody()
      .find(".Error.pt-1")
      .should("be.visible")
      .and("contain.text", "Your card's expiration year is in the past.");
  });

  it("should show error for incomplete card CVV", () => {
    const { cardNo, card_exp_month, card_exp_year, cvc } =
      stripeCards.successCard;

    getIframeBody().find("[data-testid=cardNoInput]").type(cardNo);
    getIframeBody().find("[data-testid=expiryInput]").type(card_exp_month);
    getIframeBody().find("[data-testid=expiryInput]").type(card_exp_year);
    getIframeBody().find("[data-testid=cvvInput]").type("1");

    getIframeBody().get("#submit").click();

    cy.wait(3000);
    getIframeBody()
      .find(".Error.pt-1")
      .should("be.visible")
      .and("contain.text", "Your card's security code is incomplete.");
  });
});
