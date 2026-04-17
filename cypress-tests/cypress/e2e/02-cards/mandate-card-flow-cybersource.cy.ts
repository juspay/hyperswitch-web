/**
 * Mandate Card Flow - Cybersource
 * Tests the mandate (off_session) card saving and reuse flow:
 *
 * Flow:
 * 1. First payment: Enter card details with setup_future_usage: "off_session"
 *    - Check "Save card details" checkbox
 *    - Complete payment successfully
 * 2. Second payment: Same customer_id with setup_future_usage: "off_session"
 *    - Saved card payment sheet should appear
 *    - No CVC input required (mandate/off_session)
 *    - Complete payment using saved card
 */
import * as testIds from "../../../../src/Utilities/TestUtils.bs";
import {
  getClientURL,
  createPaymentBody,
  changeObjectKeyValue,
  connectorProfileIdMapping,
  connectorEnum,
} from "../../support/utils";
import { cybersourceCards } from "../../support/cards";

describe("Mandate Card Flow - Cybersource", () => {
  const publishableKey = Cypress.env("HYPERSWITCH_PUBLISHABLE_KEY");
  const secretKey = Cypress.env("HYPERSWITCH_SECRET_KEY");
  let getIframeBody: () => Cypress.Chainable<JQuery<HTMLBodyElement>>;
  const iframeSelector =
    "#orca-payment-element-iframeRef-orca-elements-payment-element-payment-element";

  const customerId = `mandate_cypress_${Date.now()}`;

  const { cardNo, card_exp_month, card_exp_year, cvc } =
    cybersourceCards.successCard;

  it("should save card with off_session setup and complete first payment", () => {
    getIframeBody = () => cy.iframe(iframeSelector);

    changeObjectKeyValue(
      createPaymentBody,
      "profile_id",
      connectorProfileIdMapping.get(connectorEnum.CYBERSOURCE)
    );
    changeObjectKeyValue(
      createPaymentBody,
      "authentication_type",
      "no_three_ds"
    );
    changeObjectKeyValue(createPaymentBody, "customer_id", customerId);
    changeObjectKeyValue(
      createPaymentBody,
      "setup_future_usage",
      "off_session"
    );

    cy.createPaymentIntent(secretKey, createPaymentBody).then(() => {
      cy.getGlobalState("clientSecret").then((clientSecret) => {
        cy.visit(getClientURL(clientSecret, publishableKey));
      });
    });

    cy.waitForSDKReady();

    getIframeBody()
      .find(`[data-testid=${testIds.cardNoInputTestId}]`)
      .safeType(cardNo);

    getIframeBody()
      .find(`[data-testid=${testIds.expiryInputTestId}]`)
      .safeType(card_exp_month + card_exp_year);

    getIframeBody()
      .find(`[data-testid=${testIds.cardCVVInputTestId}]`)
      .safeType(cvc);

    getIframeBody()
      .find('[role="checkbox"][aria-label="Select to save card details"]', {
        timeout: 10000,
      })
      .should("be.visible")
      .click();

    getIframeBody()
      .find('[role="checkbox"][aria-checked="true"]')
      .should("exist");

    cy.get("#submit").click();

    cy.contains("Thanks for your order!", { timeout: 30000 }).should(
      "be.visible"
    );
  });

  it("should use saved card for second payment without CVC (mandate)", () => {
    getIframeBody = () => cy.iframe(iframeSelector);

    changeObjectKeyValue(
      createPaymentBody,
      "profile_id",
      connectorProfileIdMapping.get(connectorEnum.CYBERSOURCE)
    );
    changeObjectKeyValue(
      createPaymentBody,
      "authentication_type",
      "no_three_ds"
    );
    changeObjectKeyValue(createPaymentBody, "customer_id", customerId);
    changeObjectKeyValue(
      createPaymentBody,
      "setup_future_usage",
      "off_session"
    );

    cy.createPaymentIntent(secretKey, createPaymentBody).then(() => {
      cy.getGlobalState("clientSecret").then((clientSecret) => {
        cy.visit(getClientURL(clientSecret, publishableKey));
      });
    });

    cy.waitForSDKReady();

    getIframeBody()
      .find(`[data-testid=${testIds.addNewCardIcon}]`, { timeout: 20000 })
      .should("be.visible");

    getIframeBody().contains("4242").should("be.visible");

    getIframeBody()
      .find("[data-testid=cvvInput]")
      .should("not.exist");

    cy.get("#submit").click();

    cy.contains("Thanks for your order!", { timeout: 30000 }).should(
      "be.visible"
    );
  });
});
