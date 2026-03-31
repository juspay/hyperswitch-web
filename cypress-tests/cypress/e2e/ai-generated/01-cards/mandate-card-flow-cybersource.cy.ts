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
import * as testIds from "../../../../../src/Utilities/TestUtils.bs";
import {
  getClientURL,
  createPaymentBody,
  changeObjectKeyValue,
  connectorProfileIdMapping,
  connectorEnum,
} from "../../../support/utils";
import { cybersourceCards } from "../../../support/cards";

describe("Mandate Card Flow - Cybersource", () => {
  const publishableKey = Cypress.env("HYPERSWITCH_PUBLISHABLE_KEY");
  const secretKey = Cypress.env("HYPERSWITCH_SECRET_KEY");
  let getIframeBody: () => Cypress.Chainable<JQuery<HTMLBodyElement>>;
  const iframeSelector =
    "#orca-payment-element-iframeRef-orca-elements-payment-element-payment-element";

  // Generate a unique customer ID for this test run to ensure isolation
  const customerId = `mandate_cypress_${Date.now()}`;

  const { cardNo, card_exp_month, card_exp_year, cvc } =
    cybersourceCards.successCard;

  it("should save card with off_session setup and complete first payment", () => {
    getIframeBody = () => cy.iframe(iframeSelector);

    // Configure payment body for Cybersource with off_session mandate
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

    // Enter card details
    getIframeBody()
      .find(`[data-testid=${testIds.cardNoInputTestId}]`)
      .safeType(cardNo);

    getIframeBody()
      .find(`[data-testid=${testIds.expiryInputTestId}]`)
      .safeType(card_exp_month + card_exp_year);

    getIframeBody()
      .find(`[data-testid=${testIds.cardCVVInputTestId}]`)
      .safeType(cvc);

    // Check the "Save card details" checkbox
    // The checkbox has role="checkbox" and aria-label for state
    getIframeBody()
      .find('[role="checkbox"][aria-label="Select to save card details"]', {
        timeout: 10000,
      })
      .should("be.visible")
      .click();

    // Verify checkbox is now checked
    getIframeBody()
      .find('[role="checkbox"][aria-checked="true"]')
      .should("exist");

    // Submit payment — #submit is in the main document (demo app), not inside the iframe
    cy.get("#submit").click();

    // Verify first payment success
    cy.contains("Thanks for your order!", { timeout: 30000 }).should(
      "be.visible"
    );
  });

  it("should use saved card for second payment without CVC (mandate)", () => {
    getIframeBody = () => cy.iframe(iframeSelector);

    // Configure second payment with same customer_id and setup_future_usage: off_session
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

    // Verify we're on the saved card payment sheet by checking for "Add new payment method"
    // The addNewCardIcon test ID indicates saved cards are available
    getIframeBody()
      .find(`[data-testid=${testIds.addNewCardIcon}]`, { timeout: 20000 })
      .should("be.visible");

    // Verify a saved card with last 4 digits is visible
    getIframeBody().contains("4242").should("be.visible");

    // For mandate/off_session saved cards, CVC input should NOT be required.
    // Verify no CVC input is visible on the saved card payment sheet.
    getIframeBody()
      .find("[data-testid=cvvInput]")
      .should("not.exist");

    // Click pay button directly — no CVC needed for mandate flow
    // #submit is in the main document (demo app), not inside the iframe
    cy.get("#submit").click();

    // Verify second payment success
    cy.contains("Thanks for your order!", { timeout: 30000 }).should(
      "be.visible"
    );
  });
});
