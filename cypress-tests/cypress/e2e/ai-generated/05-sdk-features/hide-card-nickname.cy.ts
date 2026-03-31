/**
 * Hide Card Nickname Field Tests
 * Verifies that the hideCardNicknameField option controls
 * the visibility of the card nickname input field.
 *
 * The nickname field (NicknamePaymentInput) only renders when:
 * - hideCardNicknameField is false
 * - isCustomerAcceptanceRequired is true (save checkbox is checked, or SETUP_MANDATE)
 *
 * The nickname field uses data-testid="userCardNickName".
 */
import * as testIds from "../../../../../src/Utilities/TestUtils.bs";
import {
  getClientURL,
  createPaymentBody,
  changeObjectKeyValue,
} from "../../../support/utils";
import { stripeCards } from "../../../support/cards";

describe("PaymentElement hideCardNicknameField Option", () => {
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
      "nickname_test_user"
    );
    changeObjectKeyValue(
      createPaymentBody,
      "authentication_type",
      "no_three_ds"
    );
  });

  describe("hideCardNicknameField: true", () => {
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
                hideCardNicknameField: true,
                displaySavedPaymentMethodsCheckbox: true,
              }
            )
          );
          cy.waitForSDKReady();
        });
      });
    });

    it("should not render the card nickname field even when save checkbox is checked", () => {
      // Wait for card input to be ready
      getIframeBody()
        .find(`[data-testid=${testIds.cardNoInputTestId}]`, { timeout: 10000 })
        .should("be.visible");

      // Check the save checkbox to enable customerAcceptanceRequired
      getIframeBody()
        .find('[role="checkbox"]', { timeout: 10000 })
        .then(($checkbox) => {
          if ($checkbox.length > 0) {
            // Click the checkbox if it's not already checked
            if ($checkbox.attr("aria-checked") !== "true") {
              cy.wrap($checkbox).click();
            }
          }
        });

      // Wait and verify nickname field does NOT appear
      // PaymentField does not have data-testid, use name attribute
      cy.wait(1000);
      getIframeBody()
        .find('input[name="userCardNickName"]')
        .should("not.exist");
    });
  });

  describe("hideCardNicknameField: false (default)", () => {
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
                hideCardNicknameField: false,
                displaySavedPaymentMethodsCheckbox: true,
              }
            )
          );
          cy.waitForSDKReady();
        });
      });
    });

    it("should render the card nickname field when save checkbox is checked", () => {
      // Wait for card input to be ready
      getIframeBody()
        .find(`[data-testid=${testIds.cardNoInputTestId}]`, { timeout: 10000 })
        .should("be.visible");

      // Check the save checkbox to enable customerAcceptanceRequired
      getIframeBody()
        .find('[role="checkbox"]', { timeout: 10000 })
        .then(($checkbox) => {
          if ($checkbox.length > 0 && $checkbox.attr("aria-checked") !== "true") {
            cy.wrap($checkbox).click();
          }
        });

      // Nickname field should appear after checkbox is checked
      // PaymentField does not have data-testid, use name attribute
      getIframeBody()
        .find('input[name="userCardNickName"]', { timeout: 10000 })
        .should("exist");
    });
  });
});
