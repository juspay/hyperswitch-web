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
  let publishableKey: string;
  let secretKey: string;
  let getIframeBody: () => Cypress.Chainable<JQuery<HTMLBodyElement>>;
  const iframeSelector =
    "#orca-payment-element-iframeRef-orca-elements-payment-element-payment-element";

  const customerId = `mandate_cypress_${Date.now()}`;

  const { cardNo, card_exp_month, card_exp_year, cvc } =
    cybersourceCards.successCard;

  beforeEach(() => {
    publishableKey = Cypress.env("HYPERSWITCH_PUBLISHABLE_KEY");
    secretKey = Cypress.env("HYPERSWITCH_SECRET_KEY");
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
  });

  it("should save card with off_session setup and complete first payment", () => {
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

    cy.get("#submit").should("be.visible").click();

    cy.contains("Thanks for your order!", { timeout: 30000 }).should(
      "be.visible"
    );
  });

  it("should use saved card for second payment without CVC (mandate)", () => {
    cy.createPaymentIntent(secretKey, createPaymentBody).then(() => {
      cy.getGlobalState("clientSecret").then((clientSecret) => {
        cy.visit(getClientURL(clientSecret, publishableKey));
      });
    });

    // The saved-card view does not render cardNoInput, so waitForSDKReady()
    // (which waits for cardNoInput) cannot be used here. Wait for the iframe
    // to be visible, then assert the saved card UI is present.
    cy.get(iframeSelector, { timeout: 15000 }).should("be.visible");

    // Verify the saved card from the first payment is present.
    // addNewCardIcon appears when at least one saved card exists.
    getIframeBody()
      .find(`[data-testid=${testIds.addNewCardIcon}]`, { timeout: 20000 })
      .should("be.visible");

    // Card ending in 4242 should be pre-selected
    getIframeBody().contains("4242").should("be.visible");

    // off_session mandate — no CVV input required
    getIframeBody()
      .find("[data-testid=cvvInput]")
      .should("not.exist");

    cy.get("#submit").should("be.visible").click();

    cy.contains("Thanks for your order!", { timeout: 30000 }).should(
      "be.visible"
    );
  });
});
