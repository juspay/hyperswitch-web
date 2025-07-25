import * as testIds from "../../../src/Utilities/TestUtils.bs";
import { getClientURL } from "../support/utils";
import { createPaymentBody } from "../support/utils";
import {
  changeObjectKeyValue,
  connectorProfileIdMapping,
  connectorEnum,
} from "../support/utils";
import { stripeCards } from "cypress/support/cards";

describe("Card payment flow test", () => {
  const publishableKey = Cypress.env("HYPERSWITCH_PUBLISHABLE_KEY");
  const secretKey = Cypress.env("HYPERSWITCH_SECRET_KEY");
  let getIframeBody: () => Cypress.Chainable<JQuery<HTMLBodyElement>>;
  let iframeSelector =
    "#orca-payment-element-iframeRef-orca-elements-payment-element-payment-element";
  changeObjectKeyValue(
    createPaymentBody,
    "profile_id",
    connectorProfileIdMapping.get(connectorEnum.CRYPTOPAY),
  );

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
    cy.get(iframeSelector)
      .should("be.visible")
      .its("0.contentDocument")
      .its("body");
  });

  it("should complete the crypto payment successfully", () => {
    cy.wait(2000);
    getIframeBody().find(`[data-testid=${testIds.addNewCardIcon}]`).click();
    getIframeBody().contains("div", "Crypto").click();
    getIframeBody()
      .get("#submit")
      .click()
      .then(() => {
        cy.url().should(
          "include",
          "hosted-business-sandbox.cryptopay.me/invoices",
        );
      });
  });
});
