import { getClientURL, createPaymentBody, changeObjectKeyValue } from "../../support/utils";
import { stripeCards } from "../../support/cards";
import * as testIds from "../../../../src/Utilities/TestUtils.bs";

describe.skip("SDK Refactored Example - Best Practices", () => {
  const publishableKey = Cypress.env("HYPERSWITCH_PUBLISHABLE_KEY");
  const secretKey = Cypress.env("HYPERSWITCH_SECRET_KEY");

  beforeEach(() => {
    changeObjectKeyValue(createPaymentBody, "customer_id", "refactored_test_user");
    
    cy.createPaymentIntent(secretKey, createPaymentBody).then(() => {
      cy.getGlobalState("clientSecret").then((clientSecret) => {
        cy.visit(getClientURL(clientSecret, publishableKey));
      });
    });

    cy.waitForSDKReady();
  });

  it("should complete card payment with smart waits", () => {
    const { cardNo, card_exp_month, card_exp_year, cvc } = stripeCards.successCard;

    cy.enterCardDetails({
      cardNo,
      card_exp_month,
      card_exp_year,
      cvc,
    });

    cy.iframe("#orca-payment-element-iframeRef-orca-elements-payment-element-payment-element")
      .find("#submit")
      .safeClick();

    cy.contains("Thanks for your order!", { timeout: 10000 })
      .should("be.visible");
  });

  it("should validate card number with smart error handling", () => {
    cy.iframe("#orca-payment-element-iframeRef-orca-elements-payment-element-payment-element")
      .find(`[data-testid=${testIds.cardNoInputTestId}]`)
      .safeType("111111");

    cy.iframe("#orca-payment-element-iframeRef-orca-elements-payment-element-payment-element")
      .find(`[data-testid=${testIds.expiryInputTestId}]`)
      .safeType("1230");

    cy.iframe("#orca-payment-element-iframeRef-orca-elements-payment-element-payment-element")
      .find(`[data-testid=${testIds.cardCVVInputTestId}]`)
      .safeType("123");

    cy.iframe("#orca-payment-element-iframeRef-orca-elements-payment-element-payment-element")
      .find("#submit")
      .safeClick();

    cy.iframe("#orca-payment-element-iframeRef-orca-elements-payment-element-payment-element")
      .find(".Error.pt-1", { timeout: 5000 })
      .should("be.visible")
      .and("contain.text", "Please enter a valid card number.");
  });

  it("should handle SDK reinitialization", () => {
    cy.waitForSDKReady();

    cy.reload();
    cy.waitForSDKReady();

    cy.iframe("#orca-payment-element-iframeRef-orca-elements-payment-element-payment-element")
      .find(`[data-testid=${testIds.cardNoInputTestId}]`)
      .should("be.visible");
  });
});
