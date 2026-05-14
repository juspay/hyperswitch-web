// 4.2 Afterpay / Clearpay — Redirect-Back Happy Path (redirect-out scope)
//
// Flow:
//   1. Create payment intent (Stripe profile, USD, US billing)
//      displaySavedPaymentMethods: false is passed so payment method tabs are
//      shown directly (no saved-methods screen / addNewCardIcon step needed).
//   2. Select "afterpay_clearpay" from the overflow dropdown (paymentMethodsSelect)
//      Afterpay lands in the <select> overflow because the iframe is narrow
//      (~360 px wide) and cardsToRender = (width-40)/130 ≈ 2, leaving room for
//      only card + klarna in the visible tab row.
//   3. Click main submit button
//   4. Assert browser redirects away from localhost (to Afterpay / Stripe / Hyperswitch sandbox)
//
// Note: "redirect-back" is scoped to verifying the redirect-OUT only.
// Full round-trip automation requires Afterpay sandbox credentials (out of scope).
//
// Connector: Stripe (USD, US).

import * as testIds from "../../../../src/Utilities/TestUtils.bs";
import {
  getClientURL,
  createPaymentBody,
  changeObjectKeyValue,
  connectorProfileIdMapping,
  connectorEnum,
} from "../../support/utils";

describe("Afterpay / Clearpay Redirect-Back Happy Path (Stripe)", () => {
  const publishableKey = Cypress.env("HYPERSWITCH_PUBLISHABLE_KEY");
  const secretKey = Cypress.env("HYPERSWITCH_SECRET_KEY");
  let getIframeBody: () => Cypress.Chainable<JQuery<HTMLBodyElement>>;
  const iframeSelector =
    "#orca-payment-element-iframeRef-orca-elements-payment-element-payment-element";

  // Configure payment body for Stripe + USD + US billing
  changeObjectKeyValue(
    createPaymentBody,
    "profile_id",
    connectorProfileIdMapping.get(connectorEnum.STRIPE) ?? "",
  );
  changeObjectKeyValue(createPaymentBody, "currency", "USD");
  changeObjectKeyValue(createPaymentBody, "billing", {
    address: {
      line1: "1467",
      line2: "Harrison Street",
      line3: "Harrison Street",
      city: "San Francisco",
      state: "California",
      zip: "94122",
      country: "US",
      first_name: "John",
      last_name: "Doe",
    },
    phone: {
      number: "8056594427",
      country_code: "+1",
    },
  });
  changeObjectKeyValue(createPaymentBody, "shipping", {
    address: {
      line1: "1467",
      line2: "Harrison Street",
      line3: "Harrison Street",
      city: "San Francisco",
      state: "California",
      zip: "94122",
      country: "US",
      first_name: "John",
      last_name: "Doe",
    },
    phone: {
      number: "8056594427",
      country_code: "+1",
    },
  });

  beforeEach(() => {
    getIframeBody = () => cy.iframe(iframeSelector);

    cy.createPaymentIntent(secretKey, createPaymentBody).then(() => {
      cy.getGlobalState("clientSecret").then((clientSecret) => {
        // displaySavedPaymentMethods: false — shows payment method tabs
        // immediately so we can select directly from the overflow dropdown.
        cy.visit(
          getClientURL(
            clientSecret,
            publishableKey,
            undefined,
            undefined,
            undefined,
            { displaySavedPaymentMethods: false },
          ),
        );
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

  it("should redirect to Afterpay/Clearpay checkout page on submission (happy path)", () => {
    cy.wait(2000);

    // Afterpay lands in the overflow <select> dropdown (paymentMethodsSelect).
    // Selecting via the native <select> fires a change event that updates the
    // SDK's selectedOption atom and swaps Afterpay into the visible tab row.
    getIframeBody()
      .find(`[data-testid=${testIds.paymentMethodDropDownTestId}]`)
      .select("afterpay_clearpay");

    // Give the SDK time to register Afterpay as the active payment method
    // (InfoElement has no fields, so there is no implicit wait from form rendering)
    cy.wait(1500);

    // Submit — triggers hyper.confirmPayment → redirect to Afterpay hosted page.
    // Stripe routes Afterpay through buy.stripe.com (test mode) or via
    // sandbox.hyperswitch.io as an intermediate redirect.
    getIframeBody()
      .get("#submit")
      .click();

    cy.url({ timeout: 20000 }).should(
      "match",
      /afterpay|clearpay|sandbox\.hyperswitch\.io|stripe\.com/,
    );
  });
});
