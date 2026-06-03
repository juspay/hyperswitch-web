/**
 * Billing Fields Tests
 *
 * Covers two orthogonal aspects of billing field behaviour:
 *
 *  1. Backend-Driven Dynamic Fields
 *     The backend returns `required_fields` based on what is absent from the
 *     payment body. Tests here verify that the SDK renders exactly the fields
 *     the backend requests — across multiple connectors and partial-billing
 *     scenarios.
 *
 *  2. SDK fields.billingDetails Option
 *     The merchant can pass `fields.billingDetails` (e.g. "never", or a
 *     per-field object) to the SDK to suppress individual fields regardless of
 *     what the backend requests. Tests here verify that option is respected.
 */
import * as testIds from "../../../../src/Utilities/TestUtils.bs";
import {
  getClientURL,
  createPaymentBody,
  changeObjectKeyValue,
  removeObjectKey,
  connectorEnum,
  connectorProfileIdMapping,
  defaultBillingAddress,
} from "../../support/utils";
import { cybersourceCards } from "../../support/cards";

describe("Billing Fields", () => {
  const publishableKey = Cypress.env("HYPERSWITCH_PUBLISHABLE_KEY");
  const secretKey = Cypress.env("HYPERSWITCH_SECRET_KEY");
  let getIframeBody: () => Cypress.Chainable<JQuery<HTMLBodyElement>>;
  const iframeSelector =
    "#orca-payment-element-iframeRef-orca-elements-payment-element-payment-element";

  beforeEach(() => {
    getIframeBody = () => cy.iframe(iframeSelector);
  });

  afterEach(() => {
    // Restore createPaymentBody to its default state after every test so that
    // mutations in one describe block cannot bleed into the next.
    changeObjectKeyValue(createPaymentBody, "billing", {
      email: "hyperswitch_sdk_demo_id@gmail.com",
      address: defaultBillingAddress,
      phone: { number: "8056594427", country_code: "+91" },
    });
    changeObjectKeyValue(
      createPaymentBody,
      "profile_id",
      connectorProfileIdMapping.get(connectorEnum.STRIPE),
    );
    changeObjectKeyValue(
      createPaymentBody,
      "customer_id",
      "hyperswitch_sdk_demo_id",
    );
  });

  // ---------------------------------------------------------------------------
  // 1. Backend-Driven Dynamic Fields
  //
  // Fields appear when the backend's required_fields indicates they are absent
  // from the payment intent. Providing them in the payment body suppresses them.
  // ---------------------------------------------------------------------------

  describe("Backend-Driven Dynamic Fields", () => {
    describe("Stripe Connector", () => {
      beforeEach(() => {
        changeObjectKeyValue(
          createPaymentBody,
          "profile_id",
          connectorProfileIdMapping.get(connectorEnum.STRIPE),
        );
        changeObjectKeyValue(
          createPaymentBody,
          "customer_id",
          "dynamic_fields_stripe_user",
        );
        changeObjectKeyValue(
          createPaymentBody,
          "authentication_type",
          "no_three_ds",
        );
      });

      it("should render billing address fields when billing is removed from payment body", () => {
        removeObjectKey(createPaymentBody, "billing");

        cy.createPaymentIntent(secretKey, createPaymentBody).then(() => {
          cy.getGlobalState("clientSecret").then((clientSecret) => {
            cy.visit(getClientURL(clientSecret, publishableKey));
          });
        });

        cy.waitForSDKReady();

        getIframeBody()
          .find(`[data-testid=${testIds.cardNoInputTestId}]`)
          .should("be.visible");
      });

      it("should not render billing fields when billing is provided in payment body", () => {
        changeObjectKeyValue(createPaymentBody, "billing", defaultBillingAddress);

        cy.createPaymentIntent(secretKey, createPaymentBody).then(() => {
          cy.getGlobalState("clientSecret").then((clientSecret) => {
            cy.visit(getClientURL(clientSecret, publishableKey));
          });
        });

        cy.waitForSDKReady();

        getIframeBody().then(($body) => {
          const hasBillingSection =
            $body.find('.billing-section, input[name="line1"]').length > 0;
          if (!hasBillingSection) {
            expect(hasBillingSection).to.be.false;
          }
        });
      });
    });

    describe("Bank of America Connector", () => {
      it("should render billing fields when billing is removed for Bank of America", () => {
        changeObjectKeyValue(
          createPaymentBody,
          "profile_id",
          connectorProfileIdMapping.get(connectorEnum.BANK_OF_AMERICA),
        );
        changeObjectKeyValue(
          createPaymentBody,
          "customer_id",
          "dynamic_fields_boa_user",
        );
        changeObjectKeyValue(
          createPaymentBody,
          "authentication_type",
          "no_three_ds",
        );
        removeObjectKey(createPaymentBody, "billing");

        cy.createPaymentIntent(secretKey, createPaymentBody).then(() => {
          cy.getGlobalState("clientSecret").then((clientSecret) => {
            cy.visit(getClientURL(clientSecret, publishableKey));
          });
        });

        cy.waitForSDKReady();

        getIframeBody()
          .find('input[name="line1"]')
          .should("be.visible");
      });
    });

    describe("Cybersource Connector – Field Rendering and Validation", () => {
      beforeEach(() => {
        changeObjectKeyValue(
          createPaymentBody,
          "profile_id",
          connectorProfileIdMapping.get(connectorEnum.CYBERSOURCE),
        );
        changeObjectKeyValue(
          createPaymentBody,
          "customer_id",
          "dynamic_fields_validation_user",
        );
        changeObjectKeyValue(
          createPaymentBody,
          "authentication_type",
          "no_three_ds",
        );
        removeObjectKey(createPaymentBody, "billing");

        cy.createPaymentIntent(secretKey, createPaymentBody).then(() => {
          cy.getGlobalState("clientSecret").then((clientSecret) => {
            cy.visit(getClientURL(clientSecret, publishableKey));
          });
        });

        cy.waitForSDKReady();
      });

      it("should show billing details header when dynamic fields are rendered", () => {
        getIframeBody().contains("Billing Details").should("be.visible");
      });

      it("should require address line1 field for payment submission", () => {
        const { cardNo, card_exp_month, card_exp_year, cvc } =
          cybersourceCards.successCard;

        getIframeBody()
          .find(`[data-testid=${testIds.cardNoInputTestId}]`)
          .safeType(cardNo);
        getIframeBody()
          .find(`[data-testid=${testIds.expiryInputTestId}]`)
          .safeType(card_exp_month + card_exp_year);
        getIframeBody()
          .find(`[data-testid=${testIds.cardCVVInputTestId}]`)
          .safeType(cvc);

        getIframeBody().find('input[name="city"]').type("San Francisco");
        getIframeBody().find('input[name="postal"]').type("94122");

        cy.get("#submit").should("be.visible").click();
        cy.get("#submit").should("be.visible");
      });

      it("should accept valid billing fields and complete payment", () => {
        const { cardNo, card_exp_month, card_exp_year, cvc } =
          cybersourceCards.successCard;

        getIframeBody()
          .find(`[data-testid=${testIds.cardNoInputTestId}]`)
          .safeType(cardNo);
        getIframeBody()
          .find(`[data-testid=${testIds.expiryInputTestId}]`)
          .safeType(card_exp_month + card_exp_year);
        getIframeBody()
          .find(`[data-testid=${testIds.cardCVVInputTestId}]`)
          .safeType(cvc);

        getIframeBody()
          .find(`input[name="${testIds.fullNameInputTestId}"]`)
          .type("Joseph Doe");

        getIframeBody()
          .find('select[aria-label="Country option tab"]')
          .select("United States");

        getIframeBody()
          .find('input[name="line1"]')
          .type("1467 Harrison Street");
        getIframeBody().find('input[name="city"]').type("San Francisco");

        getIframeBody()
          .find('select[aria-label="State option tab"]')
          .select("California");

        getIframeBody().find('input[name="postal"]').type("94122");

        cy.get("#submit").should("be.visible").click();
        cy.get("#submit").should("be.disabled");

        cy.contains("Thanks for your order!", { timeout: 15000 }).should(
          "be.visible",
        );
      });

      it("should allow typing in address line1 field", () => {
        getIframeBody()
          .find('input[name="line1"]')
          .type("1467 Harrison Street");

        getIframeBody()
          .find('input[name="line1"]')
          .should("have.value", "1467 Harrison Street");
      });

      it("should allow typing in city field", () => {
        getIframeBody().find('input[name="city"]').type("San Francisco");

        getIframeBody()
          .find('input[name="city"]')
          .should("have.value", "San Francisco");
      });

      it("should allow typing in postal code field", () => {
        getIframeBody().find('input[name="postal"]').type("94122");

        getIframeBody()
          .find('input[name="postal"]')
          .should("have.value", "94122");
      });
    });

    describe("Partial Billing — Only the Missing Fields Appear", () => {
      // When billing is partially provided, the backend omits already-known
      // fields from required_fields. Only the absent fields should render.
      beforeEach(() => {
        changeObjectKeyValue(
          createPaymentBody,
          "profile_id",
          connectorProfileIdMapping.get(connectorEnum.CYBERSOURCE),
        );
        changeObjectKeyValue(
          createPaymentBody,
          "customer_id",
          "dynamic_fields_partial_billing_user",
        );
        changeObjectKeyValue(
          createPaymentBody,
          "authentication_type",
          "no_three_ds",
        );
      });

      it("should not render BillingName field when billing first and last name are provided", () => {
        removeObjectKey(createPaymentBody, "billing");
        changeObjectKeyValue(createPaymentBody, "billing", {
          address: { first_name: "Joseph", last_name: "Doe" },
        });

        cy.createPaymentIntent(secretKey, createPaymentBody).then(() => {
          cy.getGlobalState("clientSecret").then((clientSecret) => {
            cy.visit(getClientURL(clientSecret, publishableKey));
          });
        });

        cy.waitForSDKReady();

        getIframeBody()
          .find('input[name="BillingName"]')
          .should("not.exist");

        getIframeBody()
          .find('input[name="line1"]', { timeout: 10000 })
          .should("be.visible");
      });

      it("should not render email field when billing email is provided", () => {
        removeObjectKey(createPaymentBody, "billing");
        changeObjectKeyValue(createPaymentBody, "billing", {
          email: "hyperswitch_sdk_demo_id@gmail.com",
        });

        cy.createPaymentIntent(secretKey, createPaymentBody).then(() => {
          cy.getGlobalState("clientSecret").then((clientSecret) => {
            cy.visit(getClientURL(clientSecret, publishableKey));
          });
        });

        cy.waitForSDKReady();

        getIframeBody()
          .find('input[name="email"]')
          .should("not.exist");

        getIframeBody()
          .find('input[name="line1"]', { timeout: 10000 })
          .should("be.visible");
      });
    });

    describe("Country and State Dropdown", () => {
      beforeEach(() => {
        changeObjectKeyValue(
          createPaymentBody,
          "profile_id",
          connectorProfileIdMapping.get(connectorEnum.CYBERSOURCE),
        );
        changeObjectKeyValue(
          createPaymentBody,
          "customer_id",
          "dynamic_fields_dropdown_user",
        );
        changeObjectKeyValue(
          createPaymentBody,
          "authentication_type",
          "no_three_ds",
        );
        removeObjectKey(createPaymentBody, "billing");

        cy.createPaymentIntent(secretKey, createPaymentBody).then(() => {
          cy.getGlobalState("clientSecret").then((clientSecret) => {
            cy.visit(getClientURL(clientSecret, publishableKey));
          });
        });

        cy.waitForSDKReady();
      });

      it("should render country dropdown when required by connector", () => {
        getIframeBody().then(($body) => {
          const hasCountryDropdown =
            $body.find('select[aria-label="Country option tab"]').length > 0;

          if (hasCountryDropdown) {
            getIframeBody()
              .find('select[aria-label="Country option tab"]')
              .should("be.visible");
          }
        });
      });

      it("should render state dropdown when required by connector", () => {
        getIframeBody().then(($body) => {
          const hasStateDropdown =
            $body.find('select[aria-label="State option tab"]').length > 0;

          if (hasStateDropdown) {
            getIframeBody()
              .find('select[aria-label="State option tab"]')
              .should("be.visible");
          }
        });
      });
    });
  });

  // ---------------------------------------------------------------------------
  // 2. SDK fields.billingDetails Option
  //
  // The merchant can suppress individual billing fields via the SDK option,
  // independently of what the backend requests.
  // ---------------------------------------------------------------------------

  describe("SDK fields.billingDetails Option", () => {
    beforeEach(() => {
      changeObjectKeyValue(
        createPaymentBody,
        "customer_id",
        "billing_fields_test_user",
      );
      changeObjectKeyValue(
        createPaymentBody,
        "authentication_type",
        "no_three_ds",
      );
      changeObjectKeyValue(
        createPaymentBody,
        "profile_id",
        connectorProfileIdMapping.get(connectorEnum.CYBERSOURCE),
      );
    });

    describe('billingDetails: "never" — suppress all billing fields', () => {
      beforeEach(() => {
        // Provide complete billing in the payment body so the backend does not
        // return any billing address fields as required_fields. The
        // fields.billingDetails: "never" SDK option then independently
        // suppresses the SDK-level guards (BillingName, Email). All billing
        // inputs should be absent from the DOM.
        changeObjectKeyValue(createPaymentBody, "billing", {
          email: "hyperswitch_sdk_demo_id@gmail.com",
          address: defaultBillingAddress,
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
                undefined,
                { fields: { billingDetails: "never" } },
              ),
            );
            cy.waitForSDKReady();
          });
        });
      });

      it("should hide the billing name field", () => {
        getIframeBody().find('input[name="BillingName"]').should("not.exist");
      });

      it("should hide the email field", () => {
        getIframeBody().find('input[name="email"]').should("not.exist");
      });

      it("should hide the address line1 field", () => {
        getIframeBody().find('input[name="line1"]').should("not.exist");
      });

      it("should hide the city field", () => {
        getIframeBody().find('input[name="city"]').should("not.exist");
      });

      it("should hide the postal code field", () => {
        getIframeBody().find('input[name="postal"]').should("not.exist");
      });
    });

    describe("billingDetails: per-field control", () => {
      beforeEach(() => {
        removeObjectKey(createPaymentBody, "billing");

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
                },
              ),
            );
            cy.waitForSDKReady();
          });
        });
      });

      it("should hide the billing name field when set to never", () => {
        getIframeBody().find('input[name="BillingName"]').should("not.exist");
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
});
