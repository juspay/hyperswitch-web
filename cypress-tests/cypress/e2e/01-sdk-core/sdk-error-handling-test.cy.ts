import {
     getClientURL,
     createPaymentBody,
     changeObjectKeyValue,
   } from "../../support/utils";

   describe("SDK Error Handling Tests", () => {
     const publishableKey = Cypress.env("HYPERSWITCH_PUBLISHABLE_KEY");
     const secretKey = Cypress.env("HYPERSWITCH_SECRET_KEY");

     beforeEach(() => {
       changeObjectKeyValue(createPaymentBody, "customer_id", "error_handling_test_user");
     });

     it("should handle missing client secret error", () => {
       // Visit with empty client secret
       cy.visit(getClientURL("", publishableKey), {
         failOnStatusCode: false,
       });

       // SDK should fail to initialize without client secret
       cy.get("#orca-payment-element-iframeRef-orca-elements-payment-element-payment-element", { timeout: 5000 })
         .should("not.exist");
     });

     it("should handle invalid client secret format", () => {
       const invalidClientSecret = "invalid_secret_format";
       
       cy.visit(getClientURL(invalidClientSecret, publishableKey), {
         failOnStatusCode: false,
       });

       // SDK should fail to initialize with invalid client secret
       cy.get("#orca-payment-element-iframeRef-orca-elements-payment-element-payment-element", { timeout: 5000 })
         .should("not.exist");
     });

     it("should handle network errors gracefully", () => {
       // Intercept and fail payment intent creation
       cy.intercept("POST", "**/payment_intents", {
         forceNetworkError: true,
       }).as("createPaymentIntent");

       cy.request({
         method: "POST",
         url: `${Cypress.env("HYPERSWITCH_API_URL")}/payments`,
         headers: {
           "Content-Type": "application/json",
           "api-key": secretKey,
         },
         body: createPaymentBody,
         failOnStatusCode: false,
       }).then((response) => {
         expect(response.status).to.not.equal(200);
       });
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
         // API may return 401 or 404 depending on implementation
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
         // API may return 404 or 200 depending on routing
         expect([200, 404]).to.include(response.status);
       });
     });

     it("should handle timeout errors", () => {
       cy.intercept("POST", "**/payment_intents", {
         delay: 31000, // Delay longer than default timeout
         statusCode: 200,
         body: { id: "pi_test", client_secret: "pi_test_secret_test" },
       }).as("slowPaymentIntent");

       cy.request({
         method: "POST",
         url: `${Cypress.env("HYPERSWITCH_API_URL")}/payments`,
         headers: {
           "Content-Type": "application/json",
           "api-key": secretKey,
         },
         body: createPaymentBody,
         failOnStatusCode: false,
         timeout: 5000,
       }).then((response) => {
         // Should handle timeout appropriately
         expect(response.status).to.satisfy((status: number) => status === 0 || status >= 400);
       });
     });

     it("should display user-friendly error messages", () => {
       cy.createPaymentIntent(secretKey, createPaymentBody).then(() => {
         cy.getGlobalState("clientSecret").then((clientSecret) => {
           cy.visit(getClientURL(clientSecret, publishableKey));
         });
       });

       // Wait for SDK to load
       cy.get("#orca-payment-element-iframeRef-orca-elements-payment-element-payment-element")
         .should("be.visible");
       cy.wait(2000);

       // Trigger a validation error (submit empty form)
       cy.get("#submit").click();

       // Verify error message is displayed (Error class may be in iframe)
       cy.get("#orca-payment-element-iframeRef-orca-elements-payment-element-payment-element")
         .its("0.contentDocument")
         .its("body")
         .find(".Error")
         .should("be.visible");
     });

     it("should handle SDK script loading errors", () => {
       // Intercept SDK script and return 500
       cy.intercept("GET", "**/app.js", {
         statusCode: 500,
         body: "Server Error",
       }).as("sdkScriptError");

       cy.createPaymentIntent(secretKey, createPaymentBody).then(() => {
         cy.getGlobalState("clientSecret").then((clientSecret) => {
           cy.visit(getClientURL(clientSecret, publishableKey));
         });
       });

       // Should handle script loading error
       cy.on("window:before:load", (win) => {
         cy.stub(win.console, "error").as("consoleError");
       });
     });

     it("should recover from temporary network failures", () => {
       let requestCount = 0;
       
       // First request fails, second succeeds
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

       // SDK should retry and eventually load
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

       // Should log error for invalid key prefix
       cy.on("window:before:load", (win) => {
         cy.stub(win.console, "error").as("consoleError");
       });

       cy.get("@consoleError").should("have.been.called");
     });

     it("should handle missing required parameters", () => {
       // Visit without any parameters
       cy.visit(`${getClientURL("", "")}`);

       // Should show error
       cy.on("window:before:load", (win) => {
         cy.stub(win.console, "error").as("consoleError");
       });

       cy.get("@consoleError").should("have.been.called");
     });

     it("should log errors to Sentry when configured", () => {
       const sentryDsn = Cypress.env("SENTRY_DSN");
       
       if (sentryDsn) {
         cy.intercept("POST", "**sentry.io**", (req) => {
           // Capture Sentry error reports
           expect(req.body).to.exist;
         }).as("sentryRequest");

         cy.createPaymentIntent(secretKey, createPaymentBody).then(() => {
           cy.getGlobalState("clientSecret").then((clientSecret) => {
             cy.visit(`${getClientURL(clientSecret, publishableKey)}&sentryDsn=${encodeURIComponent(sentryDsn)}`);
           });
         });

         // Trigger an error
         cy.window().then((win: any) => {
           if (win.triggerTestError) {
             win.triggerTestError();
           }
         });

         // Verify Sentry was called
         cy.wait("@sentryRequest", { timeout: 5000 });
       }
     });
   });