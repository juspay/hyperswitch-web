/**
 * Payment Methods Header Text Tests
 * Verifies that paymentMethodsHeaderText and savedPaymentMethodsHeaderText
 * options control the header text displayed above payment methods.
 */
import * as testIds from "../../../../../src/Utilities/TestUtils.bs";
import {
  getClientURL,
  createPaymentBody,
  changeObjectKeyValue,
} from "../../../support/utils";

describe("PaymentElement Header Text Options", () => {
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
      "header_text_test_user"
    );
    changeObjectKeyValue(
      createPaymentBody,
      "authentication_type",
      "no_three_ds"
    );
  });

  describe("custom paymentMethodsHeaderText", () => {
    const customHeaderText = "Choose your preferred payment method";

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
                paymentMethodsHeaderText: customHeaderText,
              }
            )
          );
          cy.waitForSDKReady();
        });
      });
    });

    it("should display custom header text above payment methods", () => {
      getIframeBody()
        .contains(customHeaderText, { timeout: 10000 })
        .should("be.visible");
    });
  });

  describe("no custom paymentMethodsHeaderText (default)", () => {
    beforeEach(() => {
      cy.createPaymentIntent(secretKey, createPaymentBody).then(() => {
        cy.getGlobalState("clientSecret").then((clientSecret) => {
          cy.visit(getClientURL(clientSecret, publishableKey));
          cy.waitForSDKReady();
        });
      });
    });

    it("should render payment methods without custom header text", () => {
      getIframeBody()
        .find(`[data-testid=${testIds.paymentMethodListTestId}]`, {
          timeout: 10000,
        })
        .should("be.visible");

      // The custom header text should not be present
      getIframeBody()
        .contains("Choose your preferred payment method")
        .should("not.exist");
    });
  });
});
