// ***********************************************
// This example commands.js shows you how to
// create various custom commands and overwrite
// existing commands.
//
// For more comprehensive examples of custom
// commands please read more here:
// https://on.cypress.io/custom-commands
// ***********************************************
//
//
// -- This is a parent command --
// Cypress.Commands.add('login', (email, password) => { ... })
//
//
// -- This is a child command --
// Cypress.Commands.add('drag', { prevSubject: 'element'}, (subject, options) => { ... })
//
//
// -- This is a dual command --
// Cypress.Commands.add('dismiss', { prevSubject: 'optional'}, (subject, options) => { ... })
//
//
// -- This will overwrite an existing command --
// Cypress.Commands.overwrite('visit', (originalFn, url, options) => { ... })
import "cypress-iframe";
import { createPaymentBody } from "./utils"
import * as testIds from "../../../src/Utilities/TestUtils.bs";
// commands.js or your custom support file
const iframeSelector =
  "#orca-payment-element-iframeRef-orca-elements-payment-element-payment-element";

let globalState = {};

Cypress.Commands.add("enterValueInIframe", (selector, value) => {
  cy.iframe(iframeSelector)
    .find(`[data-testid=${selector}]`)
    .should("be.visible")
    .type(value);
});

Cypress.Commands.add("selectValueInIframe", (selector, value) => {
  cy.iframe(iframeSelector)
    .find(`[data-testid=${selector}]`)
    .should("be.visible")
    .select(value);
});

Cypress.Commands.add("hardReload", () => {
  cy.wrap(
    Cypress.automation("remote:debugger:protocol", {
      command: "Network.clearBrowserCache",
    })
  );
});

Cypress.Commands.add(
  "testDynamicFields",
  (customerData, testIdsToRemoveArr = [], isThreeDSEnabled = false) => {
    const mapping = {
      [testIds.cardNoInputTestId]: customerData.cardNo,
      [testIds.expiryInputTestId]: customerData.cardExpiry,
      [testIds.cardCVVInputTestId]: customerData.cardCVV,
      [testIds.fullNameInputTestId]: customerData.cardHolderName,
      [testIds.cardHolderNameInputTestId]: customerData.cardHolderName,
      [testIds.emailInputTestId]: customerData.email,
      [testIds.addressLine1InputTestId]: customerData.address,
      [testIds.cityInputTestId]: customerData.city,
      [testIds.countryDropDownTestId]: customerData.country,
      [testIds.stateDropDownTestId]: customerData.state,
      [testIds.postalCodeInputTestId]: customerData.postalCode,
    };
    if (isThreeDSEnabled) {
      mapping[testIds.cardNoInputTestId] = customerData.threeDSCardNo;
    }
    let publishableKey = "pk_snd_3b33cd9404234113804aa1accaabe22f";
    let clientSecret: string;
    cy.request({
      method: "GET",
      url: "http://localhost:5252/create-payment-intent",
    }).then((response: { body: { clientSecret: string } }) => {
      clientSecret = response.body.clientSecret;

      cy.request({
        method: "GET",
        url: `https://sandbox.hyperswitch.io/account/payment_methods?client_secret=${clientSecret}`,
        headers: {
          "Content-Type": "application/json",
          "api-key": publishableKey,
        }, // Replace with your API endpoint
      }).then((response) => {
        // Check the response status
        console.warn(response.body.payment_methods);

        let paymentMethods = response.body.payment_methods;

        const foundElement = paymentMethods.find(
          (element) => element.payment_method === "card"
        );

        const ele = foundElement.payment_method_types.find(
          (element) => element.payment_method_type === "debit"
        );
        console.log(ele.required_fields);

        let requiredFieldsArr = ele.required_fields;
        let idArr = [];
        for (const key in requiredFieldsArr) {
          idArr.push(testIds.fieldTestIdMapping[key]);
        }

        const countryIndex = idArr.indexOf("Country");
        const stateIndex = idArr.indexOf("State");

        // Move "State" after "Country"
        if (
          countryIndex !== -1 &&
          stateIndex !== -1 &&
          stateIndex < countryIndex
        ) {
          idArr.splice(stateIndex, 1);
          idArr.splice(countryIndex, 0, "State");
        }

        console.warn(idArr);

        expect(response.status).to.eq(200);

        idArr = idArr.filter((item) => !testIdsToRemoveArr.includes(item));

        idArr.forEach((ele) => {
          cy.iframe(iframeSelector)
            .find(`[data-testid=${ele}]`)
            .should("be.visible")
            .type(mapping[ele], { force: true });

          if (ele === "Country" || ele === "State") {
            cy.iframe(iframeSelector)
              .find(`[data-testid=${ele}]`)
              .should("be.visible")
              .select(mapping[ele]);
          }
        });
      });
    });
  }
);


Cypress.Commands.add("createPaymentIntent", (secretKey: string, createPaymentBody: any) => {
  return cy
    .request({
      method: "POST",
      url: "https://sandbox.hyperswitch.io/payments",
      headers: {
        "Content-Type": "application/json",
        Accept: "application/json",
        "api-key": secretKey,
      },
      body: JSON.stringify(createPaymentBody),
    })
    .then((response) => {
      expect(response.headers["content-type"]).to.include("application/json");
      expect(response.body).to.have.property("client_secret");
      const clientSecret = response.body.client_secret;
      cy.log(clientSecret);
      cy.log(response.toString());

      globalState["clientSecret"] = clientSecret;
    });
});

Cypress.Commands.add("getGlobalState", (key: any) => {
  return globalState[key];
});

Cypress.Commands.add("fillCardDetails", (iframeSelector: string, cardData: any) => {
  const getIframeBody = () => cy.iframe(iframeSelector);

  // Find and interact with card details input fields within the iframe
  getIframeBody().find(`[data-testid=${testIds.addNewCardIcon}]`).click();
  getIframeBody().find("[data-testid=cardNoInput]").type(cardData.cardNo);
  getIframeBody().find("[data-testid=expiryInput]").type(cardData.expiryDate);
  getIframeBody().find("[data-testid=cvvInput]").should("be.ok").type(cardData.cvc);

  // Submit the payment details
  getIframeBody().get("#submit").click();
});

