import * as testIds from "../../../src/Utilities/TestUtils.bs";
import {
  getClientURL,
  createPaymentBody,
  changeObjectKeyValue,
} from "../support/utils";

describe("Adyen Card payment flow test", () => {
  const publishableKey = Cypress.env("HYPERSWITCH_PUBLISHABLE_KEY");
  const secretKey = Cypress.env("HYPERSWITCH_SECRET_KEY");
  let getIframeBody: () => Cypress.Chainable<JQuery<HTMLBodyElement>>;
  const iframeSelector =
    "#orca-payment-element-iframeRef-orca-elements-payment-element-payment-element";
  const adyenIframeSelector = ".adyen-checkout__iframe--threeDSIframe";

  changeObjectKeyValue(
    createPaymentBody,
    "profile_id",
    Cypress.env("PROFILE_ID")
  );
  changeObjectKeyValue(createPaymentBody, "authentication_type", "three_ds");

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
    cy.frameLoaded(iframeSelector);
  });

  it("submit payment form and make successful payment", () => {
    getIframeBody().find(`[data-testid=${testIds.addNewCardIcon}]`).click();
    cy.enterValueInIframe(testIds.cardNoInputTestId, "4917 6100 0000 0000");
    cy.enterValueInIframe(testIds.expiryInputTestId, "03/30");
    cy.enterValueInIframe(testIds.cardCVVInputTestId, "737");

    cy.intercept("**/payments/redirect/**").as("hyperswitchRedriect");
    cy.intercept("**/checkoutshopper/threeDS2.shtml*").as("adyenCheckout");

    getIframeBody().get("#submit").click();

    //redirect through hyperswitch
    cy.wait("@hyperswitchRedriect").then(() => {
      cy.location("pathname").should("include", "/payments/redirect");
      cy.contains("Please wait while we process your payment...").should(
        "be.visible"
      );
    });

    //adyen checkout page
    cy.wait("@adyenCheckout").then(() => {
      //not using cy.iframe as it can only be applied to exactly one iframe at a time
      cy.get(adyenIframeSelector).should("be.visible");

      cy.getIframeElement(adyenIframeSelector, ".input-field").type("password");
      cy.getIframeElement(adyenIframeSelector, "#buttonSubmit").click();

      cy.contains("Returning to JuspayDEECOM");
    });
    cy.contains("Thanks for your order!").should("be.visible");
  });
});
