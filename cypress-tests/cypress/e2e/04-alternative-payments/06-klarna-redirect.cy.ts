// 4.1 Klarna — Redirect-Back Happy Path (redirect-out scope)
//
// Flow:
//   1. Create payment intent (Stripe profile, USD, US billing)
//   2. Click "use new payment methods" (addNewCardIcon) to expand the list
//   3. Select "Klarna" from the payment method list
//   4. Click main submit button
//   5. Assert browser redirects away from localhost (to Klarna / sandbox.hyperswitch.io)
//
// Note: "redirect-back" is scoped to verifying the redirect-OUT to Klarna's
// hosted page. Full round-trip automation (cy.origin on Klarna's page) requires
// Klarna sandbox test credentials and is out of scope for this test.
//
// Connector: Stripe (USD, US) — Adyen Klarna sandbox returns status=failed
// immediately without redirecting, so Stripe is used instead.

import * as testIds from "../../../../src/Utilities/TestUtils.bs";
import {
  getClientURL,
  createPaymentBody,
  changeObjectKeyValue,
  connectorProfileIdMapping,
  connectorEnum,
} from "../../support/utils";

describe("Klarna Redirect-Back Happy Path (Stripe)", () => {
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
        cy.visit(getClientURL(clientSecret, publishableKey));
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

  it("should redirect to Klarna checkout page on submission (happy path)", () => {
    cy.wait(2000);

    // "addNewCardIcon" is the "use new payment methods" button shown when the
    // customer has saved methods. Clicking it reveals the full payment method list.
    getIframeBody()
      .find(`[data-testid=${testIds.addNewCardIcon}]`)
      .click();

    // Wait for the payment method list to render
    cy.wait(1000);

    getIframeBody()
      .contains("div", "Klarna")
      .click();

    // Give the SDK time to register Klarna as the active payment method
    // (InfoElement has no fields, so there is no implicit wait from form rendering)
    cy.wait(1500);

    // Submit — triggers hyper.confirmPayment which should redirect to Klarna
    getIframeBody()
      .get("#submit")
      .click();

    // Assert the browser leaves localhost and lands on Klarna / Hyperswitch sandbox
    cy.url({ timeout: 20000 }).should(
      "match",
      /klarna|sandbox\.hyperswitch\.io/,
    );
  });
});
