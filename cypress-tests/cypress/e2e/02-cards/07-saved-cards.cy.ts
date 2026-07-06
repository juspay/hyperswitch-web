import * as testIds from "../../../../src/Utilities/TestUtils.bs";
import { getClientURL } from "../../support/utils";
import { createPaymentBody } from "../../support/utils";
import { changeObjectKeyValue } from "../../support/utils";

describe("Card payment flow test", () => {
  let publishableKey: string;
  let secretKey: string;
  let getIframeBody: () => Cypress.Chainable<JQuery<HTMLBodyElement>>;
  let iframeSelector =
    "#orca-payment-element-iframeRef-orca-elements-payment-element-payment-element";
  changeObjectKeyValue(
    createPaymentBody,
    "customer_id",
    "hyperswitch_sdk_demo_id",
  );

  beforeEach(() => {
    publishableKey = Cypress.env("HYPERSWITCH_PUBLISHABLE_KEY");
    secretKey = Cypress.env("HYPERSWITCH_SECRET_KEY");
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
    cy.get(
      "#orca-payment-element-iframeRef-orca-elements-payment-element-payment-element",
    )
      .should("be.visible")
      .its("0.contentDocument")
      .its("body");
  });

  it("should check if cards are saved", () => {
    getIframeBody().then(($body) => {
      if ($body.find(`[data-testid=${testIds.addNewCardIcon}]`).length > 0) {
        getIframeBody().contains("4 digit").click();
        getIframeBody().find("[data-testid=cvvInput]").type("1234");
        getIframeBody().get("#submit").click();
        cy.contains("Thanks for your order!", { timeout: 10000 }).should("be.visible");
      } else {
        cy.log("new card flow — no saved cards on fresh merchant");
      }
    });
  });
});
