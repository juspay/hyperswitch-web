import * as testIds from "../../../../src/Utilities/TestUtils.bs";
import { getClientURL } from "../../support/utils";
import { createPaymentBody } from "../../support/utils";
import {
  changeObjectKeyValue,
  connectorProfileIdMapping,
  connectorEnum,
} from "../../support/utils";
import { stripeCards } from "../../support/cards";

describe("cashtocode E-voucher test ", () => {
  let publishableKey: string;
  let secretKey: string;
  let getIframeBody: () => Cypress.Chainable<JQuery<HTMLBodyElement>>;
  let iframeSelector =
    "#orca-payment-element-iframeRef-orca-elements-payment-element-payment-element";

  beforeEach(() => {
    publishableKey = Cypress.env("HYPERSWITCH_PUBLISHABLE_KEY");
    secretKey = Cypress.env("HYPERSWITCH_SECRET_KEY");
    changeObjectKeyValue(
      createPaymentBody,
      "profile_id",
      connectorProfileIdMapping.get(connectorEnum.CASHTOCODE),
    );
    changeObjectKeyValue(createPaymentBody, "currency", "USD");
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

  it("should complete the E-voucher payment successfully", function () {
    cy.iframe(iframeSelector).should("exist");
    cy.selectPaymentMethodOrSkip(getIframeBody, "E-Voucher").then((skipped) => {
      if (skipped) {
        this.skip();
      }
      getIframeBody()
        .get("#submit")
        .click()
        .then(() => {
          cy.url().should(
            "include",
            "https://dev.evoucher.cashtocode.com/",
          );
        });
    });
  });
});
