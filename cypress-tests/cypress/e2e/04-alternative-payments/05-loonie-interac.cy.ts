import * as testIds from "../../../../src/Utilities/TestUtils.bs";
import { getClientURL, createPaymentBody, changeObjectKeyValue, connectorProfileIdMapping, connectorEnum } from "../../support/utils";

describe("GigaDat Interac Payment flow test", () => {
  let publishableKey: string;
  let secretKey: string;
  let getIframeBody: () => Cypress.Chainable<JQuery<HTMLBodyElement>>;
  let iframeSelector =
    "#orca-payment-element-iframeRef-orca-elements-payment-element-payment-element";

  beforeEach(() => {
    publishableKey = Cypress.env("HYPERSWITCH_PUBLISHABLE_KEY");
    secretKey = Cypress.env("HYPERSWITCH_SECRET_KEY");
    getIframeBody = () => cy.iframe(iframeSelector);

    changeObjectKeyValue(
      createPaymentBody,
      "profile_id",
      connectorProfileIdMapping.get(connectorEnum.INTERAC),
    );

    changeObjectKeyValue(createPaymentBody, "currency", "CAD");

    createPaymentBody.billing.address.country = "CA";

    createPaymentBody.shipping.address.country = "CA";

    changeObjectKeyValue(createPaymentBody, "connector", []);
  });

  it("title rendered correctly", () => {
    cy.createPaymentIntent(secretKey, createPaymentBody).then(() => {
      cy.getGlobalState("clientSecret").then((clientSecret) => {
        cy.visit(getClientURL(clientSecret, publishableKey));
      });
    });
    cy.contains("Hyperswitch Unified Checkout").should("be.visible");
  });

  it("orca-payment-element iframe loaded", () => {
    cy.createPaymentIntent(secretKey, createPaymentBody).then(() => {
      cy.getGlobalState("clientSecret").then((clientSecret) => {
        cy.visit(getClientURL(clientSecret, publishableKey));
      });
    });
    cy.get(iframeSelector)
      .should("be.visible")
      .its("0.contentDocument")
      .its("body");
  });

  it("should complete Interac payment via GigaDat connector", function () {

    changeObjectKeyValue(createPaymentBody, "connector", ["gigadat"]);

    cy.createPaymentIntent(secretKey, createPaymentBody).then(() => {
      cy.getGlobalState("clientSecret").then((clientSecret) => {
        cy.visit(getClientURL(clientSecret, publishableKey));
      });
    });

    cy.iframe(iframeSelector).should("exist");
    cy.selectPaymentMethodOrSkip(getIframeBody, "Interac").then((skipped) => {
      if (skipped) {
        this.skip();
      }
      getIframeBody()
        .get("#submit")
        .click()
        .then(() => {
          cy.url().should("include", "interac");
        });
    });
  });

  it("should complete Interac payment via Loonio connector", function () {
    changeObjectKeyValue(createPaymentBody, "connector", ["loonio"]);

    cy.createPaymentIntent(secretKey, createPaymentBody).then(() => {
      cy.getGlobalState("clientSecret").then((clientSecret) => {
        cy.visit(getClientURL(clientSecret, publishableKey));
      });
    });

    cy.iframe(iframeSelector).should("exist");
    cy.selectPaymentMethodOrSkip(getIframeBody, "Interac").then((skipped) => {
      if (skipped) {
        this.skip();
      }
      getIframeBody()
        .get("#submit")
        .click()
        .then(() => {   
          cy.url().should("include", "interac");
        });
    });
  });
});
