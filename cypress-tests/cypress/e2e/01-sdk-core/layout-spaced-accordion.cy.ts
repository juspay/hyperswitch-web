/**
 * Layout: Spaced Accordion Tests
 * Tests for accordion layout with spacedAccordionItems: true.
 * Items should have spacing between them, individual border-radius,
 * and visible borders on each item.
 */
import * as testIds from "../../../../src/Utilities/TestUtils.bs";
import {
  getClientURL,
  createPaymentBody,
  changeObjectKeyValue,
} from "../../support/utils";
import { stripeCards } from "../../support/cards";

describe("Layout - Spaced Accordion", () => {
  const publishableKey = Cypress.env("HYPERSWITCH_PUBLISHABLE_KEY");
  const secretKey = Cypress.env("HYPERSWITCH_SECRET_KEY");
  let getIframeBody: () => Cypress.Chainable<JQuery<HTMLBodyElement>>;
  const iframeSelector =
    "#orca-payment-element-iframeRef-orca-elements-payment-element-payment-element";

  const spacedAccordionLayout = {
    type: "accordion",
    spacedAccordionItems: true,
  };

  beforeEach(() => {
    getIframeBody = () => cy.iframe(iframeSelector);
    changeObjectKeyValue(
      createPaymentBody,
      "customer_id",
      "layout_spaced_accordion_test_user",
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
          getClientURL(
            clientSecret,
            publishableKey,
            undefined,
            undefined,
            spacedAccordionLayout,
          ),
        );
        cy.waitForSDKReady();
      });
    });
  });

  describe("Spaced Accordion Container", () => {
    it("should render accordion container (not tabs)", () => {
      getIframeBody()
        .find(".AccordionContainer")
        .should("be.visible");
    });

    it("should NOT render tab header", () => {
      getIframeBody().find(".TabHeader").should("not.exist");
    });

    it("should render multiple accordion items", () => {
      getIframeBody()
        .find(".AccordionItem")
        .should("have.length.at.least", 1);
    });
  });

  describe("Spaced Accordion Spacing", () => {
    it("should have margin-bottom between accordion items (spaced mode)", () => {
      getIframeBody()
        .find(".AccordionItem")
        .first()
        .then(($el) => {
          const marginBottom = parseFloat($el.css("margin-bottom"));
          expect(marginBottom).to.be.greaterThan(0);
        });
    });

    it("should have individual border-radius on each item (not shared edges)", () => {
      getIframeBody()
        .find(".AccordionItem")
        .first()
        .then(($el) => {
          const borderRadius = $el.css("border-radius");
          expect(borderRadius).to.not.equal("0px");
        });
    });

    it("should have visible bottom border on each item", () => {
      getIframeBody()
        .find(".AccordionItem")
        .first()
        .then(($el) => {
          const borderBottomStyle = $el.css("border-bottom-style");
          expect(borderBottomStyle).to.equal("solid");
        });
    });
  });

  describe("Spaced Accordion Selection", () => {
    it("should have one item selected by default", () => {
      getIframeBody()
        .find(".AccordionItem--selected")
        .should("have.length", 1);
    });

    it("should switch selection when clicking a different item", () => {
      getIframeBody().find(".AccordionItem").then(($items) => {
        if ($items.length > 1) {
          cy.wrap($items.eq(1)).safeClick();

          getIframeBody()
            .find(".AccordionItem")
            .eq(1)
            .find(".AccordionItem--selected")
            .should("exist");
        }
      });
    });
  });

  describe("Payment Flow with Spaced Accordion", () => {
    it("should show card fields when card item is selected", () => {
      getIframeBody()
        .find(`[data-testid=${testIds.cardNoInputTestId}]`)
        .should("be.visible");
    });

    it("should complete payment successfully with spaced accordion layout", () => {
      const { cardNo, card_exp_month, card_exp_year, cvc } =
        stripeCards.successCard;

      cy.enterCardDetails({ cardNo, card_exp_month, card_exp_year, cvc });

      cy.get("#submit").click();

      cy.contains("Thanks for your order!", { timeout: 10000 }).should(
        "be.visible",
      );
    });
  });
});
