import * as testIds from "../../../src/Utilities/TestUtils.bs";
import { getClientURL, createPaymentBody, changeObjectKeyValue } from "../support/utils";

describe("GigaDat Interac Payment flow test", () => {
  const publishableKey = Cypress.env("HYPERSWITCH_PUBLISHABLE_KEY");
  const secretKey = Cypress.env("HYPERSWITCH_SECRET_KEY");
  let getIframeBody: () => Cypress.Chainable<JQuery<HTMLBodyElement>>;
  let iframeSelector =
    "#orca-payment-element-iframeRef-orca-elements-payment-element-payment-element";

  beforeEach(() => {
    getIframeBody = () => cy.iframe(iframeSelector);

    // Set profile_id for GigaDat/Loonio
    changeObjectKeyValue(
      createPaymentBody,
      "profile_id",
      "pro_Kkp5G7zlVxvOqvkX7yaZ",
    );

    // Set currency to CAD
    changeObjectKeyValue(createPaymentBody, "currency", "CAD");

    // Set billing address country to CA (Canada)
    createPaymentBody.billing.address.country = "CA";

    // Set shipping address country to CA (Canada)
    createPaymentBody.shipping.address.country = "CA";

    // Pass connector as empty array
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

  it("should complete Interac payment via GigaDat connector", () => {
    // Set connector to gigadat
    changeObjectKeyValue(createPaymentBody, "connector", ["gigadat"]);

    cy.createPaymentIntent(secretKey, createPaymentBody).then(() => {
      cy.getGlobalState("clientSecret").then((clientSecret) => {
        cy.visit(getClientURL(clientSecret, publishableKey));
      });
    });

    cy.wait(2000);
    getIframeBody().find(`[data-testid=${testIds.addNewCardIcon}]`).click();
    getIframeBody().contains("div", "Interac").click();
    getIframeBody()
      .get("#submit")
      .click()
      .then(() => {
        // Verify redirect to Interac payment page
        cy.url().should("include", "interac");
      });
  });

  it("should complete Interac payment via Loonio connector", () => {
    // Set connector to loonio
    changeObjectKeyValue(createPaymentBody, "connector", ["loonio"]);

    cy.createPaymentIntent(secretKey, createPaymentBody).then(() => {
      cy.getGlobalState("clientSecret").then((clientSecret) => {
        cy.visit(getClientURL(clientSecret, publishableKey));
      });
    });

    cy.wait(2000);
    getIframeBody().find(`[data-testid=${testIds.addNewCardIcon}]`).click();
    getIframeBody().contains("div", "Interac").click();
    getIframeBody()
      .get("#submit")
      .click()
      .then(() => {
        // Verify redirect to Interac payment page
        cy.url().should("include", "interac");
      });
  });
});