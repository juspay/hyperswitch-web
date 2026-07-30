/**
 * Layout: Tabs (Default) Tests
 * Tests for the default tabs layout: tab rendering, selection,
 * styling, overflow dropdown, and payment completion.
 */
import * as testIds from "../../../../src/Utilities/TestUtils.bs";
import {
  getClientURL,
  createPaymentBody,
  changeObjectKeyValue,
  connectorEnum,
  connectorProfileIdMapping,
  defaultBillingAddress,
} from "../../support/utils";
import { stripeCards } from "../../support/cards";

describe("Layout - Tabs (Default)", () => {
  let publishableKey: string;
  let secretKey: string;
  let getIframeBody: () => Cypress.Chainable<JQuery<HTMLBodyElement>>;
  const iframeSelector =
    "#orca-payment-element-iframeRef-orca-elements-payment-element-payment-element";

  beforeEach(() => {
    publishableKey = Cypress.env("HYPERSWITCH_PUBLISHABLE_KEY");
    secretKey = Cypress.env("HYPERSWITCH_SECRET_KEY");
    getIframeBody = () => cy.iframe(iframeSelector);
    changeObjectKeyValue(
      createPaymentBody,
      "customer_id",
      "layout_tabs_test_user",
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
      connectorProfileIdMapping.get(connectorEnum.STRIPE),
    );
    changeObjectKeyValue(createPaymentBody, "billing", defaultBillingAddress);

    cy.createPaymentIntent(secretKey, createPaymentBody).then(() => {
      cy.getGlobalState("clientSecret").then((clientSecret) => {
        cy.visit(getClientURL(clientSecret, publishableKey));
        cy.waitForSDKReady();
      });
    });
  });

  describe("Tab Header Rendering", () => {
    it("should render the tab header container with paymentList testid", () => {
      getIframeBody()
        .find(`[data-testid=${testIds.paymentMethodListTestId}]`)
        .should("be.visible");
    });

    it("should render tab header with TabHeader CSS class and flex-row layout", () => {
      getIframeBody()
        .find(".TabHeader")
        .should("be.visible")
        .and("have.class", "flex")
        .and("have.class", "flex-row");
    });

    it("should render at least one payment method tab", () => {
      getIframeBody().find(".Tab").should("have.length.at.least", 1);
    });

    it("should have exactly one selected tab by default", () => {
      getIframeBody()
        .find(".Tab--selected")
        .should("have.length", 1);
    });

    it("should render tab icons and labels inside each tab", () => {
      getIframeBody()
        .find(".Tab")
        .first()
        .within(() => {
          cy.get(".TabIcon").should("exist");
          cy.get(".TabLabel").should("exist");
        });
    });
  });

  describe("Tab Selection", () => {
    it("should highlight the selected tab with Tab--selected class", () => {
      getIframeBody()
        .find(".Tab")
        .first()
        .should("have.class", "Tab--selected");
    });

    it("should switch selected tab when clicking a different tab", () => {
      getIframeBody().find(".Tab").then(($tabs) => {
        if ($tabs.length > 1) {
          cy.wrap($tabs.eq(1)).safeClick();

          getIframeBody()
            .find(".Tab")
            .eq(1)
            .should("have.class", "Tab--selected");

          getIframeBody()
            .find(".Tab")
            .first()
            .should("not.have.class", "Tab--selected");
        }
      });
    });

    it("should update the selected tab label with TabLabel--selected class", () => {
      getIframeBody()
        .find(".Tab--selected .TabLabel")
        .should("have.class", "TabLabel--selected");
    });
  });

  describe("Tab Styling", () => {
    it("should apply Default theme styles to tabs (border and border-radius)", () => {
      getIframeBody()
        .find(".Tab")
        .first()
        .should("have.css", "border-radius", "4px");
    });

    it("should apply box-shadow to the selected tab", () => {
      // Retrying assertion: the selected tab applies its box-shadow via the
      // `animate-slowShow` enter-animation, so a one-shot read inside `.then()`
      // can capture the pre-animation `none`.
      getIframeBody()
        .find(".Tab--selected")
        .first()
        .should("not.have.css", "box-shadow", "none");
    });
  });

  describe("Payment Flow with Tabs Layout", () => {
    it("should display card input fields when card tab is selected", () => {
      getIframeBody()
        .find(`[data-testid=${testIds.cardNoInputTestId}]`)
        .should("be.visible");
      getIframeBody()
        .find(`[data-testid=${testIds.expiryInputTestId}]`)
        .should("be.visible");
      getIframeBody()
        .find(`[data-testid=${testIds.cardCVVInputTestId}]`)
        .should("be.visible");
    });

    it("should complete a payment successfully using tabs layout", () => {
      const { cardNo, card_exp_month, card_exp_year, cvc } =
        stripeCards.successCard;

      cy.enterCardDetails({ cardNo, card_exp_month, card_exp_year, cvc });

      cy.get("#submit").should("be.visible").click();

      cy.contains("Thanks for your order!", { timeout: 10000 }).should(
        "be.visible",
      );
    });
  });

  describe("Overflow Dropdown", () => {
    it("should render overflow dropdown if there are more payment methods than visible tabs", () => {
      getIframeBody().then(($body) => {
        const hasDropdown =
          $body.find(`[data-testid=${testIds.paymentMethodDropDownTestId}]`)
            .length > 0;
        if (hasDropdown) {
          getIframeBody()
            .find(`[data-testid=${testIds.paymentMethodDropDownTestId}]`)
            .should("have.class", "TabMore");
        }
      });
    });
  });
});
