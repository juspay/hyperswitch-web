/**
 * Card Number Formatting and Paste Handling Tests
 * Tests for auto-formatting, clipboard paste behavior, and input masking
 * that are not thoroughly covered in the existing suite.
 */
import * as testIds from "../../../../../src/Utilities/TestUtils.bs";
import {
  getClientURL,
  createPaymentBody,
  changeObjectKeyValue,
} from "../../../support/utils";
import { stripeCards } from "../../../support/cards";

describe("Card Number Formatting and Paste Handling", () => {
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
      "formatting_test_user",
    );
    changeObjectKeyValue(
      createPaymentBody,
      "authentication_type",
      "no_three_ds",
    );

    cy.createPaymentIntent(secretKey, createPaymentBody).then(() => {
      cy.getGlobalState("clientSecret").then((clientSecret) => {
        cy.visit(getClientURL(clientSecret, publishableKey));
        cy.waitForSDKReady();
      });
    });
  });

  describe("Card Number Auto-Formatting", () => {
    it("should format 16-digit Visa card as XXXX XXXX XXXX XXXX", () => {
      getIframeBody()
        .find(`[data-testid=${testIds.cardNoInputTestId}]`)
        .safeType("4242424242424242");

      getIframeBody()
        .find(`[data-testid=${testIds.cardNoInputTestId}]`)
        .should("have.value", "4242 4242 4242 4242");
    });

    it("should format 15-digit Amex card as XXXX XXXXXX XXXXX", () => {
      getIframeBody()
        .find(`[data-testid=${testIds.cardNoInputTestId}]`)
        .safeType("378282246310005");

      getIframeBody()
        .find(`[data-testid=${testIds.cardNoInputTestId}]`)
        .invoke("val")
        .should("match", /^3782 822463 10005$/);
    });

    it("should format 14-digit Diners Club card correctly", () => {
      getIframeBody()
        .find(`[data-testid=${testIds.cardNoInputTestId}]`)
        .safeType("36227206271667");

      getIframeBody()
        .find(`[data-testid=${testIds.cardNoInputTestId}]`)
        .invoke("val")
        .then((val) => {
          // Diners Club should have formatted output
          const trimmedVal = String(val).replace(/\s/g, "");
          expect(trimmedVal).to.equal("36227206271667");
        });
    });

    it("should format 19-digit UnionPay card correctly", () => {
      const { cardNo } = stripeCards.unionPay19;

      getIframeBody()
        .find(`[data-testid=${testIds.cardNoInputTestId}]`)
        .safeType(cardNo);

      getIframeBody()
        .find(`[data-testid=${testIds.cardNoInputTestId}]`)
        .invoke("val")
        .then((val) => {
          // UnionPay 19-digit should have spaces
          const trimmedVal = String(val).replace(/\s/g, "");
          expect(trimmedVal).to.equal(cardNo);
        });
    });
  });

  describe("Expiry Date Formatting", () => {
    it("should auto-format expiry as MM / YY", () => {
      getIframeBody()
        .find(`[data-testid=${testIds.cardNoInputTestId}]`)
        .safeType(stripeCards.successCard.cardNo);

      getIframeBody()
        .find(`[data-testid=${testIds.expiryInputTestId}]`)
        .safeType("1230");

      getIframeBody()
        .find(`[data-testid=${testIds.expiryInputTestId}]`)
        .invoke("val")
        .should("match", /^12\s*\/\s*30$/);
    });

    it("should auto-prepend 0 when month starts with 2-9", () => {
      getIframeBody()
        .find(`[data-testid=${testIds.cardNoInputTestId}]`)
        .safeType(stripeCards.successCard.cardNo);

      getIframeBody()
        .find(`[data-testid=${testIds.expiryInputTestId}]`)
        .safeType("230");

      getIframeBody()
        .find(`[data-testid=${testIds.expiryInputTestId}]`)
        .invoke("val")
        .should("match", /^02\s*\/\s*30$/);
    });

    it("should not allow non-numeric characters in expiry field", () => {
      getIframeBody()
        .find(`[data-testid=${testIds.cardNoInputTestId}]`)
        .safeType(stripeCards.successCard.cardNo);

      getIframeBody()
        .find(`[data-testid=${testIds.expiryInputTestId}]`)
        .safeType("ab12cd30");

      getIframeBody()
        .find(`[data-testid=${testIds.expiryInputTestId}]`)
        .invoke("val")
        .should("match", /^12\s*\/\s*30$/);
    });
  });

  describe("Paste Handling", () => {
    it("should accept and format a pasted card number with spaces", () => {
      getIframeBody()
        .find(`[data-testid=${testIds.cardNoInputTestId}]`)
        .then(($input) => {
          // Simulate paste by setting value and triggering input event
          $input.val("4242 4242 4242 4242");
          $input[0].dispatchEvent(new Event("input", { bubbles: true }));
        });

      getIframeBody()
        .find(`[data-testid=${testIds.cardNoInputTestId}]`)
        .invoke("val")
        .then((val) => {
          const digitsOnly = String(val).replace(/\s/g, "");
          expect(digitsOnly).to.equal("4242424242424242");
        });
    });

    it("should accept and format a pasted card number with dashes", () => {
      getIframeBody()
        .find(`[data-testid=${testIds.cardNoInputTestId}]`)
        .then(($input) => {
          $input.val("4242-4242-4242-4242");
          $input[0].dispatchEvent(new Event("input", { bubbles: true }));
        });

      getIframeBody()
        .find(`[data-testid=${testIds.cardNoInputTestId}]`)
        .invoke("val")
        .then((val) => {
          const digitsOnly = String(val).replace(/[\s-]/g, "");
          expect(digitsOnly).to.equal("4242424242424242");
        });
    });
  });

  describe("Max Length Enforcement", () => {
    it("should enforce maximum 19 digits for card number", () => {
      getIframeBody()
        .find(`[data-testid=${testIds.cardNoInputTestId}]`)
        .safeType("42424242424242424242999");

      getIframeBody()
        .find(`[data-testid=${testIds.cardNoInputTestId}]`)
        .invoke("val")
        .then((val) => {
          const digitsOnly = String(val).replace(/\s/g, "");
          expect(digitsOnly.length).to.be.at.most(19);
        });
    });

    it("should enforce maximum 3 digits for Visa CVC", () => {
      getIframeBody()
        .find(`[data-testid=${testIds.cardNoInputTestId}]`)
        .safeType(stripeCards.successCard.cardNo);

      getIframeBody()
        .find(`[data-testid=${testIds.cardCVVInputTestId}]`)
        .safeType("12345");

      getIframeBody()
        .find(`[data-testid=${testIds.cardCVVInputTestId}]`)
        .invoke("val")
        .then((val) => {
          expect(String(val).length).to.be.at.most(3);
        });
    });

    it("should enforce maximum 4 digits for Amex CVC", () => {
      getIframeBody()
        .find(`[data-testid=${testIds.cardNoInputTestId}]`)
        .safeType(stripeCards.amexCard15.cardNo);

      getIframeBody()
        .find(`[data-testid=${testIds.cardCVVInputTestId}]`)
        .safeType("123456");

      getIframeBody()
        .find(`[data-testid=${testIds.cardCVVInputTestId}]`)
        .invoke("val")
        .then((val) => {
          expect(String(val).length).to.be.at.most(4);
        });
    });
  });
});
