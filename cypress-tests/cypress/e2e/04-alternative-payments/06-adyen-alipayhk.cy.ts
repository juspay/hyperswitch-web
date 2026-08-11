import {
  changeObjectKeyValue,
  connectorEnum,
  connectorProfileIdMapping,
  createPaymentBody,
  getClientURL,
} from "../../support/utils";

describe("Adyen AlipayHK payment flow", () => {
  let publishableKey: string;
  let secretKey: string;
  let getIframeBody: () => Cypress.Chainable<JQuery<HTMLBodyElement>>;
  const iframeSelector =
    "#orca-payment-element-iframeRef-orca-elements-payment-element-payment-element";

  beforeEach(() => {
    publishableKey = Cypress.env("HYPERSWITCH_PUBLISHABLE_KEY");
    secretKey = Cypress.env("HYPERSWITCH_SECRET_KEY");

    const adyenProfileId = connectorProfileIdMapping.get(connectorEnum.ADYEN);
    assert.ok(
      adyenProfileId,
      "Adyen connector credentials are missing from creds.json — " +
        "connector was not provisioned. Add adyen to creds.json to run this test.",
    );

    changeObjectKeyValue(createPaymentBody, "profile_id", adyenProfileId);
    changeObjectKeyValue(createPaymentBody, "currency", "HKD");
    createPaymentBody.billing.address.country = "HK";
    createPaymentBody.shipping.address.country = "HK";

    getIframeBody = () => cy.iframe(iframeSelector);
    cy.createPaymentIntent(secretKey, createPaymentBody).then(() => {
      cy.getGlobalState("clientSecret").then((clientSecret) => {
        cy.visit(getClientURL(clientSecret, publishableKey));
      });
    });
  });

  // NOTE: The Adyen Acquirer Simulator page (authorised / cancelled / error /
  // refused buttons) is intermittent, so the test intentionally stops at the
  // redirect — it asserts the browser reaches the Adyen-hosted page and does
  // not interact with the simulator outcomes.
  it("should redirect to Adyen for the AlipayHK payment", function () {
    cy.get(iframeSelector).should("be.visible");

    cy.selectPaymentMethodOrSkip(getIframeBody, "AlipayHK").then((skipped) => {
      if (skipped) {
        this.skip();
      }

      getIframeBody().get("#submit").click();

      cy.url({ timeout: 30000 }).should("include", "adyen");
    });
  });
});
