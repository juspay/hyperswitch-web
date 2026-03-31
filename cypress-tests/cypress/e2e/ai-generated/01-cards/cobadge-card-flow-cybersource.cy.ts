/**
 * Cobadge Card Flow - Cybersource
 * Tests the cobadge (multi-brand) card flow where a single card number
 * matches multiple card networks (e.g., Visa + CartesBancaires).
 *
 * Flow:
 * 1. Enter a cobadge card number (4010061700000021) that matches both Visa and CartesBancaires
 * 2. Verify the card brand dropdown appears with both options
 * 3. Select a brand from the dropdown
 * 4. Complete the payment with the selected brand
 *
 * DOM structure of the cobadge dropdown:
 * - It's a native <select> inside a div with class "hellow-rodl"
 * - Options: disabled "Select a card brand", then brand names (e.g., "Visa", "CartesBancaires")
 * - Dropdown only appears when card number >= 16 digits AND matches multiple brands
 */
import * as testIds from "../../../../../src/Utilities/TestUtils.bs";
import {
  getClientURL,
  createPaymentBody,
  changeObjectKeyValue,
  connectorProfileIdMapping,
  connectorEnum,
} from "../../../support/utils";
import { cobadgeCards, cobadgeCardBrands } from "../../../support/cards";

describe("Cobadge Card Flow - Cybersource", () => {
  const publishableKey = Cypress.env("HYPERSWITCH_PUBLISHABLE_KEY");
  const secretKey = Cypress.env("HYPERSWITCH_SECRET_KEY");
  let getIframeBody: () => Cypress.Chainable<JQuery<HTMLBodyElement>>;
  const iframeSelector =
    "#orca-payment-element-iframeRef-orca-elements-payment-element-payment-element";

  const { cardNo, card_exp_month, card_exp_year, cvc } =
    cobadgeCards.visaCartesBancaires;

  beforeEach(() => {
    getIframeBody = () => cy.iframe(iframeSelector);

    changeObjectKeyValue(
      createPaymentBody,
      "profile_id",
      connectorProfileIdMapping.get(connectorEnum.CYBERSOURCE)
    );
    changeObjectKeyValue(
      createPaymentBody,
      "authentication_type",
      "no_three_ds"
    );
    changeObjectKeyValue(
      createPaymentBody,
      "customer_id",
      `cobadge_cypress_${Date.now()}`
    );

    cy.createPaymentIntent(secretKey, createPaymentBody).then(() => {
      cy.getGlobalState("clientSecret").then((clientSecret) => {
        cy.visit(getClientURL(clientSecret, publishableKey));
      });
    });

    cy.waitForSDKReady();
  });

  it("should display card brand dropdown for cobadge card (Visa + CartesBancaires)", () => {
    // Enter the cobadge card number
    getIframeBody()
      .find(`[data-testid=${testIds.cardNoInputTestId}]`)
      .safeType(cardNo);

    cy.wait(1500);

    // The cobadge dropdown is a native <select> inside a div with class "hellow-rodl".
    // It appears once the card number is >= 16 digits and matches multiple brands.
    getIframeBody()
      .find(".hellow-rodl select", { timeout: 10000 })
      .should("exist");

    // Expand the native <select> by setting its size attribute so all options are visible
    // (native dropdowns cannot be opened programmatically, but size > 1 renders as a listbox)
    getIframeBody()
      .find(".hellow-rodl select")
      .then(($select) => {
        $select.attr("size", $select.find("option").length);
        $select.css({ width: "auto", position: "absolute", "z-index": "9999" });
      });

    cy.wait(2000);

    // Verify both brand options are present in the dropdown
    getIframeBody()
      .find(".hellow-rodl select")
      .find("option")
      .should("have.length.at.least", 3) // disabled placeholder + at least 2 brands
      .then(($options) => {
        const optionTexts = [...$options].map((opt) => opt.textContent);
        expect(optionTexts).to.include(cobadgeCardBrands.VISA);
        expect(optionTexts).to.include(cobadgeCardBrands.CARTES_BANCAIRES);
      });

    // Verify the placeholder "Select a card brand" disabled option exists
    getIframeBody()
      .find(".hellow-rodl select option:disabled")
      .should("contain.text", "Select a card brand");

    cy.wait(1000);

    // Reset the select back to normal dropdown style
    getIframeBody()
      .find(".hellow-rodl select")
      .then(($select) => {
        $select.removeAttr("size");
        $select.css({ width: "", position: "", "z-index": "" });
      });
  });

  it("should allow selecting Visa from cobadge dropdown", () => {
    // Enter the cobadge card number
    getIframeBody()
      .find(`[data-testid=${testIds.cardNoInputTestId}]`)
      .safeType(cardNo);

    cy.wait(1500);

    // Expand the select visually by setting size attribute, then select Visa
    getIframeBody()
      .find(".hellow-rodl select", { timeout: 10000 })
      .then(($select) => {
        $select.attr("size", $select.find("option").length);
        $select.css({ width: "auto", position: "absolute", "z-index": "9999" });
      });

    cy.wait(1000);

    // Click the Visa option directly within the expanded listbox
    getIframeBody()
      .find(".hellow-rodl select")
      .select(cobadgeCardBrands.VISA);

    cy.wait(1500);

    // Verify Visa is selected
    getIframeBody()
      .find(".hellow-rodl select")
      .should("have.value", cobadgeCardBrands.VISA);

    // Reset the select back to normal
    getIframeBody()
      .find(".hellow-rodl select")
      .then(($select) => {
        $select.removeAttr("size");
        $select.css({ width: "", position: "", "z-index": "" });
      });

    cy.wait(1000);
  });

  it("should allow switching between Visa and CartesBancaires brands", () => {
    // Enter the cobadge card number
    getIframeBody()
      .find(`[data-testid=${testIds.cardNoInputTestId}]`)
      .safeType(cardNo);

    cy.wait(1500);

    // Expand the select visually, then select Visa first
    getIframeBody()
      .find(".hellow-rodl select", { timeout: 10000 })
      .then(($select) => {
        $select.attr("size", $select.find("option").length);
        $select.css({ width: "auto", position: "absolute", "z-index": "9999" });
      });

    cy.wait(1000);

    getIframeBody()
      .find(".hellow-rodl select")
      .select(cobadgeCardBrands.VISA);

    cy.wait(1500);

    getIframeBody()
      .find(".hellow-rodl select")
      .should("have.value", cobadgeCardBrands.VISA);

    // Now switch to CartesBancaires (select is still expanded)
    getIframeBody()
      .find(".hellow-rodl select")
      .select(cobadgeCardBrands.CARTES_BANCAIRES);

    cy.wait(1500);

    getIframeBody()
      .find(".hellow-rodl select")
      .should("have.value", cobadgeCardBrands.CARTES_BANCAIRES);

    // Reset the select back to normal
    getIframeBody()
      .find(".hellow-rodl select")
      .then(($select) => {
        $select.removeAttr("size");
        $select.css({ width: "", position: "", "z-index": "" });
      });

    cy.wait(1000);
  });

  it("should complete payment with selected cobadge card brand (Visa)", () => {
    // Enter the cobadge card number
    getIframeBody()
      .find(`[data-testid=${testIds.cardNoInputTestId}]`)
      .safeType(cardNo);

    cy.wait(1500);

    // Expand the select visually, then select Visa
    getIframeBody()
      .find(".hellow-rodl select", { timeout: 10000 })
      .then(($select) => {
        $select.attr("size", $select.find("option").length);
        $select.css({ width: "auto", position: "absolute", "z-index": "9999" });
      });

    cy.wait(1000);

    getIframeBody()
      .find(".hellow-rodl select")
      .select(cobadgeCardBrands.VISA);

    cy.wait(1000);

    // Reset the select back to normal before continuing
    getIframeBody()
      .find(".hellow-rodl select")
      .then(($select) => {
        $select.removeAttr("size");
        $select.css({ width: "", position: "", "z-index": "" });
      });

    cy.wait(500);

    // Enter expiry and CVC
    getIframeBody()
      .find(`[data-testid=${testIds.expiryInputTestId}]`)
      .safeType(card_exp_month + card_exp_year);

    getIframeBody()
      .find(`[data-testid=${testIds.cardCVVInputTestId}]`)
      .safeType(cvc);

    cy.wait(1000);

    // Submit payment — #submit is in the main document (demo app)
    cy.get("#submit").click();

    // Verify payment success
    cy.contains("Thanks for your order!", { timeout: 30000 }).should(
      "be.visible"
    );
  });
});
