// 4.6 ACH Direct Debit — Stripe — Happy Path
//
// Flow:
//   1. Create payment intent (Stripe profile, USD, US billing)
//      displaySavedPaymentMethods: false is passed via options so that:
//        a) Payment method tabs are shown directly (no saved-methods screen)
//        b) isVerifyPMAuthConnectorConfigured evaluates to false inside
//           ACHBankDebit → the manual form (FullName + Email + "Add bank
//           account") renders instead of the pmAuth/Plaid "Add Bank Details" flow
//   2. Select "ACH Debit" from the overflow dropdown (paymentMethodsSelect)
//      ACH lands in the <select> overflow because the iframe container is narrow
//      (~360 px) and cardsToRender = (width-40)/130 ≈ 2, leaving room for only
//      card + klarna in the visible tab row.
//   3. Fill Full Name + Email in the main form
//   4. Click "Add bank account" → fullscreen modal opens (#orca-fullscreen)
//   5. Fill Routing Number + Account Number in the modal
//   6. Click "Done" → modal closes
//   7. Click main submit button → payment confirmed → redirect to completion
//
// Stripe sandbox bank details:
//   Routing number : 110000000
//   Account number : 000123456789
//   Account type   : Checking

import * as testIds from "../../../../src/Utilities/TestUtils.bs";
import {
  getClientURL,
  createPaymentBody,
  changeObjectKeyValue,
  connectorProfileIdMapping,
  connectorEnum,
} from "../../support/utils";

describe("ACH Direct Debit Payment flow test (Stripe)", () => {
  const publishableKey = Cypress.env("HYPERSWITCH_PUBLISHABLE_KEY");
  const secretKey = Cypress.env("HYPERSWITCH_SECRET_KEY");
  let getIframeBody: () => Cypress.Chainable<JQuery<HTMLBodyElement>>;
  let getFullscreenBody: () => Cypress.Chainable<JQuery<HTMLBodyElement>>;
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
    getFullscreenBody = () => cy.iframe("#orca-fullscreen");

    cy.createPaymentIntent(secretKey, createPaymentBody).then(() => {
      cy.getGlobalState("clientSecret").then((clientSecret) => {
        // displaySavedPaymentMethods: false —
        //   • Shows payment method tabs directly (no saved-methods screen)
        //   • Forces manual ACH form (not the pmAuth/Plaid flow)
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

  it("should complete the ACH Direct Debit payment successfully", () => {
    cy.wait(2000);

    // ACH Debit lands in the overflow <select> dropdown (paymentMethodsSelect)
    // because the iframe is too narrow to show it as a visible tab.
    // Selecting via the native <select> fires a change event that updates the
    // SDK's selectedOption atom, which then swaps ACH into the visible tab row
    // and renders the manual ACH form.
    getIframeBody()
      .find(`[data-testid=${testIds.paymentMethodDropDownTestId}]`)
      .select("ach_debit");

    // Wait for the ACH manual form to render (FullName + Email + Add bank account)
    cy.wait(1500);

    // Fill Full Name and Email in the main form
    getIframeBody()
      .find(`[data-testid=${testIds.fullNameInputTestId}]`)
      .type("John Doe");
    getIframeBody()
      .find(`[data-testid=${testIds.emailInputTestId}]`)
      .type("test@example.com");

    // Click "Add bank account" to open the fullscreen bank details modal
    getIframeBody()
      .find('[aria-label="Click to Add bank account"]')
      .click();

    // Wait for the #orca-fullscreen iframe to mount and the modal to open
    cy.get("#orca-fullscreen", { timeout: 10000 }).should("be.visible");
    cy.wait(1500);

    // Fill Routing Number in the modal (Stripe sandbox: 110000000)
    getFullscreenBody()
      .find(`[data-testid=${testIds.routingNumberInputTestId}]`)
      .type("110000000");

    // Fill Account Number in the modal (Stripe sandbox test account)
    getFullscreenBody()
      .find(`[data-testid=${testIds.accountNumberInputTestId}]`)
      .type("000123456789");

    // Click "Done" to submit bank details and close the modal
    getFullscreenBody()
      .contains("Done")
      .click();

    // Wait for modal to animate closed
    cy.wait(1000);

    // Submit the payment — expects redirect to the return URL (completion page)
    getIframeBody()
      .get("#submit")
      .click()
      .then(() => {
        cy.url({ timeout: 15000 }).should("include", "localhost:9060");
      });
  });
});
