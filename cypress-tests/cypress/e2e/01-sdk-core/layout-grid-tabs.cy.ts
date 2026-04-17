/**
 * Layout: Grid Tabs Tests
 * Tests for tabs layout with paymentMethodsArrangementForTabs: "grid".
 * Tabs should be arranged in a CSS grid instead of a horizontal flex row.
 */
import * as testIds from "../../../../src/Utilities/TestUtils.bs";
import {
  getClientURL,
  createPaymentBody,
  changeObjectKeyValue,
} from "../../support/utils";
import { stripeCards } from "../../support/cards";

describe("Layout - Grid Tabs", () => {
  const publishableKey = Cypress.env("HYPERSWITCH_PUBLISHABLE_KEY");
  const secretKey = Cypress.env("HYPERSWITCH_SECRET_KEY");
  let getIframeBody: () => Cypress.Chainable<JQuery<HTMLBodyElement>>;
  const iframeSelector =
    "#orca-payment-element-iframeRef-orca-elements-payment-element-payment-element";

  const gridTabsLayout = {
    type: "tabs",
    paymentMethodsArrangementForTabs: "grid",
  };

  beforeEach(() => {
    getIframeBody = () => cy.iframe(iframeSelector);
    changeObjectKeyValue(
      createPaymentBody,
      "customer_id",
      "layout_grid_tabs_test_user",
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
            gridTabsLayout,
          ),
        );
        cy.waitForSDKReady();
      });
    });
  });

  describe("Grid Tabs Container", () => {
    it("should render tabs layout (not accordion)", () => {
      getIframeBody()
        .find(".TabHeader")
        .should("be.visible");

      getIframeBody().find(".AccordionContainer").should("not.exist");
    });

    it("should use CSS grid display on the tab header", () => {
      getIframeBody()
        .find(".TabHeader")
        .should("have.css", "display", "grid");
    });

    it("should have grid-template-columns set for grid arrangement", () => {
      getIframeBody()
        .find(".TabHeader")
        .then(($el) => {
          const gridCols = $el.css("grid-template-columns");
          expect(gridCols).to.not.be.empty;
          expect(gridCols).to.not.equal("none");
        });
    });

    it("should have gap between grid items", () => {
      getIframeBody()
        .find(".TabHeader")
        .then(($el) => {
          const gap = $el.css("gap");
          expect(gap).to.not.equal("normal");
        });
    });
  });

  describe("Grid Tabs Items", () => {
    it("should render tab buttons with Tab CSS class", () => {
      getIframeBody().find(".Tab").should("have.length.at.least", 1);
    });

    it("should display all payment methods without overflow dropdown", () => {
      getIframeBody()
        .find(`[data-testid=${testIds.paymentMethodDropDownTestId}]`)
        .should("not.exist");
    });

    it("should have one selected tab by default", () => {
      getIframeBody()
        .find(".Tab--selected")
        .should("have.length", 1);
    });

    it("should switch selection when clicking a different grid tab", () => {
      getIframeBody().find(".Tab").then(($tabs) => {
        if ($tabs.length > 1) {
          cy.wrap($tabs.eq(1)).safeClick();

          getIframeBody()
            .find(".Tab")
            .eq(1)
            .should("have.class", "Tab--selected");
        }
      });
    });
  });

  describe("Payment Flow with Grid Tabs", () => {
    it("should show card input fields when card tab is selected", () => {
      getIframeBody()
        .find(`[data-testid=${testIds.cardNoInputTestId}]`)
        .should("be.visible");
    });

    it("should complete payment successfully with grid tabs layout", () => {
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
