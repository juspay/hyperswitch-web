import {
  getClientURL,
  createPaymentBody,
  changeObjectKeyValue,
} from "../../support/utils";

describe("SDK Initialization Tests", () => {
  let publishableKey: string;
  let secretKey: string;

  beforeEach(() => {
    publishableKey = Cypress.env("HYPERSWITCH_PUBLISHABLE_KEY");
    secretKey = Cypress.env("HYPERSWITCH_SECRET_KEY");
    changeObjectKeyValue(createPaymentBody, "customer_id", "sdk_init_test_user");
  });

  it("should initialize SDK with valid publishable key", () => {
    cy.createPaymentIntent(secretKey, createPaymentBody).then(() => {
      cy.getGlobalState("clientSecret").then((clientSecret) => {
        cy.visit(getClientURL(clientSecret, publishableKey));
      });
    });

    cy.waitForSDKReady();
  });

  it("should fail initialization with invalid publishable key format", () => {
    const invalidKey = "invalid_key_format";
    
    cy.createPaymentIntent(secretKey, createPaymentBody).then(() => {
      cy.getGlobalState("clientSecret").then((clientSecret) => {
        // Install the console.error stub via onBeforeLoad so it is registered
        // BEFORE the SDK's JS runs — registering cy.on() after cy.visit() is
        // too late and the stub never captures init-time errors.
        cy.visit(getClientURL(clientSecret, invalidKey), {
          onBeforeLoad(win) {
            cy.stub(win.console, "error").as("consoleError");
          },
        });
      });
    });

    cy.get("@consoleError").should("have.been.called");
  });

  it("should initialize with custom backend URL", () => {
    const customBackendUrl =
      Cypress.env("HYPERSWITCH_CUSTOM_BACKEND_URL") ||
      Cypress.env("HYPERSWITCH_API_URL");
    
    cy.createPaymentIntent(secretKey, createPaymentBody).then(() => {
      cy.getGlobalState("clientSecret").then((clientSecret) => {
        const url = `${getClientURL(clientSecret, publishableKey)}&customBackendUrl=${encodeURIComponent(customBackendUrl)}`;
        cy.visit(url);
      });
    });

    cy.waitForSDKReady();
  });

  it("should reinitialize SDK when isForceInit is true", () => {
    cy.createPaymentIntent(secretKey, createPaymentBody).then(() => {
      cy.getGlobalState("clientSecret").then((clientSecret) => {
        const url = `${getClientURL(clientSecret, publishableKey)}&isForceInit=true`;
        cy.visit(url);
      });
    });

    cy.waitForSDKReady();
    
    cy.window().then((win: any) => {
      expect(win.Hyper).to.exist;
    });
  });

  it("should initialize SDK with profile ID", () => {
    cy.createPaymentIntent(secretKey, createPaymentBody).then(() => {
      cy.getGlobalState("clientSecret").then((clientSecret) => {
        cy.visit(getClientURL(clientSecret, publishableKey));
      });
    });

    cy.waitForSDKReady();
  });
});
