import * as testIds from "../../../../src/Utilities/TestUtils.bs";

import {
  getClientURL,
  createPaymentBody,
  changeObjectKeyValue,
  connectorProfileIdMapping,
  connectorEnum,
} from "../../support/utils";
import { adyenCards } from "../../support/cards";

describe("Adyen 3DS Card Payment", () => {
  const publishableKey = Cypress.env("HYPERSWITCH_PUBLISHABLE_KEY");
  const secretKey = Cypress.env("HYPERSWITCH_SECRET_KEY");
  let getIframeBody: () => Cypress.Chainable<JQuery<HTMLBodyElement>>;
  const iframeSelector =
    "#orca-payment-element-iframeRef-orca-elements-payment-element-payment-element";

  changeObjectKeyValue(createPaymentBody, "authentication_type", "three_ds");
  changeObjectKeyValue(createPaymentBody, "customer_id", "adyen_3ds_test_user");
  changeObjectKeyValue(
    createPaymentBody,
    "profile_id",
    connectorProfileIdMapping.get(connectorEnum.ADYEN) ?? "",
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
    cy.get(iframeSelector).should("be.visible");
  });

  it("should redirect to 3DS authentication page", () => {
    const { cardNo, cvc, card_exp_month, card_exp_year } = adyenCards.threeDSCard;

    getIframeBody()
      .find(`[data-testid=${testIds.cardNoInputTestId}]`)
      .type(cardNo);
    getIframeBody()
      .find(`[data-testid=${testIds.expiryInputTestId}]`)
      .type(card_exp_month);
    getIframeBody()
      .find(`[data-testid=${testIds.expiryInputTestId}]`)
      .type(card_exp_year);
    getIframeBody()
      .find(`[data-testid=${testIds.cardCVVInputTestId}]`)
      .type(cvc);

    getIframeBody().get("#submit").click();

    cy.url({ timeout: 15000 }).should("include", "adyen.com");
  });

  it("should complete the 3DS card payment successfully", () => {
    const { cardNo, cvc, card_exp_month, card_exp_year } = adyenCards.threeDSCard;

    getIframeBody()
      .find(`[data-testid=${testIds.cardNoInputTestId}]`)
      .type(cardNo);
    getIframeBody()
      .find(`[data-testid=${testIds.expiryInputTestId}]`)
      .type(card_exp_month);
    getIframeBody()
      .find(`[data-testid=${testIds.expiryInputTestId}]`)
      .type(card_exp_year);
    getIframeBody()
      .find(`[data-testid=${testIds.cardCVVInputTestId}]`)
      .type(cvc);

    getIframeBody()
      .get("#submit")
      .click()
      .then(() => {
        cy.url({ timeout: 15000 }).should("include", "adyen.com");
      });
  });

  it("should complete frictionless 3DS payment without a challenge", () => {
    const { cardNo, cvc, card_exp_month, card_exp_year } = adyenCards.frictionlessCard;

    getIframeBody()
      .find(`[data-testid=${testIds.cardNoInputTestId}]`)
      .type(cardNo);
    getIframeBody()
      .find(`[data-testid=${testIds.expiryInputTestId}]`)
      .type(card_exp_month);
    getIframeBody()
      .find(`[data-testid=${testIds.expiryInputTestId}]`)
      .type(card_exp_year);
    getIframeBody()
      .find(`[data-testid=${testIds.cardCVVInputTestId}]`)
      .type(cvc);

    getIframeBody().get("#submit").click();

    cy.contains("Thanks for your order!", { timeout: 15000 }).should(
      "be.visible",
    );
  });
});
