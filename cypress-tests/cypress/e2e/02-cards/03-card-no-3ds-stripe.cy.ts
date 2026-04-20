import * as testIds from "../../../../src/Utilities/TestUtils.bs";
import { getClientURL, createPaymentBody, changeObjectKeyValue } from "../../support/utils";
import { stripeCards } from "../../support/cards";

describe("Stripe Non-3DS Card Payment", () => {
  const publishableKey = Cypress.env("HYPERSWITCH_PUBLISHABLE_KEY");
  const secretKey = Cypress.env("HYPERSWITCH_SECRET_KEY");
  let getIframeBody: () => Cypress.Chainable<JQuery<HTMLBodyElement>>;
  const iframeSelector =
    "#orca-payment-element-iframeRef-orca-elements-payment-element-payment-element";

  changeObjectKeyValue(createPaymentBody, "customer_id", "stripe_no_3ds_test_user");

  beforeEach(() => {
    getIframeBody = () => cy.iframe(iframeSelector);
    cy.createPaymentIntent(secretKey, createPaymentBody).then(() => {
      cy.getGlobalState("clientSecret").then((clientSecret) => {
        cy.visit(getClientURL(clientSecret, publishableKey));
      });
    });
  });

  describe("Successful Payments", () => {
    it("should complete the card payment successfully", () => {
      const { cardNo, card_exp_month, card_exp_year, cvc } = stripeCards.successCard;

      getIframeBody().find(`[data-testid=${testIds.cardNoInputTestId}]`).type(cardNo);
      getIframeBody().find(`[data-testid=${testIds.expiryInputTestId}]`).type(card_exp_month);
      getIframeBody().find(`[data-testid=${testIds.expiryInputTestId}]`).type(card_exp_year);
      getIframeBody().find(`[data-testid=${testIds.cardCVVInputTestId}]`).type(cvc);

      getIframeBody().get("#submit").click();

      cy.contains("Thanks for your order!", { timeout: 10000 }).should("be.visible");
    });
  });

  describe("Validation Errors", () => {
    it("should fail with an invalid card number", () => {
      const { cardNo, card_exp_month, card_exp_year, cvc } = stripeCards.invalidCard;

      getIframeBody().find(`[data-testid=${testIds.cardNoInputTestId}]`).type(cardNo);
      getIframeBody().find(`[data-testid=${testIds.expiryInputTestId}]`).type(card_exp_month);
      getIframeBody().find(`[data-testid=${testIds.expiryInputTestId}]`).type(card_exp_year);
      getIframeBody().find(`[data-testid=${testIds.cardCVVInputTestId}]`).type(cvc);

      getIframeBody().get("#submit").click();

      cy.contains("Please enter valid details", { timeout: 10000 }).should("be.visible");
    });

    it("should show error for expired card year", () => {
      const { cardNo, card_exp_month, cvc } = stripeCards.successCard;

      getIframeBody().find(`[data-testid=${testIds.cardNoInputTestId}]`).type(cardNo);
      getIframeBody().find(`[data-testid=${testIds.expiryInputTestId}]`).type(card_exp_month);
      getIframeBody().find(`[data-testid=${testIds.expiryInputTestId}]`).type("10");
      getIframeBody().find(`[data-testid=${testIds.cardCVVInputTestId}]`).type(cvc);

      getIframeBody().get("#submit").click();

      getIframeBody()
        .find(".Error.pt-1", { timeout: 10000 })
        .should("be.visible")
        .and("contain.text", "Your card's expiration year is in the past.");
    });

    it("should show error for incomplete card CVV", () => {
      const { cardNo, card_exp_month, card_exp_year } = stripeCards.successCard;

      getIframeBody().find(`[data-testid=${testIds.cardNoInputTestId}]`).type(cardNo);
      getIframeBody().find(`[data-testid=${testIds.expiryInputTestId}]`).type(card_exp_month);
      getIframeBody().find(`[data-testid=${testIds.expiryInputTestId}]`).type(card_exp_year);
      getIframeBody().find(`[data-testid=${testIds.cardCVVInputTestId}]`).type("1");

      getIframeBody().get("#submit").click();

      getIframeBody()
        .find(".Error.pt-1", { timeout: 10000 })
        .should("be.visible")
        .and("contain.text", "Your card's security code is incomplete.");
    });
  });
});
