import * as testIds from "../../../../src/Utilities/TestUtils.bs";
import {
  getClientURL,
  juspayChallengeTestCard,
  juspayFrictionlessTestCard,
  createPaymentBody,
  changeObjectKeyValue,
  connectorProfileIdMapping,
  connectorEnum,
} from "../../support/utils";
describe("External 3DS using Juspay Checks", () => {
  let getIframeBody: () => Cypress.Chainable<JQuery<HTMLBodyElement>>;
  let publishableKey: string;
  let secretKey: string;
  let iframeSelector =
    "#orca-payment-element-iframeRef-orca-elements-payment-element-payment-element";

  beforeEach(function () {
    // Run only when the Juspay connector is configured for this merchant;
    // otherwise report the suite as pending (visible skip) instead of failing.
    if (!connectorProfileIdMapping.get(connectorEnum.JUSPAY)) {
      this.skip();
    }
    publishableKey = Cypress.env("HYPERSWITCH_PUBLISHABLE_KEY");
    secretKey = Cypress.env("HYPERSWITCH_SECRET_KEY");
    getIframeBody = () => cy.iframe(iframeSelector);
    // Mutate the shared payment body here (not at describe-load time) so this
    // suite's 3DS settings don't leak into other specs.
    changeObjectKeyValue(
      createPaymentBody,
      "profile_id",
      connectorProfileIdMapping.get(connectorEnum.JUSPAY),
    );
    changeObjectKeyValue(
      createPaymentBody,
      "request_external_three_ds_authentication",
      true,
    );
    changeObjectKeyValue(createPaymentBody, "authentication_type", "three_ds");
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
    cy.get(iframeSelector)
      .should("be.visible")
      .its("0.contentDocument")
      .its("body");
  });

  it("If the user completes the challenge, the payment should be successful.", () => {
    cy.waitForSDKReady();
    getIframeBody().find(`[data-testid=${testIds.addNewCardIcon}]`).click();
    getIframeBody()
      .find(`[data-testid=${testIds.cardNoInputTestId}]`)
      .type(juspayChallengeTestCard);
    getIframeBody()
      .find(`[data-testid=${testIds.expiryInputTestId}]`)
      .type("0444");
    getIframeBody()
      .find(`[data-testid=${testIds.cardCVVInputTestId}]`)
      .should("be.visible")
      .type("1234");
    getIframeBody().get("#submit").click();

    cy.nestedIFrame("#threeDsAuthFrame", ($body) => {
      cy.wrap($body).find("#otp", { timeout: 10000 }).should("be.visible").type("1234");

      cy.wrap($body).contains("button", "Pay").click();
      cy.contains("Thanks for your order!", { timeout: 15000 }).should("be.visible");
    });
  });

  it("If the user closes the challenge, the payment should fail.", () => {
    cy.waitForSDKReady();
    getIframeBody().find(`[data-testid=${testIds.addNewCardIcon}]`).click();
    getIframeBody()
      .find(`[data-testid=${testIds.cardNoInputTestId}]`)
      .type(juspayChallengeTestCard);
    getIframeBody()
      .find(`[data-testid=${testIds.expiryInputTestId}]`)
      .type("0444");
    getIframeBody()
      .find(`[data-testid=${testIds.cardCVVInputTestId}]`)
      .should("be.visible")
      .type("1234");
    getIframeBody().get("#submit").click();

    cy.nestedIFrame("#threeDsAuthFrame", ($body) => {
      cy.wrap($body).contains("button", "Cancel", { timeout: 10000 }).click();
      cy.contains("Payment failed. Please check your payment method.", { timeout: 10000 }).should(
        "be.visible",
      );
    });
  });

  it("If the user enters a frictionless card, the payment should be successful without a challenge.", () => {
    cy.waitForSDKReady();
    getIframeBody().find(`[data-testid=${testIds.addNewCardIcon}]`).click();
    getIframeBody()
      .find(`[data-testid=${testIds.cardNoInputTestId}]`)
      .type(juspayFrictionlessTestCard);
    getIframeBody()
      .find(`[data-testid=${testIds.expiryInputTestId}]`)
      .type("0444");
    getIframeBody()
      .find(`[data-testid=${testIds.cardCVVInputTestId}]`)
      .should("be.visible")
      .type("1234");
    getIframeBody().get("#submit").click();
    cy.contains("Thanks for your order!", { timeout: 10000 }).should("be.visible");
  });
});
