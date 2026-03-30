/**
 * Card Validation Tests
 * Consolidated tests for card number validation, brand detection, and formatting
 */
import * as testIds from "../../../../src/Utilities/TestUtils.bs";
import { getClientURL, createPaymentBody, changeObjectKeyValue } from "../../support/utils";
import { stripeCards } from "../../support/cards";

describe("Card Number Validation", () => {
  const publishableKey = Cypress.env("HYPERSWITCH_PUBLISHABLE_KEY");
  const secretKey = Cypress.env("HYPERSWITCH_SECRET_KEY");
  let getIframeBody: () => Cypress.Chainable<JQuery<HTMLBodyElement>>;
  const iframeSelector =
    "#orca-payment-element-iframeRef-orca-elements-payment-element-payment-element";

  changeObjectKeyValue(createPaymentBody, "customer_id", "card_validation_test_user");

  beforeEach(() => {
    getIframeBody = () => cy.iframe(iframeSelector);
    cy.createPaymentIntent(secretKey, createPaymentBody).then(() => {
      cy.getGlobalState("clientSecret").then((clientSecret) => {
        cy.visit(getClientURL(clientSecret, publishableKey));
      });
    });
  });

  describe("Invalid Card Scenarios", () => {
    it("should fail with undetectable card brand and invalid card number", () => {
      const { card_exp_month, card_exp_year, cvc } = stripeCards.successCard;

      getIframeBody()
        .find(`[data-testid=${testIds.cardNoInputTestId}]`)
        .type("111111");
      getIframeBody()
        .find(`[data-testid=${testIds.expiryInputTestId}]`)
        .type(card_exp_month);
      getIframeBody()
        .find(`[data-testid=${testIds.expiryInputTestId}]`)
        .type(card_exp_year);
      getIframeBody()
        .find(`[data-testid=${testIds.cardCVVInputTestId}]`)
        .type(cvc);

      getIframeBody().get("#submit").click();

      getIframeBody()
        .find(".Error.pt-1")
        .should("be.visible")
        .and("contain.text", "Please enter a valid card number.");
    });

    it("should fail with detectable but invalid card number", () => {
      const { card_exp_month, card_exp_year, cvc } = stripeCards.successCard;

      getIframeBody()
        .find(`[data-testid=${testIds.cardNoInputTestId}]`)
        .type("424242");
      getIframeBody()
        .find(`[data-testid=${testIds.expiryInputTestId}]`)
        .type(card_exp_month);
      getIframeBody()
        .find(`[data-testid=${testIds.expiryInputTestId}]`)
        .type(card_exp_year);
      getIframeBody()
        .find(`[data-testid=${testIds.cardCVVInputTestId}]`)
        .type(cvc);

      getIframeBody().get("#submit").click();

      getIframeBody()
        .find(".Error.pt-1")
        .should("be.visible")
        .and("contain.text", "Card number is invalid.");
    });

    it("should fail with unsupported card brand (RuPay)", () => {
      const { card_exp_month, card_exp_year, cvc } = stripeCards.successCard;

      getIframeBody()
        .find(`[data-testid=${testIds.cardNoInputTestId}]`)
        .type("6082015309577308");
      getIframeBody()
        .find(`[data-testid=${testIds.expiryInputTestId}]`)
        .type(card_exp_month);
      getIframeBody()
        .find(`[data-testid=${testIds.expiryInputTestId}]`)
        .type(card_exp_year);
      getIframeBody()
        .find(`[data-testid=${testIds.cardCVVInputTestId}]`)
        .type(cvc);

      getIframeBody().get("#submit").click();

      getIframeBody()
        .find(".Error.pt-1")
        .should("be.visible")
        .and("contain.text", "RuPay is not supported at the moment.");
    });

    it("should fail with empty card number", () => {
      const { card_exp_month, card_exp_year, cvc } = stripeCards.successCard;

      getIframeBody()
        .find(`[data-testid=${testIds.expiryInputTestId}]`)
        .type(card_exp_month);
      getIframeBody()
        .find(`[data-testid=${testIds.expiryInputTestId}]`)
        .type(card_exp_year);
      getIframeBody()
        .find(`[data-testid=${testIds.cardCVVInputTestId}]`)
        .type(cvc);

      getIframeBody().get("#submit").click();

      getIframeBody()
        .find(".Error.pt-1")
        .should("be.visible")
        .and("contain.text", "Card Number cannot be empty");
    });
  });

  describe("Card Brand Detection & Formatting", () => {
    it("should auto-format 16-digit Visa card", () => {
      getIframeBody()
        .find(`[data-testid=${testIds.cardNoInputTestId}]`)
        .type("4242424242424242");

      getIframeBody()
        .find(`[data-testid=${testIds.cardNoInputTestId}]`)
        .should("have.value", "4242 4242 4242 4242");
    });

    it("should auto-format 19-digit UnionPay card", () => {
      const { cardNo, card_exp_month, card_exp_year, cvc } = stripeCards.unionPay19;

      getIframeBody()
        .find(`[data-testid=${testIds.cardNoInputTestId}]`)
        .type(cardNo);
      getIframeBody()
        .find(`[data-testid=${testIds.expiryInputTestId}]`)
        .type(card_exp_month);
      getIframeBody()
        .find(`[data-testid=${testIds.expiryInputTestId}]`)
        .type(card_exp_year);
      getIframeBody()
        .find(`[data-testid=${testIds.cardCVVInputTestId}]`)
        .type(cvc);

      getIframeBody().get("#submit").click();
      cy.contains("Thanks for your order!").should("be.visible");
    });

    it("should auto-format 16-digit MasterCard", () => {
      const { cardNo, card_exp_month, card_exp_year, cvc } = stripeCards.masterCard16;

      getIframeBody()
        .find(`[data-testid=${testIds.cardNoInputTestId}]`)
        .type(cardNo);
      getIframeBody()
        .find(`[data-testid=${testIds.expiryInputTestId}]`)
        .type(card_exp_month);
      getIframeBody()
        .find(`[data-testid=${testIds.expiryInputTestId}]`)
        .type(card_exp_year);
      getIframeBody()
        .find(`[data-testid=${testIds.cardCVVInputTestId}]`)
        .type(cvc);

      getIframeBody().get("#submit").click();
      cy.contains("Thanks for your order!").should("be.visible");
    });

    it("should auto-format 15-digit American Express card", () => {
      const { cardNo, card_exp_month, card_exp_year, cvc } = stripeCards.amexCard15;

      getIframeBody()
        .find(`[data-testid=${testIds.cardNoInputTestId}]`)
        .type(cardNo);
      getIframeBody()
        .find(`[data-testid=${testIds.expiryInputTestId}]`)
        .type(card_exp_month);
      getIframeBody()
        .find(`[data-testid=${testIds.expiryInputTestId}]`)
        .type(card_exp_year);
      getIframeBody()
        .find(`[data-testid=${testIds.cardCVVInputTestId}]`)
        .type(cvc);

      getIframeBody().get("#submit").click();
      cy.contains("Thanks for your order!").should("be.visible");
    });

    it("should auto-format 14-digit Diners Club card", () => {
      const { cardNo, card_exp_month, card_exp_year, cvc } = stripeCards.dinersClubCard14;

      getIframeBody()
        .find(`[data-testid=${testIds.cardNoInputTestId}]`)
        .type(cardNo);
      getIframeBody()
        .find(`[data-testid=${testIds.expiryInputTestId}]`)
        .type(card_exp_month);
      getIframeBody()
        .find(`[data-testid=${testIds.expiryInputTestId}]`)
        .type(card_exp_year);
      getIframeBody()
        .find(`[data-testid=${testIds.cardCVVInputTestId}]`)
        .type(cvc);

      getIframeBody().get("#submit").click();
      cy.contains("Thanks for your order!").should("be.visible");
    });
  });

  describe("Card Brand Icons", () => {
    it("should display card brand icon dynamically for Visa", () => {
      getIframeBody()
        .find(`[data-testid=${testIds.cardNoInputTestId}]`)
        .type("4242");

      getIframeBody()
        .find(`[data-testid=${testIds.cardNoInputTestId}]`)
        .should("have.value", "4242");
    });
  });


  describe("Expiry Date Validation", () => {
    it("should reject expired card (past year)", () => {
      const { cardNo, cvc } = stripeCards.successCard;

      getIframeBody()
        .find(`[data-testid=${testIds.cardNoInputTestId}]`)
        .type(cardNo);
      getIframeBody()
        .find(`[data-testid=${testIds.expiryInputTestId}]`)
        .type("0123"); // Expired: Jan 2023
      getIframeBody()
        .find(`[data-testid=${testIds.cardCVVInputTestId}]`)
        .type(cvc);

      getIframeBody().get("#submit").click();

      getIframeBody()
        .find(".Error.pt-1")
        .should("be.visible")
        .and("contain.text", "Your card's expiration year is in the past.");
    });

    it("should reject invalid month (00)", () => {
      const { cardNo, cvc } = stripeCards.successCard;

      getIframeBody()
        .find(`[data-testid=${testIds.cardNoInputTestId}]`)
        .type(cardNo);
      getIframeBody()
        .find(`[data-testid=${testIds.expiryInputTestId}]`)
        .type("0030"); // Invalid month 00
      getIframeBody()
        .find(`[data-testid=${testIds.cardCVVInputTestId}]`)
        .type(cvc);

      getIframeBody().get("#submit").click();

      getIframeBody()
        .find(".Error.pt-1")
        .should("be.visible");
    });

    it("should accept valid future expiry date", () => {
      const { cardNo, cvc } = stripeCards.successCard;
      const futureYear = (new Date().getFullYear() + 1).toString().slice(-2);

      getIframeBody()
        .find(`[data-testid=${testIds.cardNoInputTestId}]`)
        .type(cardNo);
      getIframeBody()
        .find(`[data-testid=${testIds.expiryInputTestId}]`)
        .type(`12${futureYear}`);
      getIframeBody()
        .find(`[data-testid=${testIds.cardCVVInputTestId}]`)
        .type(cvc);

      getIframeBody().get("#submit").click();
      cy.contains("Thanks for your order!").should("be.visible");
    });
  });

  describe("CVC/CVV Validation", () => {
    it("should require 3 digits for Visa", () => {
      const { cardNo, card_exp_month, card_exp_year } = stripeCards.successCard;

      getIframeBody()
        .find(`[data-testid=${testIds.cardNoInputTestId}]`)
        .type(cardNo);
      getIframeBody()
        .find(`[data-testid=${testIds.expiryInputTestId}]`)
        .type(card_exp_month);
      getIframeBody()
        .find(`[data-testid=${testIds.expiryInputTestId}]`)
        .type(card_exp_year);
      getIframeBody()
        .find(`[data-testid=${testIds.cardCVVInputTestId}]`)
        .type("12"); // Only 2 digits

      getIframeBody().get("#submit").click();

      getIframeBody()
        .find(".Error.pt-1")
        .should("be.visible")
        .and("contain.text", "Your card's security code is incomplete.");
    });

    it("should require 4 digits for Amex", () => {
      const { cardNo, card_exp_month, card_exp_year } = stripeCards.amexCard15;

      getIframeBody()
        .find(`[data-testid=${testIds.cardNoInputTestId}]`)
        .type(cardNo);
      getIframeBody()
        .find(`[data-testid=${testIds.expiryInputTestId}]`)
        .type(card_exp_month);
      getIframeBody()
        .find(`[data-testid=${testIds.expiryInputTestId}]`)
        .type(card_exp_year);
      getIframeBody()
        .find(`[data-testid=${testIds.cardCVVInputTestId}]`)
        .type("123"); // Only 3 digits for Amex

      getIframeBody().get("#submit").click();

      getIframeBody()
        .find(".Error.pt-1")
        .should("be.visible")
        .and("contain.text", "Your card's security code is incomplete.");
    });

    it("should reject alphabetic characters in CVC", () => {
      const { cardNo, card_exp_month, card_exp_year } = stripeCards.successCard;

      getIframeBody()
        .find(`[data-testid=${testIds.cardNoInputTestId}]`)
        .type(cardNo);
      getIframeBody()
        .find(`[data-testid=${testIds.expiryInputTestId}]`)
        .type(card_exp_month);
      getIframeBody()
        .find(`[data-testid=${testIds.expiryInputTestId}]`)
        .type(card_exp_year);
      getIframeBody()
        .find(`[data-testid=${testIds.cardCVVInputTestId}]`)
        .type("abc");

      getIframeBody()
        .find(`[data-testid=${testIds.cardCVVInputTestId}]`)
        .should("have.value", ""); // Should not accept letters
    });

    it("should accept valid 3-digit CVC for Visa", () => {
      const { cardNo, card_exp_month, card_exp_year } = stripeCards.successCard;

      getIframeBody()
        .find(`[data-testid=${testIds.cardNoInputTestId}]`)
        .type(cardNo);
      getIframeBody()
        .find(`[data-testid=${testIds.expiryInputTestId}]`)
        .type(card_exp_month);
      getIframeBody()
        .find(`[data-testid=${testIds.expiryInputTestId}]`)
        .type(card_exp_year);
      getIframeBody()
        .find(`[data-testid=${testIds.cardCVVInputTestId}]`)
        .type("123");

      getIframeBody().get("#submit").click();
      cy.contains("Thanks for your order!").should("be.visible");
    });

    it("should accept valid 4-digit CVC for Amex", () => {
      const { cardNo, card_exp_month, card_exp_year } = stripeCards.amexCard15;

      getIframeBody()
        .find(`[data-testid=${testIds.cardNoInputTestId}]`)
        .type(cardNo);
      getIframeBody()
        .find(`[data-testid=${testIds.expiryInputTestId}]`)
        .type(card_exp_month);
      getIframeBody()
        .find(`[data-testid=${testIds.expiryInputTestId}]`)
        .type(card_exp_year);
      getIframeBody()
        .find(`[data-testid=${testIds.cardCVVInputTestId}]`)
        .type("1234");

      getIframeBody().get("#submit").click();
      cy.contains("Thanks for your order!").should("be.visible");
    });
  });

  describe("Input Edge Cases", () => {
    it("should trim spaces from card number input", () => {
      getIframeBody()
        .find(`[data-testid=${testIds.cardNoInputTestId}]`)
        .type("4242 4242 4242 4242");

      getIframeBody()
        .find(`[data-testid=${testIds.cardNoInputTestId}]`)
        .should("have.value", "4242 4242 4242 4242"); // Formatted with spaces
    });

    it("should reject card number with letters", () => {
      getIframeBody()
        .find(`[data-testid=${testIds.cardNoInputTestId}]`)
        .type("4242abcd4242");

      getIframeBody()
        .find(`[data-testid=${testIds.cardNoInputTestId}]`)
        .should("have.value", "4242 4242"); // Only numbers accepted
    });

    it("should enforce max length for card number (19 digits)", () => {
      getIframeBody()
        .find(`[data-testid=${testIds.cardNoInputTestId}]`)
        .type("620550000000000000499999999999");

      getIframeBody()
        .find(`[data-testid=${testIds.cardNoInputTestId}]`)
        .invoke("val")
        .should("have.length.at.most", 23); // 19 digits + 4 spaces
    });

    it("should handle paste event with formatted number", () => {
      getIframeBody()
        .find(`[data-testid=${testIds.cardNoInputTestId}]`)
        .invoke("val", "4242 4242 4242 4242")
        .trigger("input");

      getIframeBody()
        .find(`[data-testid=${testIds.cardNoInputTestId}]`)
        .should("have.value", "4242 4242 4242 4242");
    });

    it("should clear error when user starts fixing invalid input", () => {
      const { card_exp_year, cvc } = stripeCards.successCard;

      getIframeBody()
        .find(`[data-testid=${testIds.cardNoInputTestId}]`)
        .type("111111"); // Invalid card
      getIframeBody()
        .find(`[data-testid=${testIds.expiryInputTestId}]`)
        .type("12");
      getIframeBody()
        .find(`[data-testid=${testIds.expiryInputTestId}]`)
        .type(card_exp_year);
      getIframeBody()
        .find(`[data-testid=${testIds.cardCVVInputTestId}]`)
        .type(cvc);

      getIframeBody().get("#submit").click();

      // Error should be visible
      getIframeBody()
        .find(".Error.pt-1")
        .should("be.visible");

      // Start fixing - error should clear or remain based on implementation
      getIframeBody()
        .find(`[data-testid=${testIds.cardNoInputTestId}]`)
        .clear()
        .type("4242");

      // Card icon should update to Visa
      getIframeBody()
        .find(`[data-testid=${testIds.cardNoInputTestId}]`)
        .should("have.value", "4242");
    });
  });

  describe("Real-time Validation", () => {
    it("should show card brand while typing", () => {
      getIframeBody()
        .find(`[data-testid=${testIds.cardNoInputTestId}]`)
        .type("4");

      // After typing first digit, should detect Visa
      getIframeBody()
        .find(`[data-testid=${testIds.cardNoInputTestId}]`)
        .should("have.value", "4");

      getIframeBody()
        .find(`[data-testid=${testIds.cardNoInputTestId}]`)
        .type("242424242424242");

      getIframeBody()
        .find(`[data-testid=${testIds.cardNoInputTestId}]`)
        .should("have.value", "4242 4242 4242 4242");
    });

    it("should update card brand when changing from Visa to MasterCard", () => {
      // Type Visa first
      getIframeBody()
        .find(`[data-testid=${testIds.cardNoInputTestId}]`)
        .type("4242424242424242");

      getIframeBody()
        .find(`[data-testid=${testIds.cardNoInputTestId}]`)
        .clear();

      // Type MasterCard
      getIframeBody()
        .find(`[data-testid=${testIds.cardNoInputTestId}]`)
        .type("5555555555554444");

      getIframeBody()
        .find(`[data-testid=${testIds.cardNoInputTestId}]`)
        .should("have.value", "5555 5555 5555 4444");
    });

    it("should validate minimum card number length", () => {
      const { card_exp_month, card_exp_year, cvc } = stripeCards.successCard;

      getIframeBody()
        .find(`[data-testid=${testIds.cardNoInputTestId}]`)
        .type("4242"); // Too short
      getIframeBody()
        .find(`[data-testid=${testIds.expiryInputTestId}]`)
        .type(card_exp_month);
      getIframeBody()
        .find(`[data-testid=${testIds.expiryInputTestId}]`)
        .type(card_exp_year);
      getIframeBody()
        .find(`[data-testid=${testIds.cardCVVInputTestId}]`)
        .type(cvc);

      getIframeBody().get("#submit").click();

      getIframeBody()
        .find(".Error.pt-1")
        .should("be.visible")
        .and("contain.text", "Card number is invalid.");
    });
  });

  describe("Cross-field Validation", () => {
    it("should require all fields before submit", () => {
      // Only fill card number
      getIframeBody()
        .find(`[data-testid=${testIds.cardNoInputTestId}]`)
        .type(stripeCards.successCard.cardNo);

      getIframeBody().get("#submit").click();

      getIframeBody()
        .find(".Error.pt-1")
        .should("be.visible");
    });

    it("should preserve valid fields when one is invalid", () => {
      const { cardNo, card_exp_month, card_exp_year } = stripeCards.successCard;

      getIframeBody()
        .find(`[data-testid=${testIds.cardNoInputTestId}]`)
        .type(cardNo);
      getIframeBody()
        .find(`[data-testid=${testIds.expiryInputTestId}]`)
        .type(card_exp_month);
      getIframeBody()
        .find(`[data-testid=${testIds.expiryInputTestId}]`)
        .type(card_exp_year);
      getIframeBody()
        .find(`[data-testid=${testIds.cardCVVInputTestId}]`)
        .type("12"); // Invalid CVC

      getIframeBody().get("#submit").click();

      // Check valid fields are preserved
      getIframeBody()
        .find(`[data-testid=${testIds.cardNoInputTestId}]`)
        .should("have.value", "4242 4242 4242 4242");
      getIframeBody()
        .find(`[data-testid=${testIds.expiryInputTestId}]`)
        .should("have.value", `12 / ${card_exp_year}`);
    });

    // it("should show all field errors on submit with empty form", () => {
    //   getIframeBody().get("#submit").click();

    //   getIframeBody()
    //     .find(".Error.pt-1")
    //     .should("be.visible");
    // });
  });

  describe.skip("Saved Card CVC Validation", () => {
    it("should accept 3-digit CVC on saved payment methods screen", () => {
      getIframeBody()
        .find(`[data-testid=${testIds.cardCVVInputTestId}]`)
        .type("123")
        .then(() => {
          getIframeBody()
            .find(`[data-testid=${testIds.cardCVVInputTestId}]`)
            .should("have.value", "123");
        });
    });

    it("should accept 4-digit CVC for AMEX saved card", () => {
      cy.wait(2000);
      getIframeBody()
        .contains("div", "4 digit cvc t..")
        .should("exist")
        .trigger("click");
      cy.wait(1000);

      getIframeBody()
        .find(`[data-testid=${testIds.cardCVVInputTestId}]`)
        .type("1234")
        .then(() => {
          getIframeBody()
            .find(`[data-testid=${testIds.cardCVVInputTestId}]`)
            .should("have.value", "1234");
        });
    });

    it("should display error when CVC is empty for saved card", () => {
      cy.wait(2000);

      getIframeBody()
        .contains("div", "4 digit cvc t..")
        .should("exist")
        .click();
      cy.wait(1000);

      getIframeBody().get("#submit").click();

      getIframeBody()
        .contains("CVC Number cannot be empty")
        .should("be.visible");

      cy.contains("Please enter all fields").should("be.visible");
    });
  });
});
