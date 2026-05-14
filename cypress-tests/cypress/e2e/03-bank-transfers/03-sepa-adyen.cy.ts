// 4.7 SEPA Direct Debit — Adyen — Happy Path
//
// Flow:
//   1. Create payment intent (Adyen profile, EUR, DE billing)
//      displaySavedPaymentMethods: false — skips any saved-methods screen and
//      shows the payment method list directly.
//   2. Select "sepa_debit" from the overflow <select> dropdown
//      SEPA lands in the overflow because the iframe is narrow (~360px) and
//      cardsToRender = (width-40)/130 ≈ 2, leaving room for only card + klarna.
//   3. SepaBankDebit renders <DynamicFields> inline (no modal, no
//      "Add bank account" button) because pmAuth is not configured for SEPA
//      on the Adyen profile — isVerifyPMAuthConnectorConfigured evaluates to false.
//   4. Fill the IBAN input (name="bankAccountNumber") with the Adyen sandbox IBAN.
//      The billing name fields (first_name, last_name) are pre-filled from the
//      payment body billing address so they are not rendered as inputs.
//   5. Click main submit button → Adyen processes the debit and redirects to the
//      return URL (localhost:9060 completion page).
//
// Adyen sandbox IBAN: DE87200400104531460600

import * as testIds from "../../../../src/Utilities/TestUtils.bs";
import {
  getClientURL,
  createPaymentBody,
  changeObjectKeyValue,
  connectorProfileIdMapping,
  connectorEnum,
} from "../../support/utils";

describe("SEPA Direct Debit Payment flow test (Adyen)", () => {
  const publishableKey = Cypress.env("HYPERSWITCH_PUBLISHABLE_KEY");
  const secretKey = Cypress.env("HYPERSWITCH_SECRET_KEY");
  let getIframeBody: () => Cypress.Chainable<JQuery<HTMLBodyElement>>;
  const iframeSelector =
    "#orca-payment-element-iframeRef-orca-elements-payment-element-payment-element";

  // Configure payment body for Adyen + EUR + DE billing
  changeObjectKeyValue(
    createPaymentBody,
    "profile_id",
    connectorProfileIdMapping.get(connectorEnum.ADYEN) ?? "",
  );
  changeObjectKeyValue(createPaymentBody, "currency", "EUR");
  changeObjectKeyValue(createPaymentBody, "billing", {
    address: {
      line1: "Unter den Linden 1",
      line2: "",
      line3: "",
      city: "Berlin",
      state: "Berlin",
      zip: "10117",
      country: "DE",
      first_name: "Hans",
      last_name: "Müller",
    },
    email: "hyperswitch_sdk_demo_id@gmail.com",
    phone: {
      number: "3012345678",
      country_code: "+49",
    },
  });
  changeObjectKeyValue(createPaymentBody, "shipping", {
    address: {
      line1: "Unter den Linden 1",
      line2: "",
      line3: "",
      city: "Berlin",
      state: "Berlin",
      zip: "10117",
      country: "DE",
      first_name: "Hans",
      last_name: "Müller",
    },
    phone: {
      number: "3012345678",
      country_code: "+49",
    },
  });

  beforeEach(() => {
    getIframeBody = () => cy.iframe(iframeSelector);

    cy.createPaymentIntent(secretKey, createPaymentBody).then(() => {
      cy.getGlobalState("clientSecret").then((clientSecret) => {
        // displaySavedPaymentMethods: false —
        //   • Shows payment method list directly (no saved-methods screen)
        //   • isVerifyPMAuthConnectorConfigured = false on Adyen (no pmAuth for SEPA)
        //     so DynamicFields renders inline — no modal needed
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

  it("should complete the SEPA Direct Debit payment successfully", () => {
    cy.wait(2000);

    // SEPA Debit lands in the overflow <select> because the iframe is too narrow
    // to show it as a visible tab alongside card and klarna.
    getIframeBody()
      .find(`[data-testid=${testIds.paymentMethodDropDownTestId}]`)
      .select("sepa_debit");

    // Wait for SepaBankDebit to render DynamicFields
    cy.wait(1500);

    // Fill the IBAN — DynamicFields renders it as input[name="bankAccountNumber"].
    // Billing name (first_name/last_name) is pre-filled from the payment body
    // so it is not rendered as an input field.
    getIframeBody()
      .find('input[name="bankAccountNumber"]')
      .type("DE87200400104531460600");

    // Submit — Adyen processes the SEPA debit and redirects to the return URL
    getIframeBody()
      .get("#submit")
      .click()
      .then(() => {
        cy.url({ timeout: 15000 }).should("include", "localhost:9060");
      });
  });
});
