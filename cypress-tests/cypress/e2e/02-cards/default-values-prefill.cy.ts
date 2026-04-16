/**
 * Default Values Prefill Tests
 * Verifies that the defaultValues option pre-fills billing details
 * (name, email, address) in the payment element form.
 *
 * Note: Dynamic billing fields rendered via PaymentField component
 * use `name` attribute (not `data-testid`) for identification.
 * The billing fields only appear when billing is NOT provided in
 * the payment body (so the backend requests them dynamically).
 */
import {
  getClientURL,
  createPaymentBody,
  changeObjectKeyValue,
  removeObjectKey,
  connectorEnum,
  connectorProfileIdMapping,
} from "../../support/utils";

describe("PaymentElement defaultValues Option", () => {
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
      "prefill_test_user"
    );
    changeObjectKeyValue(
      createPaymentBody,
      "authentication_type",
      "no_three_ds"
    );
    removeObjectKey(createPaymentBody, "billing");
    changeObjectKeyValue(
      createPaymentBody,
      "profile_id",
      connectorProfileIdMapping.get(connectorEnum.CYBERSOURCE) as string
    );
  });

  afterEach(() => {
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

  describe("pre-fill billing details via defaultValues", () => {
    const prefilledName = "John Doe";
    const prefilledLine1 = "123 Main Street";
    const prefilledCity = "New York";
    const prefilledPostal = "10001";

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
                defaultValues: {
                  billingDetails: {
                    name: prefilledName,
                    email: "",
                    phone: "",
                    address: {
                      line1: prefilledLine1,
                      line2: "",
                      city: prefilledCity,
                      state: "",
                      country: "US",
                      postal_code: prefilledPostal,
                    },
                  },
                },
                billingAddress: {
                  isUseBillingAddress: true,
                  usePrefilledValues: "auto",
                },
              }
            )
          );
          cy.waitForSDKReady();
        });
      });
    });

    it("should pre-fill the card holder name field with the default value", () => {
      getIframeBody()
        .find('input[name="FullName"]', { timeout: 10000 })
        .should("have.value", prefilledName);
    });

    it("should pre-fill the address line1 field with the default value", () => {
      getIframeBody()
        .find('input[name="line1"]', { timeout: 10000 })
        .should("have.value", prefilledLine1);
    });

    it("should pre-fill the city field with the default value", () => {
      getIframeBody()
        .find('input[name="city"]', { timeout: 10000 })
        .should("have.value", prefilledCity);
    });

    it("should pre-fill the postal code field with the default value", () => {
      getIframeBody()
        .find('input[name="postal"]', { timeout: 10000 })
        .should("have.value", prefilledPostal);
    });
  });
});
