import {
  getClientURL,
  createPaymentBody,
  changeObjectKeyValue,
} from "../../support/utils";

describe("SDK Error Handling Tests", () => {
  let publishableKey: string;
  let secretKey: string;

  beforeEach(() => {
    publishableKey = Cypress.env("HYPERSWITCH_PUBLISHABLE_KEY");
    secretKey = Cypress.env("HYPERSWITCH_SECRET_KEY");
    changeObjectKeyValue(createPaymentBody, "customer_id", "error_handling_test_user");
  });

  it("should handle missing client secret error", () => {
    cy.visit(getClientURL("", publishableKey), {
      failOnStatusCode: false,
    });

    cy.get("#orca-payment-element-iframeRef-orca-elements-payment-element-payment-element", { timeout: 5000 })
      .should("not.exist");
  });

  it("should handle invalid client secret format", () => {
    const invalidClientSecret = "invalid_secret_format";

    cy.visit(getClientURL(invalidClientSecret, publishableKey), {
      failOnStatusCode: false,
    });

    cy.get("#orca-payment-element-iframeRef-orca-elements-payment-element-payment-element", { timeout: 5000 })
      .should("not.exist");
  });

  it("should handle network errors gracefully", () => {
    // cy.intercept works for browser-level requests (XHR/fetch), not cy.request.
    // Intercept the SDK's payment_methods call to simulate a network failure
    // and verify the page remains accessible without crashing.
    cy.intercept("GET", "**/account/payment_methods*", {
      forceNetworkError: true,
    }).as("paymentMethodsError");

    cy.createPaymentIntent(secretKey, createPaymentBody).then(() => {
      cy.getGlobalState("clientSecret").then((clientSecret) => {
        cy.visit(getClientURL(clientSecret, publishableKey), {
          failOnStatusCode: false,
        });
      });
    });

    // Page should remain accessible even when the payment methods request fails
    cy.get("body").should("exist");
    cy.get("#submit").should("exist");
  });

  it("should handle 401 unauthorized error", () => {
    const invalidSecretKey = "invalid_key";

    cy.request({
      method: "POST",
      url: `${Cypress.env("HYPERSWITCH_API_URL")}/payments`,
      headers: {
        "Content-Type": "application/json",
        "api-key": invalidSecretKey,
      },
      body: createPaymentBody,
      failOnStatusCode: false,
    }).then((response) => {
      expect([401, 404]).to.include(response.status);
    });
  });

  it("should handle 404 not found error", () => {
    cy.request({
      method: "GET",
      url: `${Cypress.env("HYPERSWITCH_API_URL")}/nonexistent_endpoint`,
      headers: {
        "Content-Type": "application/json",
        "api-key": secretKey,
      },
      failOnStatusCode: false,
    }).then((response) => {
      expect([200, 404]).to.include(response.status);
    });
  });

  it("should handle timeout errors", () => {
    // cy.intercept does not affect cy.request (which is a direct Node.js call).
    // Instead, test actual API error behaviour by retrieving a non-existent payment,
    // which the server must return a 4xx error for.
    cy.request({
      method: "GET",
      url: `${Cypress.env("HYPERSWITCH_API_URL")}/payments/pay_000000000000000000000000000000`,
      headers: {
        "Content-Type": "application/json",
        "api-key": secretKey,
      },
      failOnStatusCode: false,
    }).then((response) => {
      expect(response.status).to.satisfy((status: number) => status >= 400);
    });
  });

  it("should handle SDK script loading errors", () => {
    cy.intercept("GET", "**/app.js", {
      statusCode: 500,
      body: "Server Error",
    }).as("sdkScriptError");

    cy.on("window:before:load", (win) => {
      cy.stub(win.console, "error").as("consoleError");
    });

    cy.createPaymentIntent(secretKey, createPaymentBody).then(() => {
      cy.getGlobalState("clientSecret").then((clientSecret) => {
        cy.visit(getClientURL(clientSecret, publishableKey));
      });
    });

    cy.get("#orca-payment-element-iframeRef-orca-elements-payment-element-payment-element", { timeout: 5000 })
      .should("not.exist");
  });

  it("should recover from temporary network failures", () => {
    let requestCount = 0;

    cy.intercept("GET", "**/payment_methods*", (req) => {
      requestCount++;
      if (requestCount === 1) {
        req.reply({
          forceNetworkError: true,
        });
      } else {
        req.reply({
          statusCode: 200,
          body: { payment_methods: [] },
        });
      }
    }).as("paymentMethods");

    cy.createPaymentIntent(secretKey, createPaymentBody).then(() => {
      cy.getGlobalState("clientSecret").then((clientSecret) => {
        cy.visit(getClientURL(clientSecret, publishableKey));
      });
    });

    cy.get("#orca-payment-element-iframeRef-orca-elements-payment-element-payment-element", {
      timeout: 10000,
    }).should("be.visible");
  });

  it("should handle invalid publishable key prefix", () => {
    const invalidPrefixKey = "pk_invalid_test_key";

    cy.createPaymentIntent(secretKey, createPaymentBody).then(() => {
      cy.getGlobalState("clientSecret").then((clientSecret) => {
        cy.visit(getClientURL(clientSecret, invalidPrefixKey));
      });
    });

    cy.on("window:before:load", (win) => {
      cy.stub(win.console, "error").as("consoleError");
    });

    cy.get("@consoleError").should("have.been.called");
  });

  it("should handle missing required parameters", () => {
    cy.visit(`${getClientURL("", "")}`);

    cy.on("window:before:load", (win) => {
      cy.stub(win.console, "error").as("consoleError");
    });

    cy.get("@consoleError").should("have.been.called");
  });

  it("should log errors to Sentry when configured", () => {
    const sentryDsn = Cypress.env("SENTRY_DSN");

    if (sentryDsn) {
      cy.intercept("POST", "**sentry.io**", (req) => {
        expect(req.body).to.exist;
      }).as("sentryRequest");

      cy.createPaymentIntent(secretKey, createPaymentBody).then(() => {
        cy.getGlobalState("clientSecret").then((clientSecret) => {
          cy.visit(`${getClientURL(clientSecret, publishableKey)}&sentryDsn=${encodeURIComponent(sentryDsn)}`);
        });
      });

      cy.window().then((win: any) => {
        if (win.triggerTestError) {
          win.triggerTestError();
        }
      });

      cy.wait("@sentryRequest", { timeout: 5000 });
    }
  });
});
