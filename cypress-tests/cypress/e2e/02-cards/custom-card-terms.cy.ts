/**
 * Custom Card Terms Message Tests
 * Verifies that the customMessageForCardTerms option renders
 * custom text in place of the default card terms message.
 */
import * as testIds from "../../../../src/Utilities/TestUtils.bs";
import {
  getClientURL,
  createPaymentBody,
  changeObjectKeyValue,
} from "../../support/utils";
import { stripeCards } from "../../support/cards";

describe("PaymentElement customMessageForCardTerms Option", () => {
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
      "custom_terms_test_user"
    );
    changeObjectKeyValue(
      createPaymentBody,
      "authentication_type",
      "no_three_ds"
    );
    changeObjectKeyValue(
      createPaymentBody,
      "setup_future_usage",
      "off_session"
    );
  });

  afterEach(() => {
    delete (createPaymentBody as Record<string, unknown>)["setup_future_usage"];
  });

  describe("custom terms message", () => {
    const customTermsText =
      "By proceeding, you agree to our custom payment terms and conditions.";

    beforeEach(() => {
      cy.createPaymentIntent(secretKey, createPaymentBody).then(() => {
        cy.getGlobalState("clientSecret").then((clientSecret) => {
          cy.visit(
            getClientURL(
              clientSecret,
              publishableKey,
              undefined,
              undefined,
              undefined,
              {
                customMessageForCardTerms: customTermsText,
                terms: { card: "always" },
              }
            )
          );
          cy.waitForSDKReady();
        });
      });
    });

    it("should display the custom terms message text", () => {
      getIframeBody()
        .find(".TermsTextLabel", { timeout: 10000 })
        .should("be.visible")
        .and("contain.text", customTermsText);
    });
  });

  describe("empty custom terms message (uses default)", () => {
    beforeEach(() => {
      cy.createPaymentIntent(secretKey, createPaymentBody).then(() => {
        cy.getGlobalState("clientSecret").then((clientSecret) => {
          cy.visit(
            getClientURL(
              clientSecret,
              publishableKey,
              undefined,
              undefined,
              undefined,
              {
                customMessageForCardTerms: "",
                terms: { card: "always" },
              }
            )
          );
          cy.waitForSDKReady();
        });
      });
    });

    it("should display the default terms message when custom message is empty", () => {
      getIframeBody()
        .find(".TermsTextLabel", { timeout: 10000 })
        .should("be.visible")
        .and("not.have.text", "");
    });
  });
});
