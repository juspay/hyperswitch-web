import * as testIds from "../../../../src/Utilities/TestUtils.bs";
import {
  getClientURL,
  netceteraChallengeTestCard,
  netceteraFrictionlessTestCard,
  createPaymentBody,
  changeObjectKeyValue,
  connectorProfileIdMapping,
  connectorEnum,
} from "../../support/utils";
// Skipped for now: setup.js provisions netcetera as an authentication-only
// connector (three_ds_server), so the netcetera profile has no payment
// connector and a card payment on it renders no payment form. Re-enable once a
// combined "payment processor + netcetera authenticator + external-3DS" profile
// is provisioned.
describe.skip("External 3DS using Netcetera Checks", () => {
  let getIframeBody: () => Cypress.Chainable<JQuery<HTMLBodyElement>>;
  let publishableKey: string;
  let secretKey: string;
  let iframeSelector =
    "#orca-payment-element-iframeRef-orca-elements-payment-element-payment-element";

  beforeEach(function () {
    // Run only when the Netcetera connector is configured for this merchant;
    // otherwise report the suite as pending (visible skip) instead of failing.
    if (!connectorProfileIdMapping.get(connectorEnum.NETCETERA)) {
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
      connectorProfileIdMapping.get(connectorEnum.NETCETERA),
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
    cy.get(
      "#orca-payment-element-iframeRef-orca-elements-payment-element-payment-element",
    )
      .should("be.visible")
      .its("0.contentDocument")
      .its("body");
  });

  it("If the user completes the challenge, the payment should be successful.", () => {
    cy.waitForSDKReady();
    // Click "Add New Card" only when saved cards are present; a fresh customer
    // has none, so the card form is shown directly.
    getIframeBody().then(($body) => {
      if ($body.find(`[data-testid=${testIds.addNewCardIcon}]`).length > 0) {
        getIframeBody().find(`[data-testid=${testIds.addNewCardIcon}]`).click();
      }
    });
    getIframeBody()
      .find(`[data-testid=${testIds.cardNoInputTestId}]`)
      .type(netceteraChallengeTestCard);
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
      cy.wrap($body).find("#sendOtp").click();
      cy.contains("Thanks for your order!", { timeout: 10000 }).should("be.visible");
    });
  });

  it("If the user closes the challenge, the payment should fail.", () => {
    cy.waitForSDKReady();
    // Click "Add New Card" only when saved cards are present; a fresh customer
    // has none, so the card form is shown directly.
    getIframeBody().then(($body) => {
      if ($body.find(`[data-testid=${testIds.addNewCardIcon}]`).length > 0) {
        getIframeBody().find(`[data-testid=${testIds.addNewCardIcon}]`).click();
      }
    });
    getIframeBody()
      .find(`[data-testid=${testIds.cardNoInputTestId}]`)
      .type(netceteraChallengeTestCard);
    getIframeBody()
      .find(`[data-testid=${testIds.expiryInputTestId}]`)
      .type("0444");
    getIframeBody()
      .find(`[data-testid=${testIds.cardCVVInputTestId}]`)
      .should("be.visible")
      .type("1234");
    getIframeBody().get("#submit").click();

    cy.nestedIFrame("#threeDsAuthFrame", ($body) => {
      cy.wrap($body).find("#cancel", { timeout: 10000 }).should("be.visible").click();
      cy.contains("Payment failed. Please check your payment method.", { timeout: 10000 }).should(
        "be.visible",
      );
    });
  });

  it("If the user enters a frictionless card, the payment should be successful without a challenge.", () => {
    cy.waitForSDKReady();
    // Click "Add New Card" only when saved cards are present; a fresh customer
    // has none, so the card form is shown directly.
    getIframeBody().then(($body) => {
      if ($body.find(`[data-testid=${testIds.addNewCardIcon}]`).length > 0) {
        getIframeBody().find(`[data-testid=${testIds.addNewCardIcon}]`).click();
      }
    });
    getIframeBody()
      .find(`[data-testid=${testIds.cardNoInputTestId}]`)
      .type(netceteraFrictionlessTestCard);
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
