import {
  getClientURL,
  createPaymentBody,
  changeObjectKeyValue,
} from "../../support/utils";

describe("SDK Initialization Tests", () => {
  const publishableKey = Cypress.env("HYPERSWITCH_PUBLISHABLE_KEY");
  const secretKey = Cypress.env("HYPERSWITCH_SECRET_KEY");

  beforeEach(() => {
    changeObjectKeyValue(createPaymentBody, "customer_id", "sdk_init_test_user");
  });

  it("should initialize SDK with valid publishable key", () => {
    cy.createPaymentIntent(secretKey, createPaymentBody).then(() => {
      cy.getGlobalState("clientSecret").then((clientSecret) => {
        cy.visit(getClientURL(clientSecret, publishableKey));
      });
    });

    // Verify iframe loads successfully
    cy.get("#orca-payment-element-iframeRef-orca-elements-payment-element-payment-element")
      .should("be.visible")
      .its("0.contentDocument")
      .its("body")
      .should("not.be.empty");
  });

  it("should fail initialization with invalid publishable key format", () => {
    const invalidKey = "invalid_key_format";
    
    cy.createPaymentIntent(secretKey, createPaymentBody).then(() => {
      cy.getGlobalState("clientSecret").then((clientSecret) => {
        cy.visit(getClientURL(clientSecret, invalidKey));
      });
    });

    // Should show error for invalid publishable key
    cy.on("window:before:load", (win) => {
      cy.stub(win.console, "error").as("consoleError");
    });

    cy.get("@consoleError").should("have.been.called");
  });

  it("should initialize with custom backend URL", () => {
    const customBackendUrl = Cypress.env("HYPERSWITCH_CUSTOM_BACKEND_URL");
    
    cy.createPaymentIntent(secretKey, createPaymentBody).then(() => {
      cy.getGlobalState("clientSecret").then((clientSecret) => {
        const url = `${getClientURL(clientSecret, publishableKey)}&customBackendUrl=${encodeURIComponent(customBackendUrl)}`;
        cy.visit(url);
      });
    });

    // Verify SDK loads with custom backend
    cy.get("#orca-payment-element-iframeRef-orca-elements-payment-element-payment-element")
      .should("be.visible");
  });

  it("should reinitialize SDK when isForceInit is true", () => {
    cy.createPaymentIntent(secretKey, createPaymentBody).then(() => {
      cy.getGlobalState("clientSecret").then((clientSecret) => {
        const url = `${getClientURL(clientSecret, publishableKey)}&isForceInit=true`;
        cy.visit(url);
      });
    });

    // Verify SDK reinitializes properly
    cy.get("#orca-payment-element-iframeRef-orca-elements-payment-element-payment-element")
      .should("be.visible");
    
    // Check that the SDK script is reloaded
    cy.window().then((win) => {
      expect(win.Hyper).to.exist;
    });
  });

  it("should initialize SDK with profile ID", () => {
    const profileId = Cypress.env("HYPERSWITCH_PROFILE_ID");
    
    cy.createPaymentIntent(secretKey, createPaymentBody).then(() => {
      cy.getGlobalState("clientSecret").then((clientSecret) => {
        const url = `${getClientURL(clientSecret, publishableKey)}&profileId=${profileId}`;
        cy.visit(url);
      });
    });

    // Verify SDK loads with profile ID
    cy.get("#orca-payment-element-iframeRef-orca-elements-payment-element-payment-element")
      .should("be.visible");
  });
});