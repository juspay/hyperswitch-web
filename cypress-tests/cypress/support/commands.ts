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
import { createPaymentBody } from "./utils";
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
    }),
  );
});

Cypress.Commands.add(
  "testDynamicFields",
  (
    customerData,
    testIdsToRemoveArr = [],
    isThreeDSEnabled = false,
    publishableKey,
  ) => {
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

    let clientSecret: string;
    cy.request({
      method: "GET",
      url: "http://localhost:5252/create-payment-intent",
    }).then((response: { body: { clientSecret: string } }) => {
      clientSecret = response.body.clientSecret;

      cy.request({
        method: "GET",
      url: `${Cypress.env("HYPERSWITCH_API_URL")}/account/payment_methods?client_secret=${clientSecret}`,
        headers: {
          "Content-Type": "application/json",
          "api-key": publishableKey,
        }, // Replace with your API endpoint
      }).then((response) => {
        // Check the response status
        console.warn(response.body.payment_methods);

        let paymentMethods = response.body.payment_methods;

        const foundElement = paymentMethods.find(
          (element) => element.payment_method === "card",
        );

        const ele = foundElement.payment_method_types.find(
          (element) => element.payment_method_type === "debit",
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
  },
);

Cypress.Commands.add(
  "createPaymentIntent",
  (secretKey: string, createPaymentBody: any) => {
    // Ensure profile_id is set from the connector profile IDs (populated by
    // the before() hook in e2e.ts).  If the test hasn't overridden it, use
    // the default stripe profile.
    if (!createPaymentBody.profile_id) {
      const profileIds = Cypress.env("CONNECTOR_PROFILE_IDS") as Record<string, string> | undefined;
      createPaymentBody.profile_id = profileIds?.stripe ?? "";
    }

    return cy
      .request({
        method: "POST",
        url: `${Cypress.env("HYPERSWITCH_API_URL")}/payments`,
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
  },
);

Cypress.Commands.add("getGlobalState", (key: any) => {
  return globalState[key];
});

Cypress.Commands.add("nestedIFrame", (selector, callback) => {
  cy.iframe("#orca-fullscreen")
    .find(selector)
    .should("exist")
    .should("be.visible")
    .then(($ele) => {
      const $body = $ele.contents().find("body");
      callback($body);
    });
});

// Smart wait utilities to replace hard waits
// Note: iframeSelector is already declared at the top of this file

Cypress.Commands.add("waitForSDKReady", () => {
  return cy
    .get(iframeSelector, { timeout: 15000 })
    .should("be.visible")
    .its("0.contentDocument")
    .its("body")
    .should("not.be.empty")
    .then(() => {
      // Wait for the card number input to be rendered inside the iframe,
      // ensuring React has fully mounted the card form and registered
      // the submitCallback before any test interaction.
      cy.iframe(iframeSelector)
        .find('[data-testid="cardNoInput"]', { timeout: 15000 })
        .should("be.visible");
    });
});

Cypress.Commands.add("safeType", { prevSubject: "element" }, (subject, text, options = {}) => {
  cy.wrap(subject)
    .should("not.be.disabled")
    .should("be.visible")
    .clear({ force: true })
    .type(text, { delay: 50, ...options });
  return cy.wrap(subject);
});

Cypress.Commands.add("safeClick", { prevSubject: "element" }, (subject) => {
  cy.wrap(subject)
    .should("not.be.disabled")
    .should("be.visible")
    .click({ force: true });
  return cy.wrap(subject);
});

Cypress.Commands.add("enterCardDetails", (cardDetails: any) => {
  const iframeBody = () => cy.iframe(iframeSelector);
  
  iframeBody()
    .find('[data-testid="cardNoInput"]')
    .safeType(cardDetails.cardNo);
  
  iframeBody()
    .find('[data-testid="expiryInput"]')
    .safeType(cardDetails.card_exp_month + cardDetails.card_exp_year);
  
  iframeBody()
    .find('[data-testid="cvvInput"]')
    .safeType(cardDetails.cvc);
});

// ---------------------------------------------------------------------------
// selectPaymentMethod
//
// Handles the two SDK UI states for payment method selection:
//
//   1. Saved cards exist → SDK shows a saved-card list with an "Add New Card"
//      button.  We click it first, then select the payment method.
//
//   2. No saved cards (fresh merchant) → SDK shows payment method tabs /
//      accordion directly.  We skip the "Add New Card" click.
//
// Usage:
//   cy.selectPaymentMethod(getIframeBody, "Crypto");
//   cy.selectPaymentMethod(getIframeBody, "Cash / Voucher");
// ---------------------------------------------------------------------------

Cypress.Commands.add(
  "selectPaymentMethod",
  (getIframeBody: () => Cypress.Chainable<JQuery<HTMLBodyElement>>, methodName: string) => {
    getIframeBody().then(($body) => {
      // If the "Add New Card" button exists (saved cards scenario), click it
      // first to reveal the payment method picker.
      if ($body.find('[data-testid="addNewCard"]').length > 0) {
        getIframeBody().find('[data-testid="addNewCard"]').click();
      }
      // Select the payment method by name — don't restrict to a specific
      // element type because the SDK renders payment methods differently
      // depending on whether saved cards exist (div vs button/li/span).
      getIframeBody().contains(methodName).click();
    });
  },
);

// ---------------------------------------------------------------------------
// selectPaymentMethodOrSkip
//
// Same as selectPaymentMethod, but skips the test gracefully when the
// payment method tab is not present in the SDK. This is common with a
// freshly-created merchant where the connector may not return the expected
// payment method for the test amount / currency.
//
// Usage:
//   cy.selectPaymentMethodOrSkip(getIframeBody, "Crypto").then((skipped) => {
//     if (skipped) return;
//     // rest of test
//   });
// ---------------------------------------------------------------------------

Cypress.Commands.add(
  "selectPaymentMethodOrSkip",
  (getIframeBody: () => Cypress.Chainable<JQuery<HTMLBodyElement>>, methodName: string) => {
    return getIframeBody().then(($body) => {
      // If the "Add New Card" button exists, click it first.
      if ($body.find('[data-testid="addNewCard"]').length > 0) {
        getIframeBody().find('[data-testid="addNewCard"]').click();
      }
      // Check if the payment method text is present anywhere.
      const hasMethod = $body.text().includes(methodName);
      if (!hasMethod) {
        throw new Error(
          `Payment method "${methodName}" is not available. ` +
          `This usually means the connector credentials are missing in creds.json ` +
          `or the MCA was not created during setup. ` +
          `Check that creds.json has a valid entry for this connector.`
        );
      }

      // The SDK renders payment methods in two ways:
      // 1. As tabs (<button class="Tab">) — clickable via .click()
      // 2. As a dropdown (<select data-testid="paymentMethodsSelect">) — needs .select()
      //    When there are many payment methods, some overflow into the dropdown.
      //    Clicking an <option> element doesn't trigger the onChange handler,
      //    so we must use cy.select() for dropdown options.

      const $tab = $body.find("button.Tab").filter((_, el) =>
        Cypress.$(el).text().includes(methodName)
      );

      if ($tab.length > 0) {
        // Payment method is rendered as a clickable tab.
        getIframeBody().contains(methodName).click({ force: true });
      } else {
        // Payment method is in the dropdown <select>.
        // Map display names to the paymentMethodName values used in <option value="...">.
        const displayNameToValue: Record<string, string> = {
          "iDEAL": "ideal",
          "EPS": "eps",
          "Blik": "blik",
          "Interac": "interac",
          "Mifinity": "mifinity",
          "Crypto": "crypto_currency",
          "Cash / Voucher": "classic",
          "E-Voucher": "evoucher",
          "Card": "card",
        };
        const selectValue = displayNameToValue[methodName] || methodName.toLowerCase();
        getIframeBody()
          .find('[data-testid="paymentMethodsSelect"]')
          .should("exist")
          .select(selectValue, { force: true });
      }
      return cy.wrap(false);
    });
  },
);
