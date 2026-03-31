/**
 * SDK Configuration and Appearance Tests
 * Tests for SDK initialization with different configuration options,
 * including query parameters and appearance customization.
 */
import * as testIds from "../../../../../src/Utilities/TestUtils.bs";
import {
  getClientURL,
  createPaymentBody,
  changeObjectKeyValue,
  CLIENT_BASE_URL,
} from "../../../support/utils";

describe("SDK Configuration Options", () => {
  const publishableKey = Cypress.env("HYPERSWITCH_PUBLISHABLE_KEY");
  const secretKey = Cypress.env("HYPERSWITCH_SECRET_KEY");
  let getIframeBody: () => Cypress.Chainable<JQuery<HTMLBodyElement>>;
  const iframeSelector =
    "#orca-payment-element-iframeRef-orca-elements-payment-element-payment-element";

  beforeEach(() => {
    getIframeBody = () => cy.iframe(iframeSelector);
    changeObjectKeyValue(
      createPaymentBody,
      "customer_id",
      "sdk_config_test_user",
    );
    changeObjectKeyValue(
      createPaymentBody,
      "authentication_type",
      "no_three_ds",
    );
  });

  describe("SDK with Different Currency Configurations", () => {
    it("should load SDK with USD currency", () => {
      changeObjectKeyValue(createPaymentBody, "currency", "USD");

      cy.createPaymentIntent(secretKey, createPaymentBody).then(() => {
        cy.getGlobalState("clientSecret").then((clientSecret) => {
          cy.visit(getClientURL(clientSecret, publishableKey));
        });
      });

      cy.waitForSDKReady();

      getIframeBody()
        .find(`[data-testid=${testIds.cardNoInputTestId}]`)
        .should("be.visible");
    });

    it("should load SDK with EUR currency", () => {
      changeObjectKeyValue(createPaymentBody, "currency", "EUR");

      cy.createPaymentIntent(secretKey, createPaymentBody).then(() => {
        cy.getGlobalState("clientSecret").then((clientSecret) => {
          cy.visit(getClientURL(clientSecret, publishableKey));
        });
      });

      cy.waitForSDKReady();

      getIframeBody()
        .find(`[data-testid=${testIds.cardNoInputTestId}]`)
        .should("be.visible");
    });

    it("should load SDK with GBP currency", () => {
      changeObjectKeyValue(createPaymentBody, "currency", "GBP");

      cy.createPaymentIntent(secretKey, createPaymentBody).then(() => {
        cy.getGlobalState("clientSecret").then((clientSecret) => {
          cy.visit(getClientURL(clientSecret, publishableKey));
        });
      });

      cy.waitForSDKReady();

      getIframeBody()
        .find(`[data-testid=${testIds.cardNoInputTestId}]`)
        .should("be.visible");
    });
  });

  describe("SDK with Different Amount Configurations", () => {
    it("should load SDK with a small amount ($1.00)", () => {
      changeObjectKeyValue(createPaymentBody, "amount", 100);
      changeObjectKeyValue(createPaymentBody, "currency", "USD");

      cy.createPaymentIntent(secretKey, createPaymentBody).then(() => {
        cy.getGlobalState("clientSecret").then((clientSecret) => {
          cy.visit(getClientURL(clientSecret, publishableKey));
        });
      });

      cy.waitForSDKReady();

      getIframeBody()
        .find(`[data-testid=${testIds.cardNoInputTestId}]`)
        .should("be.visible");
    });

    it("should load SDK with a large amount ($999.99)", () => {
      changeObjectKeyValue(createPaymentBody, "amount", 99999);
      changeObjectKeyValue(createPaymentBody, "currency", "USD");

      cy.createPaymentIntent(secretKey, createPaymentBody).then(() => {
        cy.getGlobalState("clientSecret").then((clientSecret) => {
          cy.visit(getClientURL(clientSecret, publishableKey));
        });
      });

      cy.waitForSDKReady();

      getIframeBody()
        .find(`[data-testid=${testIds.cardNoInputTestId}]`)
        .should("be.visible");
    });
  });

  describe("SDK with Custom Backend URL", () => {
    it("should load SDK with custom backend URL parameter", () => {
      const customBackendUrl = Cypress.env("HYPERSWITCH_CUSTOM_BACKEND_URL");

      cy.createPaymentIntent(secretKey, createPaymentBody).then(() => {
        cy.getGlobalState("clientSecret").then((clientSecret) => {
          let url = getClientURL(clientSecret, publishableKey);
          if (customBackendUrl) {
            url += `&customBackendUrl=${customBackendUrl}`;
          }
          cy.visit(url);
        });
      });

      cy.waitForSDKReady();

      getIframeBody()
        .find(`[data-testid=${testIds.cardNoInputTestId}]`)
        .should("be.visible");
    });
  });

  describe("SDK with Profile ID Parameter", () => {
    it("should load SDK with profile ID in URL", () => {
      const profileId = Cypress.env("HYPERSWITCH_PROFILE_ID");

      cy.createPaymentIntent(secretKey, createPaymentBody).then(() => {
        cy.getGlobalState("clientSecret").then((clientSecret) => {
          let url = getClientURL(clientSecret, publishableKey);
          if (profileId) {
            url += `&profileId=${profileId}`;
          }
          cy.visit(url);
        });
      });

      cy.waitForSDKReady();

      getIframeBody()
        .find(`[data-testid=${testIds.cardNoInputTestId}]`)
        .should("be.visible");
    });
  });

  describe("SDK Page Title and Branding", () => {
    it("should display 'Hyperswitch Unified Checkout' title", () => {
      cy.createPaymentIntent(secretKey, createPaymentBody).then(() => {
        cy.getGlobalState("clientSecret").then((clientSecret) => {
          cy.visit(getClientURL(clientSecret, publishableKey));
        });
      });

      cy.contains("Hyperswitch Unified Checkout").should("be.visible");
    });
  });

  describe("SDK with Force Init", () => {
    it("should reinitialize SDK when isForceInit is true", () => {
      cy.createPaymentIntent(secretKey, createPaymentBody).then(() => {
        cy.getGlobalState("clientSecret").then((clientSecret) => {
          const url =
            getClientURL(clientSecret, publishableKey) + "&isForceInit=true";
          cy.visit(url);
        });
      });

      cy.waitForSDKReady();

      getIframeBody()
        .find(`[data-testid=${testIds.cardNoInputTestId}]`)
        .should("be.visible");
    });
  });
});
