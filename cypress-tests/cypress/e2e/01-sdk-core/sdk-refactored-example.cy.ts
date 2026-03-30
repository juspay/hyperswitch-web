// EXAMPLE: Refactored test using smart waits instead of hard waits
import { getClientURL, createPaymentBody, changeObjectKeyValue } from "../../support/utils";
import { stripeCards } from "../../support/cards";
import * as testIds from "../../../../src/Utilities/TestUtils.bs";

describe("SDK Refactored Example - Best Practices", () => {
  const publishableKey = Cypress.env("HYPERSWITCH_PUBLISHABLE_KEY");
  const secretKey = Cypress.env("HYPERSWITCH_SECRET_KEY");

  beforeEach(() => {
    changeObjectKeyValue(createPaymentBody, "customer_id", "refactored_test_user");
    
    cy.createPaymentIntent(secretKey, createPaymentBody).then(() => {
      cy.getGlobalState("clientSecret").then((clientSecret) => {
        cy.visit(getClientURL(clientSecret, publishableKey));
      });
    });

    // Use smart wait instead of cy.wait(2000)
    cy.waitForSDKReady();
  });

  it("should complete card payment with smart waits", () => {
    const { cardNo, card_exp_month, card_exp_year, cvc } = stripeCards.successCard;

    // Use enterCardDetails helper instead of repetitive iframe calls
    cy.enterCardDetails({
      cardNo,
      card_exp_month,
      card_exp_year,
      cvc,
    });

    // Wait for submit button to be ready
    cy.iframe("#orca-payment-element-iframeRef-orca-elements-payment-element-payment-element")
      .find("#submit")
      .safeClick();

    // Wait for success message with proper assertion
    cy.contains("Thanks for your order!", { timeout: 10000 })
      .should("be.visible");
  });

  it("should validate card number with smart error handling", () => {
    cy.iframe("#orca-payment-element-iframeRef-orca-elements-payment-element-payment-element")
      .find(`[data-testid=${testIds.cardNoInputTestId}]`)
      .safeType("111111"); // Invalid card

    cy.iframe("#orca-payment-element-iframeRef-orca-elements-payment-element-payment-element")
      .find(`[data-testid=${testIds.expiryInputTestId}]`)
      .safeType("1230");

    cy.iframe("#orca-payment-element-iframeRef-orca-elements-payment-element-payment-element")
      .find(`[data-testid=${testIds.cardCVVInputTestId}]`)
      .safeType("123");

    cy.iframe("#orca-payment-element-iframeRef-orca-elements-payment-element-payment-element")
      .find("#submit")
      .safeClick();

    // Wait for error with proper timeout
    cy.iframe("#orca-payment-element-iframeRef-orca-elements-payment-element-payment-element")
      .find(".Error.pt-1", { timeout: 5000 })
      .should("be.visible")
      .and("contain.text", "Please enter a valid card number.");
  });

  it("should handle SDK reinitialization", () => {
    // Verify SDK is ready
    cy.waitForSDKReady();

    // Refresh and verify SDK reinitializes
    cy.reload();
    cy.waitForSDKReady();

    // Continue with test
    cy.iframe("#orca-payment-element-iframeRef-orca-elements-payment-element-payment-element")
      .find(`[data-testid=${testIds.cardNoInputTestId}]`)
      .should("be.visible");
  });
});
