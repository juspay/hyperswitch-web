
import * as testIds from "../../../src/Utilities/TestUtils.bs";
import { getClientURL } from "../support/utils";
import { createPaymentBody } from "../support/utils";
import {
  changeObjectKeyValue,
  connectorProfileIdMapping,
  connectorEnum,
} from "../support/utils";

describe("TrustPay iDEAL Bank Redirect Payment flow test", () => {
  const publishableKey = Cypress.env("HYPERSWITCH_PUBLISHABLE_KEY");
  const secretKey = Cypress.env("HYPERSWITCH_SECRET_KEY");
  let getIframeBody: () => Cypress.Chainable<JQuery<HTMLBodyElement>>;
  let iframeSelector =
    "#orca-payment-element-iframeRef-orca-elements-payment-element-payment-element";

  beforeEach(() => {
    getIframeBody = () => cy.iframe(iframeSelector);
    
    changeObjectKeyValue(
      createPaymentBody,
      "profile_id",
      connectorProfileIdMapping.get(connectorEnum.TRUSTPAY),
    );
    changeObjectKeyValue(createPaymentBody, "currency", "EUR");
    
  
    createPaymentBody.billing.address.country = "NL";
    createPaymentBody.billing.address.state = "Noord-Holland";
  
     createPaymentBody.shipping.address.country = "NL";
    createPaymentBody.shipping.address.state = "Noord-Holland";
  
  

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

  it("should complete the iDEAL bank redirect payment successfully", () => {
    cy.wait(2000);
    getIframeBody().find(`[data-testid=${testIds.addNewCardIcon}]`).click();
    getIframeBody().contains("div", "iDEAL").click();
    getIframeBody()
      .get("#submit")
      .click()
      .then(() => {
        cy.url().should(
          "include",
          "https://pay.ideal.nl/transactions",
        );
      });
  });
});

describe("TrustPay Blik Bank Redirect Payment flow test", () => {
  const publishableKey = Cypress.env("HYPERSWITCH_PUBLISHABLE_KEY");
  const secretKey = Cypress.env("HYPERSWITCH_SECRET_KEY");
  let getIframeBody: () => Cypress.Chainable<JQuery<HTMLBodyElement>>;
  let iframeSelector =
    "#orca-payment-element-iframeRef-orca-elements-payment-element-payment-element";

  beforeEach(() => {
    getIframeBody = () => cy.iframe(iframeSelector);
    

    changeObjectKeyValue(
      createPaymentBody,
      "profile_id",
      connectorProfileIdMapping.get(connectorEnum.TRUSTPAY),
    );
    changeObjectKeyValue(createPaymentBody, "currency", "PLN");
    
    createPaymentBody.billing.address.country = "PL";
  
     createPaymentBody.shipping.address.country = "PL";
  
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

  it("should complete the Blik bank redirect payment successfully", () => {
    cy.wait(2000);
    getIframeBody().find(`[data-testid=${testIds.addNewCardIcon}]`).click();
    getIframeBody().contains("div", "Blik").click();
    getIframeBody()
      .get("#submit")
      .click()
      .then(() => {
        cy.url().should(
          "include",
          "https://e.blik.com/blik_web/index.html",
        );
      });
  });
});

describe("TrustPay EPS Bank Redirect Payment flow test", () => {
  const publishableKey = Cypress.env("HYPERSWITCH_PUBLISHABLE_KEY");
  const secretKey = Cypress.env("HYPERSWITCH_SECRET_KEY");
  let getIframeBody: () => Cypress.Chainable<JQuery<HTMLBodyElement>>;
  let iframeSelector =
    "#orca-payment-element-iframeRef-orca-elements-payment-element-payment-element";

  beforeEach(() => {
    getIframeBody = () => cy.iframe(iframeSelector);
    
    changeObjectKeyValue(
      createPaymentBody,
      "profile_id",
      connectorProfileIdMapping.get(connectorEnum.TRUSTPAY),
    );
    changeObjectKeyValue(createPaymentBody, "currency", "EUR");
    
    createPaymentBody.billing.address.country = "AT";
  
     createPaymentBody.shipping.address.country = "AT";
  
  
  

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

  it("should complete the EPS bank redirect payment successfully", () => {
    cy.wait(2000);
    getIframeBody().find(`[data-testid=${testIds.addNewCardIcon}]`).click();
    getIframeBody().contains("div", "EPS").click();
    getIframeBody()
      .get("#submit")
      .click()
      .then(() => {
        cy.url().should(
          "include",
          "https://routing.eps.or.at/appl/epsSO/transinit/bankauswahl.htm",
        );
      });
  });
});
