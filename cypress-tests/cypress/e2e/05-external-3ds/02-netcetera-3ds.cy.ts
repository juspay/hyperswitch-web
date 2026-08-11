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

describe("External 3DS using Netcetera Checks", () => {
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
    getIframeBody = () => cy.paymentElementBody();
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
    changeObjectKeyValue(createPaymentBody, "connector", ["cybersource"]);
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

    // Wait for the fullscreen overlay with the 3DS iframe, then go into it
    cy.wait(5000); // Give ACS time to set cookies/session
    cy.nestedIFrame("#threeDsAuthFrame", ($body) => {
      // NDM Simulator: filter to only visible text inputs (OTP field)
      cy.wrap($body)
        .find("input[type='text']", { timeout: 30000 })
        .filter(":visible")
        .first()
        .should("be.visible")
        .type("1234");
      // Click the Pay button
      cy.wrap($body).find("button[type='submit']").contains("Pay").click();
    });
    // Poll the payment status via API until succeeded
    cy.getGlobalState("paymentId").then((paymentId) => {
      let attempts = 0;
      const maxAttempts = 30;
      const poll = () => {
        cy.request({
          method: "GET",
          url: `${Cypress.env("HYPERSWITCH_API_URL")}/payments/${paymentId}?force_sync=true`,
          headers: {
            "api-key": secretKey,
          },
        }).then((response) => {
          if (response.body.status === "succeeded") {
            cy.log("Payment succeeded:", response.body.status);
            expect(response.body.status).to.eq("succeeded");
          } else if (attempts >= maxAttempts) {
            throw new Error(
              `Payment did not succeed after ${maxAttempts} attempts. Last status: ${response.body.status}`
            );
          } else {
            attempts++;
            cy.wait(2000);
            poll();
          }
        });
      };
      poll();
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

    cy.wait(5000); // Give ACS time to set cookies/session
    cy.nestedIFrame("#threeDsAuthFrame", ($body) => {
      // Find the Cancel button in NDM Simulator
      cy.wrap($body).find("button").contains("Cancel").click();
    });
    // Poll the payment status via API until it reaches "failed"
    cy.getGlobalState("paymentId").then((paymentId) => {
      let attempts = 0;
      const maxAttempts = 20;
      const poll = () => {
        cy.request({
          method: "GET",
          url: `${Cypress.env("HYPERSWITCH_API_URL")}/payments/${paymentId}?force_sync=true`,
          headers: {
            "api-key": secretKey,
          },
        }).then((response) => {
          if (response.body.status === "failed") {
            cy.log("Payment failed as expected:", response.body.status);
            expect(response.body.status).to.eq("failed");
          } else if (attempts >= maxAttempts) {
            throw new Error(
              `Payment did not fail after ${maxAttempts} attempts. Last status: ${response.body.status}`
            );
          } else {
            attempts++;
            cy.wait(2000);
            poll();
          }
        });
      };
      poll();
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

    // Poll the payment status via Retrieve Payment Intent API until succeeded
    cy.getGlobalState("paymentId").then((paymentId) => {
      let attempts = 0;
      const maxAttempts = 30;
      const poll = () => {
        cy.request({
          method: "GET",
          url: `${Cypress.env("HYPERSWITCH_API_URL")}/payments/${paymentId}?force_sync=true`,
          headers: {
            "api-key": secretKey,
          },
        }).then((response) => {
          expect(response.body.status).to.exist;
          if (response.body.status === "succeeded") {
            cy.log("Payment succeeded:", response.body.status);
            expect(response.body.status).to.eq("succeeded");
          } else if (attempts >= maxAttempts) {
            throw new Error(`Payment did not succeed after ${maxAttempts} attempts. Last status: ${response.body.status}`);
          } else {
            attempts++;
            cy.wait(2000);
            poll();
          }
        });
      };
      poll();
    });
  });
});
