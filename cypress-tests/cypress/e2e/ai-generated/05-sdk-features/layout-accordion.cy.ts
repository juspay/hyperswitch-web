/**
 * Layout: Accordion Tests
 * Tests for the accordion layout: item rendering, selection,
 * expand/collapse, radio buttons, and payment completion.
 */
import * as testIds from "../../../../../src/Utilities/TestUtils.bs";
import {
  getClientURL,
  createPaymentBody,
  changeObjectKeyValue,
} from "../../../support/utils";
import { stripeCards } from "../../../support/cards";

describe("Layout - Accordion", () => {
  const publishableKey = Cypress.env("HYPERSWITCH_PUBLISHABLE_KEY");
  const secretKey = Cypress.env("HYPERSWITCH_SECRET_KEY");
  let getIframeBody: () => Cypress.Chainable<JQuery<HTMLBodyElement>>;
  const iframeSelector =
    "#orca-payment-element-iframeRef-orca-elements-payment-element-payment-element";

  beforeEach(() => {
    getIframeBody = () => cy.iframe(iframeSelector);
    changeObjectKeyValue(
      createPaymentBody,
      "customer_id",
      "layout_accordion_test_user",
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
            "accordion",
          ),
        );
        cy.waitForSDKReady();
      });
    });
  });

  describe("Accordion Container Rendering", () => {
    it("should render the accordion container instead of tabs", () => {
      getIframeBody()
        .find(".AccordionContainer")
        .should("be.visible");
    });

    it("should NOT render tab header when in accordion mode", () => {
      getIframeBody().find(".TabHeader").should("not.exist");
    });

    it("should render at least one accordion item", () => {
      getIframeBody()
        .find(".AccordionItem")
        .should("have.length.at.least", 1);
    });

    it("should render labels inside each accordion item", () => {
      getIframeBody()
        .find(".AccordionItem")
        .first()
        .find(".AccordionItemLabel")
        .should("exist")
        .invoke("text")
        .should("not.be.empty");
    });
  });

  describe("Accordion Selection", () => {
    it("should have one item expanded/selected by default", () => {
      getIframeBody()
        .find(".AccordionItem--selected")
        .should("have.length", 1);
    });

    it("should expand a different item when clicked", () => {
      getIframeBody().find(".AccordionItem").then(($items) => {
        if ($items.length > 1) {
          // Click the second accordion item
          cy.wrap($items.eq(1)).safeClick();

          // The AccordionItem--selected class is applied to an inner child div,
          // not the outer .AccordionItem div itself
          getIframeBody()
            .find(".AccordionItem")
            .eq(1)
            .find(".AccordionItem--selected")
            .should("exist");
        }
      });
    });

    it("should update label styling on selected accordion item", () => {
      getIframeBody()
        .find(".AccordionItemLabel--selected")
        .should("have.length.at.least", 1);
    });

    it("should update icon styling on selected accordion item", () => {
      getIframeBody()
        .find(".AccordionItemIcon--selected")
        .should("have.length.at.least", 1);
    });
  });

  describe("Accordion Styling", () => {
    it("should apply connected borders (no gap between items)", () => {
      getIframeBody()
        .find(".AccordionItem")
        .first()
        .then(($el) => {
          // Regular accordion: first item should not have margin bottom
          const marginBottom = parseFloat($el.css("margin-bottom"));
          expect(marginBottom).to.equal(0);
        });
    });

    it("should apply border to accordion items", () => {
      getIframeBody()
        .find(".AccordionItem")
        .first()
        .then(($el) => {
          // jQuery shorthand .css("border") can return empty; check longhand
          const borderStyle = $el.css("border-top-style");
          expect(borderStyle).to.equal("solid");
        });
    });

    it("should apply padding to accordion items", () => {
      getIframeBody()
        .find(".AccordionItem")
        .first()
        .should("have.css", "padding", "20px");
    });
  });

  describe("Accordion Expand/Collapse Content", () => {
    it("should show card input fields when card accordion item is selected", () => {
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
  });

  describe("Payment Flow with Accordion Layout", () => {
    it("should complete a payment successfully using accordion layout", () => {
      const { cardNo, card_exp_month, card_exp_year, cvc } =
        stripeCards.successCard;

      cy.enterCardDetails({ cardNo, card_exp_month, card_exp_year, cvc });

      cy.get("#submit").click();

      cy.contains("Thanks for your order!", { timeout: 10000 }).should(
        "be.visible",
      );
    });
  });

  describe("Accordion More Button", () => {
    it("should render AccordionMore button if items exceed maxAccordionItems", () => {
      // Default maxAccordionItems is 4. If there are more methods,
      // an AccordionMore button should appear.
      getIframeBody().then(($body) => {
        const hasMore = $body.find(".AccordionMore").length > 0;
        if (hasMore) {
          getIframeBody()
            .find(".AccordionMore")
            .should("be.visible")
            .and("contain.text", "More");
        }
      });
    });
  });
});
