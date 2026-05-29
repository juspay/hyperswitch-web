/**
 * Branding Visibility Tests
 * Verifies that the branding option controls the visibility of the
 * "Powered by Hyperswitch" icon in the payment element.
 */
import {
  getClientURL,
  createPaymentBody,
  changeObjectKeyValue,
} from "../../support/utils";

describe("PaymentElement branding Option", () => {
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
      "branding_test_user"
    );
    changeObjectKeyValue(
      createPaymentBody,
      "authentication_type",
      "no_three_ds"
    );
  });

  describe('branding: "auto" (default)', () => {
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
              { branding: "auto" }
            )
          );
          cy.waitForSDKReady();
        });
      });
    });

    it("should display the Hyperswitch branding icon", () => {
      getIframeBody()
        .find("svg", { timeout: 10000 })
        .filter((_index, el) => {
          const useEl = el.querySelector("use");
          if (!useEl) return false;
          const href =
            useEl.getAttribute("href") ||
            useEl.getAttributeNS("http://www.w3.org/1999/xlink", "href") ||
            "";
          return href.includes("powerd-by-hyper");
        })
        .should("have.length.greaterThan", 0);
    });
  });

  describe('branding: "never"', () => {
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
              { branding: "never" }
            )
          );
          cy.waitForSDKReady();
        });
      });
    });

    it("should hide the Hyperswitch branding icon", () => {
      getIframeBody().then(($body) => {
        const svgs = $body.find("svg");
        const brandingSvgs = svgs.filter((_index, el) => {
          const useEl = el.querySelector("use");
          if (!useEl) return false;
          const href =
            useEl.getAttribute("href") ||
            useEl.getAttributeNS("http://www.w3.org/1999/xlink", "href") ||
            "";
          return href.includes("powerd-by-hyper");
        });
        expect(brandingSvgs.length).to.equal(0);
      });
    });
  });
});
