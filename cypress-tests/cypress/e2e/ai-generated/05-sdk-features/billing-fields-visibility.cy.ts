/**
 * Billing Details Field Visibility Tests
 * Verifies that the fields.billingDetails option controls visibility
 * of individual billing fields (name, email, phone, address sub-fields).
 *
 * Note: Dynamic billing fields rendered via PaymentField component
 * use `name` attribute (not `data-testid`) for identification.
 * Billing fields only appear when billing is NOT provided in the
 * payment body (so the backend requests them dynamically).
 */
import {
  getClientURL,
  createPaymentBody,
  changeObjectKeyValue,
  removeObjectKey,
  connectorEnum,
  connectorProfileIdMapping,
} from "../../../support/utils";

describe("PaymentElement fields.billingDetails Option", () => {
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
      "billing_fields_test_user"
    );
    changeObjectKeyValue(
      createPaymentBody,
      "authentication_type",
      "no_three_ds"
    );
    // Remove billing from payment body to force dynamic field rendering
    removeObjectKey(createPaymentBody, "billing");
    changeObjectKeyValue(
      createPaymentBody,
      "profile_id",
      connectorProfileIdMapping.get(connectorEnum.CYBERSOURCE) as string
    );
  });

  afterEach(() => {
    // Restore billing for other tests
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
    changeObjectKeyValue(
      createPaymentBody,
      "profile_id",
      connectorProfileIdMapping.get(connectorEnum.STRIPE) as string
    );
  });

  describe('fields.billingDetails: "never" (hide all billing fields)', () => {
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
                fields: {
                  billingDetails: "never",
                },
              }
            )
          );
          cy.waitForSDKReady();
        });
      });
    });

    it("should hide the billing name field", () => {
      getIframeBody()
        .find('input[name="BillingName"]')
        .should("not.exist");
    });

    it("should hide the email field", () => {
      getIframeBody()
        .find('input[name="email"]')
        .should("not.exist");
    });

    it("should hide the address line1 field", () => {
      getIframeBody()
        .find('input[name="line1"]')
        .should("not.exist");
    });

    it("should hide the city field", () => {
      getIframeBody()
        .find('input[name="city"]')
        .should("not.exist");
    });

    it("should hide the postal code field", () => {
      getIframeBody()
        .find('input[name="postal"]')
        .should("not.exist");
    });
  });

  describe("fields.billingDetails: selective field visibility", () => {
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
                fields: {
                  billingDetails: {
                    name: "never",
                    email: "auto",
                    phone: "never",
                    address: {
                      line1: "auto",
                      line2: "never",
                      city: "auto",
                      state: "auto",
                      country: "auto",
                      postal_code: "auto",
                    },
                  },
                },
              }
            )
          );
          cy.waitForSDKReady();
        });
      });
    });

    it("should hide the billing name field when set to never", () => {
      getIframeBody()
        .find('input[name="BillingName"]')
        .should("not.exist");
    });

    it("should show address line1 field when set to auto", () => {
      getIframeBody()
        .find('input[name="line1"]', { timeout: 10000 })
        .should("be.visible");
    });

    it("should show city field when set to auto", () => {
      getIframeBody()
        .find('input[name="city"]', { timeout: 10000 })
        .should("be.visible");
    });

    it("should show postal code field when set to auto", () => {
      getIframeBody()
        .find('input[name="postal"]', { timeout: 10000 })
        .should("be.visible");
    });
  });
});
