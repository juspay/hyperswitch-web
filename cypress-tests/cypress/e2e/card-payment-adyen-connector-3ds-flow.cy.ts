import {
    adyenTestCard,
    changeObjectKeyValue,
    confirmBody,
    createPaymentBody,
    getClientURL,
  } from "cypress/support/utils";
  import { CardData } from "cypress/support/types";
  
  describe("Card Payment for Adyen Connector for 3DS Flow Test", () => {
    const publishableKey = Cypress.env("HYPERSWITCH_PUBLISHABLE_KEY");
    const secretKey = Cypress.env("HYPERSWITCH_SECRET_KEY");
    let getIframeBody: () => Cypress.Chainable<JQuery<HTMLBodyElement>>;
    const iframeSelector =
      "#orca-payment-element-iframeRef-orca-elements-payment-element-payment-element";
  
    const cardData: CardData = {
      cardNo: "4212 3456 7891 0006",
      expiryDate: "03/30",
      cvc: "737",
    };
    // const cardData: CardData = {
    //   cardNo: adyenTestCard,
    //   expiryDate: adyenExpiryDate,
    //   cvc: adyenCvc,
    // }
    changeObjectKeyValue(
      createPaymentBody,
      "profile_id",
      Cypress.env("PROFILE_ID")
    );
    changeObjectKeyValue(createPaymentBody, "authentication_type", "three_ds");
    createPaymentBody["request_external_three_ds_authentication"] = true;
  
    beforeEach(() => {
      getIframeBody = () => cy.iframe(iframeSelector);
      cy.createPaymentIntent(secretKey, createPaymentBody).then(() => {
        cy.getGlobalState("clientSecret").then((clientSecret) => {
          cy.visit(getClientURL(clientSecret, publishableKey));
        });
      });
    });
  
    // Test for rendering the correct page title
    it("title rendered correctly", () => {
      cy.contains("Hyperswitch Unified Checkout").should("be.visible");
    });
  
    it("orca-payment-element iframe loaded", () => {
      cy.get(
        "#orca-payment-element-iframeRef-orca-elements-payment-element-payment-element"
      )
        .should("be.visible")
        .its("0.contentDocument")
        .its("body");
    });
  
    // Test to fill in card details and complete payment
    it("should check card payment for adyen connector 3DS flow", function () {
      cy.fillCardDetails(iframeSelector, cardData);
  
      // Validate URL redirection to Adyen connector for 3DS Auth
      cy.url()
        .should("include", "adyen.com")
        .then((url) => {
          // Log the URL to the Cypress command log
          cy.log(`Current URL: ${url}`);
        });
  
      cy.wait(5000);
      cy.get("#root").should("be.ok");
  
      // Interact with the 3DS secure authentication iframe
      cy.iframe(".adyen-checkout__iframe").find("[name=answer]").type("password");
  
      cy.iframe(".adyen-checkout__iframe").find("#buttonSubmit").click();
      cy.wait(2000); // Wait for confirmation message to display
      cy.contains("Thanks for your order!").should("be.visible");
    });
  });
  