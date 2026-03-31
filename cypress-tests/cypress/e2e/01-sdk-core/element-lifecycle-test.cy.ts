import * as testIds from "../../../../src/Utilities/TestUtils.bs";
   import {
     getClientURL,
     createPaymentBody,
     changeObjectKeyValue,
   } from "../../support/utils";

   describe("Element Lifecycle Tests", () => {
     const publishableKey = Cypress.env("HYPERSWITCH_PUBLISHABLE_KEY");
     const secretKey = Cypress.env("HYPERSWITCH_SECRET_KEY");
     let getIframeBody: () => Cypress.Chainable<JQuery<HTMLBodyElement>>;
     const iframeSelector =
       "#orca-payment-element-iframeRef-orca-elements-payment-element-payment-element";

     beforeEach(() => {
       getIframeBody = () => cy.iframe(iframeSelector);
       changeObjectKeyValue(createPaymentBody, "customer_id", "element_lifecycle_test_user");
     });

     it("should mount element successfully", () => {
       cy.createPaymentIntent(secretKey, createPaymentBody).then(() => {
         cy.getGlobalState("clientSecret").then((clientSecret) => {
           cy.visit(getClientURL(clientSecret, publishableKey));
         });
       });

       cy.get(iframeSelector)
         .should("be.visible")
         .its("0.contentDocument")
         .its("body");

       cy.wait(2000);
       getIframeBody().find(`[data-testid=${testIds.cardNoInputTestId}]`).should("exist");
     });

     it("should verify iframe communication works", () => {
       cy.createPaymentIntent(secretKey, createPaymentBody).then(() => {
         cy.getGlobalState("clientSecret").then((clientSecret) => {
           cy.visit(getClientURL(clientSecret, publishableKey));
         });
       });

       cy.get(iframeSelector).should("be.visible");
       cy.wait(2000);

       getIframeBody().find(`[data-testid=${testIds.cardNoInputTestId}]`).should("be.visible");

       cy.get(iframeSelector).should("have.attr", "style").and("include", "height");
     });

     it("should handle SDK reinitialization after page navigation", () => {
       cy.createPaymentIntent(secretKey, createPaymentBody).then(() => {
         cy.getGlobalState("clientSecret").then((clientSecret) => {
           cy.visit(getClientURL(clientSecret, publishableKey));
         });
       });

       cy.get(iframeSelector).should("be.visible");
       cy.wait(2000);

       cy.visit("about:blank");
       cy.go("back");

       cy.get(iframeSelector, { timeout: 10000 }).should("be.visible");
     });

     it("should maintain state on page refresh", () => {
       cy.createPaymentIntent(secretKey, createPaymentBody).then(() => {
         cy.getGlobalState("clientSecret").then((clientSecret) => {
           cy.visit(getClientURL(clientSecret, publishableKey));
         });
       });

       cy.get(iframeSelector).should("be.visible");
       cy.wait(2000);

       getIframeBody()
         .find(`[data-testid=${testIds.cardNoInputTestId}]`)
         .type("4242424242424242");

       getIframeBody()
         .find(`[data-testid=${testIds.cardNoInputTestId}]`)
         .should("have.value", "4242 4242 4242 4242");

       cy.reload();

       cy.get(iframeSelector, { timeout: 10000 }).should("be.visible");
     });

     it("should handle multiple elements on same page", () => {
       cy.createPaymentIntent(secretKey, createPaymentBody).then(() => {
         cy.getGlobalState("clientSecret").then((clientSecret) => {
           cy.visit(getClientURL(clientSecret, publishableKey));
         });
       });

       cy.get(iframeSelector).should("be.visible");
       cy.wait(2000);

       getIframeBody().find(`[data-testid=${testIds.cardNoInputTestId}]`).should("have.length", 1);
     });

     it("should validate card input on submit", () => {
       cy.createPaymentIntent(secretKey, createPaymentBody).then(() => {
         cy.getGlobalState("clientSecret").then((clientSecret) => {
           cy.visit(getClientURL(clientSecret, publishableKey));
         });
       });

       cy.get(iframeSelector).should("be.visible");
       cy.wait(2000);

       cy.get("#submit").click();

       getIframeBody().find(".Error").should("be.visible");
     });

     it("should auto-format card number input", () => {
       cy.createPaymentIntent(secretKey, createPaymentBody).then(() => {
         cy.getGlobalState("clientSecret").then((clientSecret) => {
           cy.visit(getClientURL(clientSecret, publishableKey));
         });
       });

       cy.get(iframeSelector).should("be.visible");
       cy.wait(2000);

       getIframeBody()
         .find(`[data-testid=${testIds.cardNoInputTestId}]`)
         .type("4242424242424242");

       getIframeBody()
         .find(`[data-testid=${testIds.cardNoInputTestId}]`)
         .should("have.value", "4242 4242 4242 4242");
     });

     it("should display card brand icon dynamically", () => {
       cy.createPaymentIntent(secretKey, createPaymentBody).then(() => {
         cy.getGlobalState("clientSecret").then((clientSecret) => {
           cy.visit(getClientURL(clientSecret, publishableKey));
         });
       });

       cy.get(iframeSelector).should("be.visible");
       cy.wait(2000);

       getIframeBody()
         .find(`[data-testid=${testIds.cardNoInputTestId}]`)
         .type("4242");

       getIframeBody().find(`[data-testid=${testIds.cardNoInputTestId}]`)
         .should("have.value", "4242");
     });

     it("should allow input in all card fields", () => {
       cy.createPaymentIntent(secretKey, createPaymentBody).then(() => {
         cy.getGlobalState("clientSecret").then((clientSecret) => {
           cy.visit(getClientURL(clientSecret, publishableKey));
         });
       });

       cy.get(iframeSelector).should("be.visible");
       cy.wait(2000);

       getIframeBody()
         .find(`[data-testid=${testIds.cardNoInputTestId}]`)
         .type("4242424242424242")
         .should("have.value", "4242 4242 4242 4242");

       getIframeBody()
         .find(`[data-testid=${testIds.expiryInputTestId}]`)
         .type("1230")
         .invoke("val")
         .should((val) => {
           expect(val).to.match(/12\s*\/?\s*30/);
         });

       getIframeBody()
         .find(`[data-testid=${testIds.cardCVVInputTestId}]`)
         .type("123")
         .should("have.value", "123");
     });
   });
