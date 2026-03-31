/**
 * Critical Path Regression Smoke Test
 * End-to-end smoke test covering the most critical payment flows
 * across connectors to ensure nothing is broken.
 */
import * as testIds from "../../../../../src/Utilities/TestUtils.bs";
import {
  getClientURL,
  createPaymentBody,
  changeObjectKeyValue,
  removeObjectKey,
  connectorEnum,
  connectorProfileIdMapping,
} from "../../../support/utils";
import {
  stripeCards,
  cybersourceCards,
  trustpayCards,
  bankOfAmericaCards,
} from "../../../support/cards";

describe("Critical Path Regression Smoke Tests", () => {
  const publishableKey = Cypress.env("HYPERSWITCH_PUBLISHABLE_KEY");
  const secretKey = Cypress.env("HYPERSWITCH_SECRET_KEY");
  let getIframeBody: () => Cypress.Chainable<JQuery<HTMLBodyElement>>;
  const iframeSelector =
    "#orca-payment-element-iframeRef-orca-elements-payment-element-payment-element";

  beforeEach(() => {
    getIframeBody = () => cy.iframe(iframeSelector);
    changeObjectKeyValue(createPaymentBody, "capture_method", "automatic");
    // Restore billing in case a prior test removed it
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
      phone: {
        number: "8056594427",
        country_code: "+91",
      },
    });
  });

  describe("Stripe - Card Payment (No 3DS)", () => {
    it("should complete a successful card payment via Stripe", () => {
      changeObjectKeyValue(
        createPaymentBody,
        "profile_id",
        connectorProfileIdMapping.get(connectorEnum.STRIPE),
      );
      changeObjectKeyValue(
        createPaymentBody,
        "customer_id",
        "smoke_stripe_user",
      );
      changeObjectKeyValue(
        createPaymentBody,
        "authentication_type",
        "no_three_ds",
      );
      changeObjectKeyValue(createPaymentBody, "currency", "USD");

      cy.createPaymentIntent(secretKey, createPaymentBody).then(() => {
        cy.getGlobalState("clientSecret").then((clientSecret) => {
          cy.visit(getClientURL(clientSecret, publishableKey));
        });
      });

      cy.waitForSDKReady();

      cy.enterCardDetails(stripeCards.successCard);

      cy.get("#submit").click();

      cy.contains("Thanks for your order!", { timeout: 10000 }).should(
        "be.visible",
      );
    });
  });

  describe("Stripe - Card Payment (3DS)", () => {
    it("should redirect to 3DS for Stripe 3DS card", () => {
      changeObjectKeyValue(
        createPaymentBody,
        "profile_id",
        connectorProfileIdMapping.get(connectorEnum.STRIPE),
      );
      changeObjectKeyValue(
        createPaymentBody,
        "customer_id",
        "smoke_stripe_3ds_user",
      );
      changeObjectKeyValue(
        createPaymentBody,
        "authentication_type",
        "three_ds",
      );
      changeObjectKeyValue(createPaymentBody, "currency", "USD");

      cy.createPaymentIntent(secretKey, createPaymentBody).then(() => {
        cy.getGlobalState("clientSecret").then((clientSecret) => {
          cy.visit(getClientURL(clientSecret, publishableKey));
        });
      });

      cy.waitForSDKReady();

      cy.enterCardDetails(stripeCards.threeDSCard);

      cy.get("#submit").click();

      cy.url({ timeout: 15000 }).should("include", "stripe.com");
    });
  });

  describe("Cybersource - Card Payment", () => {
    it("should complete a successful card payment via Cybersource", () => {
      changeObjectKeyValue(
        createPaymentBody,
        "profile_id",
        connectorProfileIdMapping.get(connectorEnum.CYBERSOURCE),
      );
      changeObjectKeyValue(
        createPaymentBody,
        "customer_id",
        "smoke_cybersource_user",
      );
      changeObjectKeyValue(
        createPaymentBody,
        "authentication_type",
        "no_three_ds",
      );
      changeObjectKeyValue(createPaymentBody, "currency", "USD");

      cy.createPaymentIntent(secretKey, createPaymentBody).then(() => {
        cy.getGlobalState("clientSecret").then((clientSecret) => {
          cy.visit(getClientURL(clientSecret, publishableKey));
        });
      });

      cy.waitForSDKReady();

      cy.enterCardDetails(cybersourceCards.successCard);

      cy.get("#submit").click();

      cy.contains("Thanks for your order!", { timeout: 10000 }).should(
        "be.visible",
      );
    });
  });

  describe("Trustpay - Card Payment", () => {
    it("should complete a successful card payment via Trustpay", () => {
      changeObjectKeyValue(
        createPaymentBody,
        "profile_id",
        connectorProfileIdMapping.get(connectorEnum.TRUSTPAY),
      );
      changeObjectKeyValue(
        createPaymentBody,
        "customer_id",
        "smoke_trustpay_user",
      );
      changeObjectKeyValue(
        createPaymentBody,
        "authentication_type",
        "no_three_ds",
      );
      changeObjectKeyValue(createPaymentBody, "currency", "USD");

      cy.createPaymentIntent(secretKey, createPaymentBody).then(() => {
        cy.getGlobalState("clientSecret").then((clientSecret) => {
          cy.visit(getClientURL(clientSecret, publishableKey));
        });
      });

      cy.waitForSDKReady();

      cy.enterCardDetails(trustpayCards.successCard);

      cy.get("#submit").click();

      cy.contains("Thanks for your order!", { timeout: 10000 }).should(
        "be.visible",
      );
    });
  });

  describe("Bank of America - Card Payment", () => {
    it("should complete a successful card payment via Bank of America", () => {
      changeObjectKeyValue(
        createPaymentBody,
        "profile_id",
        connectorProfileIdMapping.get(connectorEnum.BANK_OF_AMERICA),
      );
      changeObjectKeyValue(
        createPaymentBody,
        "customer_id",
        "smoke_boa_user",
      );
      changeObjectKeyValue(
        createPaymentBody,
        "authentication_type",
        "no_three_ds",
      );
      changeObjectKeyValue(createPaymentBody, "currency", "USD");

      cy.createPaymentIntent(secretKey, createPaymentBody).then(() => {
        cy.getGlobalState("clientSecret").then((clientSecret) => {
          cy.visit(getClientURL(clientSecret, publishableKey));
        });
      });

      cy.waitForSDKReady();

      cy.enterCardDetails(bankOfAmericaCards.successCard);

      cy.get("#submit").click();

      cy.contains("Thanks for your order!", { timeout: 10000 }).should(
        "be.visible",
      );
    });
  });

  describe("Card Validation Smoke", () => {
    it("should show error for invalid card number", () => {
      changeObjectKeyValue(
        createPaymentBody,
        "profile_id",
        connectorProfileIdMapping.get(connectorEnum.STRIPE),
      );
      changeObjectKeyValue(
        createPaymentBody,
        "customer_id",
        "smoke_validation_user",
      );
      changeObjectKeyValue(
        createPaymentBody,
        "authentication_type",
        "no_three_ds",
      );

      cy.createPaymentIntent(secretKey, createPaymentBody).then(() => {
        cy.getGlobalState("clientSecret").then((clientSecret) => {
          cy.visit(getClientURL(clientSecret, publishableKey));
        });
      });

      cy.waitForSDKReady();

      getIframeBody()
        .find(`[data-testid=${testIds.cardNoInputTestId}]`)
        .safeType("111111");

      getIframeBody()
        .find(`[data-testid=${testIds.expiryInputTestId}]`)
        .safeType("1230");

      getIframeBody()
        .find(`[data-testid=${testIds.cardCVVInputTestId}]`)
        .safeType("123");

      cy.get("#submit").click();

      getIframeBody()
        .find(".Error.pt-1", { timeout: 5000 })
        .should("be.visible")
        .and("contain.text", "Please enter a valid card number.");
    });

    it("should show error for expired card", () => {
      changeObjectKeyValue(
        createPaymentBody,
        "profile_id",
        connectorProfileIdMapping.get(connectorEnum.STRIPE),
      );
      changeObjectKeyValue(
        createPaymentBody,
        "customer_id",
        "smoke_expired_user",
      );
      changeObjectKeyValue(
        createPaymentBody,
        "authentication_type",
        "no_three_ds",
      );

      cy.createPaymentIntent(secretKey, createPaymentBody).then(() => {
        cy.getGlobalState("clientSecret").then((clientSecret) => {
          cy.visit(getClientURL(clientSecret, publishableKey));
        });
      });

      cy.waitForSDKReady();

      getIframeBody()
        .find(`[data-testid=${testIds.cardNoInputTestId}]`)
        .safeType(stripeCards.successCard.cardNo);

      getIframeBody()
        .find(`[data-testid=${testIds.expiryInputTestId}]`)
        .safeType("0123");

      getIframeBody()
        .find(`[data-testid=${testIds.cardCVVInputTestId}]`)
        .safeType("123");

      cy.get("#submit").click();

      getIframeBody()
        .find(".Error.pt-1", { timeout: 5000 })
        .should("be.visible")
        .and("contain.text", "Your card's expiration year is in the past.");
    });

    it("should show error when submitting empty form", () => {
      changeObjectKeyValue(
        createPaymentBody,
        "profile_id",
        connectorProfileIdMapping.get(connectorEnum.STRIPE),
      );
      changeObjectKeyValue(
        createPaymentBody,
        "customer_id",
        "smoke_empty_form_user",
      );
      changeObjectKeyValue(
        createPaymentBody,
        "authentication_type",
        "no_three_ds",
      );

      cy.createPaymentIntent(secretKey, createPaymentBody).then(() => {
        cy.getGlobalState("clientSecret").then((clientSecret) => {
          cy.visit(getClientURL(clientSecret, publishableKey));
        });
      });

      cy.waitForSDKReady();

      cy.get("#submit").click();

      getIframeBody()
        .find(".Error.pt-1", { timeout: 5000 })
        .should("be.visible");
    });
  });

  describe("Manual Capture Smoke", () => {
    it("should authorize payment with manual capture via Stripe", () => {
      changeObjectKeyValue(
        createPaymentBody,
        "profile_id",
        connectorProfileIdMapping.get(connectorEnum.STRIPE),
      );
      changeObjectKeyValue(
        createPaymentBody,
        "customer_id",
        "smoke_manual_capture_user",
      );
      changeObjectKeyValue(
        createPaymentBody,
        "authentication_type",
        "no_three_ds",
      );
      changeObjectKeyValue(createPaymentBody, "capture_method", "manual");

      cy.createPaymentIntent(secretKey, createPaymentBody).then(() => {
        cy.getGlobalState("clientSecret").then((clientSecret) => {
          cy.visit(getClientURL(clientSecret, publishableKey));
        });
      });

      cy.waitForSDKReady();

      cy.enterCardDetails(stripeCards.successCard);

      cy.get("#submit").click();

      cy.contains(/Thanks for your order|authorized/i, {
        timeout: 10000,
      }).should("be.visible");
    });
  });

  describe("Dynamic Fields Smoke", () => {
    it("should render and submit billing fields when billing is removed", () => {
      changeObjectKeyValue(
        createPaymentBody,
        "profile_id",
        connectorProfileIdMapping.get(connectorEnum.CYBERSOURCE),
      );
      changeObjectKeyValue(
        createPaymentBody,
        "customer_id",
        "smoke_dynamic_fields_user",
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

      // Verify billing fields render
      getIframeBody()
        .find('input[name="line1"]')
        .should("be.visible");

      // Fill card details
      cy.enterCardDetails(cybersourceCards.successCard);

      // Fill Card Holder Name (required by Cybersource)
      // DynamicFields.res renders FullName case via FullNamePaymentInput -> PaymentField
      // PaymentField.res sets `name` on the <input> but NOT `data-testid`, so use input[name=...]
      // The field uses fullNameInputTestId ("FullName"), not cardHolderNameInputTestId ("BillingName")
      getIframeBody()
        .find(`input[name="${testIds.fullNameInputTestId}"]`)
        .type("Joseph Doe");

      // Select United States as country
      // DropdownField.res renders <select> with ariaLabel but no data-testid
      getIframeBody()
        .find('select[aria-label="Country option tab"]')
        .select("United States");

      // Fill billing fields
      getIframeBody()
        .find('input[name="line1"]')
        .type("1467 Harrison Street");
      getIframeBody().find('input[name="city"]').type("San Francisco");

      // Select state after country is set to US
      // PaymentDropDownField.res renders <select> with ariaLabel but no data-testid
      getIframeBody()
        .find('select[aria-label="State option tab"]')
        .select("California");

      getIframeBody().find('input[name="postal"]').type("94122");

      cy.get("#submit").click();

      cy.contains("Thanks for your order!", { timeout: 15000 }).should(
        "be.visible",
      );
    });
  });

  describe("SDK Initialization Smoke", () => {
    it("should load SDK iframe successfully", () => {
      changeObjectKeyValue(
        createPaymentBody,
        "profile_id",
        connectorProfileIdMapping.get(connectorEnum.STRIPE),
      );
      changeObjectKeyValue(
        createPaymentBody,
        "customer_id",
        "smoke_init_user",
      );
      changeObjectKeyValue(
        createPaymentBody,
        "authentication_type",
        "no_three_ds",
      );

      cy.createPaymentIntent(secretKey, createPaymentBody).then(() => {
        cy.getGlobalState("clientSecret").then((clientSecret) => {
          cy.visit(getClientURL(clientSecret, publishableKey));
        });
      });

      cy.waitForSDKReady();

      cy.get(iframeSelector).should("be.visible");

      getIframeBody()
        .find(`[data-testid=${testIds.cardNoInputTestId}]`)
        .should("be.visible");

      getIframeBody()
        .find(`[data-testid=${testIds.expiryInputTestId}]`)
        .should("be.visible");

      getIframeBody()
        .find(`[data-testid=${testIds.cardCVVInputTestId}]`)
        .should("be.visible");

      cy.get("#submit").should("be.visible");
    });
  });
});
