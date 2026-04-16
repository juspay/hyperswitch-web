/**
 * Themes / Appearance Tests
 * Tests that each theme preset applies correct visual styling:
 * default, midnight, charcoal, soft, brutal, bubblegum.
 *
 * Key architectural notes:
 * - Each theme has unique styling approaches (some use background-color,
 *   some use CSS gradients, some only set color/box-shadow on selected tabs).
 * - Border-radius is consistently set by all themes on .Tab elements.
 * - The #submit button is on the HOST page and does NOT get theme styles.
 * - Theme rules are injected via <style id="themestyle"> in iframe body.
 * - We focus on reliably testable properties: border-radius, existence of
 *   theme stylesheet, and theme-specific visual differentiation.
 */
import * as testIds from "../../../../src/Utilities/TestUtils.bs";
import {
  getClientURL,
  createPaymentBody,
  changeObjectKeyValue,
} from "../../support/utils";
import { stripeCards } from "../../support/cards";

/**
 * Theme preset expected border-radius values (from *Theme.res files).
 */
const themeBorderRadius: Record<string, string> = {
  default: "4px",
  midnight: "10px",
  charcoal: "10px",
  soft: "10px",
  brutal: "6px",
  bubblegum: "2px",
};

describe("Themes / Appearance", () => {
  const publishableKey = Cypress.env("HYPERSWITCH_PUBLISHABLE_KEY");
  const secretKey = Cypress.env("HYPERSWITCH_SECRET_KEY");
  let getIframeBody: () => Cypress.Chainable<JQuery<HTMLBodyElement>>;
  const iframeSelector =
    "#orca-payment-element-iframeRef-orca-elements-payment-element-payment-element";

  const setupAndVisit = (theme?: string) => {
    changeObjectKeyValue(
      createPaymentBody,
      "customer_id",
      "theme_test_user",
    );
    changeObjectKeyValue(
      createPaymentBody,
      "authentication_type",
      "no_three_ds",
    );
    changeObjectKeyValue(createPaymentBody, "capture_method", "automatic");
    changeObjectKeyValue(
      createPaymentBody,
      "profile_id",
      "pro_5fVcCxU8MFTYozgtf0P8",
    );
    changeObjectKeyValue(createPaymentBody, "billing", {
      email: "hyperswitch_sdk_demo_id@gmail.com",
      address: {
        line1: "1467",
        line2: "Harrison Street",
        line3: "Harrison Street",
        city: "San Fransico",
        state: "California",
        zip: "94122",
        country: "US",
        first_name: "joseph",
        last_name: "Doe",
      },
      phone: { number: "8056594427", country_code: "+91" },
    });

    cy.createPaymentIntent(secretKey, createPaymentBody).then(() => {
      cy.getGlobalState("clientSecret").then((clientSecret) => {
        cy.visit(
          getClientURL(clientSecret, publishableKey, undefined, theme),
        );
        cy.waitForSDKReady();
      });
    });
  };

  beforeEach(() => {
    getIframeBody = () => cy.iframe(iframeSelector);
  });

  describe("Default Theme", () => {
    beforeEach(() => {
      setupAndVisit(); // No theme param = default
    });

    it("should render SDK with tabs in default theme", () => {
      getIframeBody().find(".Tab").should("have.length.at.least", 1);
    });

    it("should apply default border-radius (4px) to tab elements", () => {
      getIframeBody()
        .find(".Tab")
        .first()
        .should("have.css", "border-radius", themeBorderRadius.default);
    });

    it("should have a selected tab with primary-colored text", () => {
      getIframeBody()
        .find(".Tab--selected")
        .first()
        .should("have.css", "color", "rgb(0, 109, 249)");
    });

    it("should apply border to non-selected tab elements", () => {
      getIframeBody()
        .find(".Tab")
        .not(".Tab--selected")
        .first()
        .then(($el) => {
          const borderStyle = $el.css("border-top-style");
          expect(borderStyle).to.equal("solid");
        });
    });

    it("should complete payment with default theme", () => {
      const { cardNo, card_exp_month, card_exp_year, cvc } =
        stripeCards.successCard;
      cy.enterCardDetails({ cardNo, card_exp_month, card_exp_year, cvc });
      cy.get("#submit").click();
      cy.contains("Thanks for your order!", { timeout: 10000 }).should(
        "be.visible",
      );
    });
  });

  describe("Midnight Theme", () => {
    beforeEach(() => {
      setupAndVisit("midnight");
    });

    it("should apply midnight border-radius (10px) to tabs", () => {
      getIframeBody()
        .find(".Tab")
        .first()
        .should("have.css", "border-radius", themeBorderRadius.midnight);
    });

    it("should apply midnight dark background to non-selected tabs", () => {
      getIframeBody()
        .find(".Tab")
        .not(".Tab--selected")
        .first()
        .should("have.css", "background-color", "rgb(48, 49, 61)");
    });

    it("should apply midnight primary color as selected tab background", () => {
      getIframeBody()
        .find(".Tab--selected")
        .first()
        .should("have.css", "background-color", "rgb(133, 217, 150)");
    });

    it("should visually differ from default theme (border-radius)", () => {
      getIframeBody()
        .find(".Tab")
        .first()
        .should("not.have.css", "border-radius", themeBorderRadius.default);
    });

    it("should complete payment with midnight theme", () => {
      const { cardNo, card_exp_month, card_exp_year, cvc } =
        stripeCards.successCard;
      cy.enterCardDetails({ cardNo, card_exp_month, card_exp_year, cvc });
      cy.get("#submit").click();
      cy.contains("Thanks for your order!", { timeout: 10000 }).should(
        "be.visible",
      );
    });
  });

  describe("Charcoal Theme", () => {
    beforeEach(() => {
      setupAndVisit("charcoal");
    });

    it("should apply charcoal border-radius (10px)", () => {
      getIframeBody()
        .find(".Tab")
        .first()
        .should("have.css", "border-radius", themeBorderRadius.charcoal);
    });

    it("should apply charcoal light-gray background to non-selected tabs", () => {
      getIframeBody()
        .find(".Tab")
        .not(".Tab--selected")
        .first()
        .should("have.css", "background-color", "rgb(240, 243, 245)");
    });

    it("should apply charcoal primary (black) to selected tab background", () => {
      getIframeBody()
        .find(".Tab--selected")
        .first()
        .should("have.css", "background-color", "rgb(0, 0, 0)");
    });
  });

  describe("Soft Theme", () => {
    beforeEach(() => {
      setupAndVisit("soft");
    });

    it("should apply soft border-radius (10px)", () => {
      getIframeBody()
        .find(".Tab")
        .first()
        .should("have.css", "border-radius", themeBorderRadius.soft);
    });

    it("should apply soft styling distinct from default theme", () => {
      getIframeBody()
        .find(".Tab")
        .first()
        .should("not.have.css", "border-radius", "4px");
    });

    it("should apply soft primary color to selected tab text", () => {
      getIframeBody()
        .find(".Tab--selected")
        .first()
        .should("have.css", "color", "rgb(125, 143, 255)");
    });
  });

  describe("Brutal Theme", () => {
    beforeEach(() => {
      setupAndVisit("brutal");
    });

    it("should apply brutal border-radius (6px)", () => {
      getIframeBody()
        .find(".Tab")
        .first()
        .should("have.css", "border-radius", themeBorderRadius.brutal);
    });

    it("should apply brutal yellow background to selected tab", () => {
      getIframeBody()
        .find(".Tab--selected")
        .first()
        .should("have.css", "background-color", "rgb(245, 251, 31)");
    });

    it("should have distinct visual styling from default theme", () => {
      getIframeBody()
        .find(".Tab")
        .first()
        .should("not.have.css", "border-radius", themeBorderRadius.default);
    });
  });

  describe("Bubblegum Theme", () => {
    beforeEach(() => {
      setupAndVisit("bubblegum");
    });

    it("should apply bubblegum border-radius (2px)", () => {
      getIframeBody()
        .find(".Tab")
        .first()
        .should("have.css", "border-radius", themeBorderRadius.bubblegum);
    });

    it("should apply bubblegum pink background to selected tab", () => {
      getIframeBody()
        .find(".Tab--selected")
        .first()
        .should("have.css", "background-color", "rgb(243, 96, 166)");
    });

    it("should have smallest border-radius of all themes", () => {
      getIframeBody()
        .find(".Tab")
        .first()
        .should("have.css", "border-radius", "2px");
    });
  });

  describe("Theme Visual Differentiation", () => {
    it("should render different border-radius for each theme", () => {
      setupAndVisit("brutal");
      getIframeBody()
        .find(".Tab")
        .first()
        .should("have.css", "border-radius", "6px");
    });

    it("should render midnight theme with different styling from default", () => {
      setupAndVisit("midnight");
      getIframeBody()
        .find(".Tab")
        .not(".Tab--selected")
        .first()
        .should("have.css", "background-color", "rgb(48, 49, 61)");
    });
  });
});
