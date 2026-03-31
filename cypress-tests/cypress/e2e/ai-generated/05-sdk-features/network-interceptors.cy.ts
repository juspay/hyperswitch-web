/**
 * Network Request Tests
 * Tests for SDK network behavior: API call verification,
 * error handling, slow responses, and retry logic.
 * Uses cy.intercept to mock/observe network requests.
 */
import * as testIds from "../../../../../src/Utilities/TestUtils.bs";
import {
  getClientURL,
  createPaymentBody,
  changeObjectKeyValue,
} from "../../../support/utils";
import { stripeCards } from "../../../support/cards";

describe("Network Requests", () => {
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
      "network_test_user",
    );
    changeObjectKeyValue(
      createPaymentBody,
      "authentication_type",
      "no_three_ds",
    );
    changeObjectKeyValue(
      createPaymentBody,
      "profile_id",
      "pro_5fVcCxU8MFTYozgtf0P8",
    );
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
  });

  describe("SDK Initialization API Calls", () => {
    it("should make a GET request to fetch payment methods on load", () => {
      cy.intercept("GET", "**/account/payment_methods*").as(
        "fetchPaymentMethods",
      );

      cy.createPaymentIntent(secretKey, createPaymentBody).then(() => {
        cy.getGlobalState("clientSecret").then((clientSecret) => {
          cy.visit(getClientURL(clientSecret, publishableKey));
          cy.waitForSDKReady();
        });
      });

      cy.wait("@fetchPaymentMethods", { timeout: 15000 }).then(
        (interception) => {
          expect(interception.request.method).to.equal("GET");
          expect(interception.request.url).to.include(
            "account/payment_methods",
          );
          expect(interception.request.url).to.include("client_secret");
        },
      );
    });

    it("should make a GET request to fetch customer saved payment methods", () => {
      cy.intercept("GET", "**/customers/payment_methods*").as(
        "fetchCustomerPMs",
      );

      cy.createPaymentIntent(secretKey, createPaymentBody).then(() => {
        cy.getGlobalState("clientSecret").then((clientSecret) => {
          cy.visit(getClientURL(clientSecret, publishableKey));
          cy.waitForSDKReady();
        });
      });

      cy.wait("@fetchCustomerPMs", { timeout: 15000 }).then(
        (interception) => {
          expect(interception.request.method).to.equal("GET");
          expect(interception.request.url).to.include(
            "customers/payment_methods",
          );
        },
      );
    });

    it("should make a POST request to fetch session tokens", () => {
      cy.intercept("POST", "**/payments/session_tokens*").as(
        "fetchSessions",
      );

      cy.createPaymentIntent(secretKey, createPaymentBody).then(() => {
        cy.getGlobalState("clientSecret").then((clientSecret) => {
          cy.visit(getClientURL(clientSecret, publishableKey));
          cy.waitForSDKReady();
        });
      });

      cy.wait("@fetchSessions", { timeout: 15000 }).then((interception) => {
        expect(interception.request.method).to.equal("POST");
        expect(interception.request.url).to.include("session_tokens");
      });
    });
  });

  describe("Payment Confirmation API Calls", () => {
    it("should make a POST confirm request when submitting payment", () => {
      cy.intercept("POST", "**/payments/*/confirm*").as("confirmPayment");

      cy.createPaymentIntent(secretKey, createPaymentBody).then(() => {
        cy.getGlobalState("clientSecret").then((clientSecret) => {
          cy.visit(getClientURL(clientSecret, publishableKey));
          cy.waitForSDKReady();
        });
      });

      const { cardNo, card_exp_month, card_exp_year, cvc } =
        stripeCards.successCard;

      cy.enterCardDetails({ cardNo, card_exp_month, card_exp_year, cvc });

      cy.get("#submit").click();

      cy.wait("@confirmPayment", { timeout: 15000 }).then((interception) => {
        expect(interception.request.method).to.equal("POST");
        expect(interception.request.url).to.include("/confirm");
      });
    });

    it("should include payment_method_data in confirm request body", () => {
      cy.intercept("POST", "**/payments/*/confirm*").as("confirmPayment");

      cy.createPaymentIntent(secretKey, createPaymentBody).then(() => {
        cy.getGlobalState("clientSecret").then((clientSecret) => {
          cy.visit(getClientURL(clientSecret, publishableKey));
          cy.waitForSDKReady();
        });
      });

      const { cardNo, card_exp_month, card_exp_year, cvc } =
        stripeCards.successCard;

      cy.enterCardDetails({ cardNo, card_exp_month, card_exp_year, cvc });

      cy.get("#submit").click();

      cy.wait("@confirmPayment", { timeout: 15000 }).then((interception) => {
        const body =
          typeof interception.request.body === "string"
            ? JSON.parse(interception.request.body)
            : interception.request.body;

        expect(body).to.have.property("payment_method");
        expect(body.payment_method).to.equal("card");
        expect(body).to.have.property("payment_method_data");
      });
    });

    it("should include browser_info in confirm request body", () => {
      cy.intercept("POST", "**/payments/*/confirm*").as("confirmPayment");

      cy.createPaymentIntent(secretKey, createPaymentBody).then(() => {
        cy.getGlobalState("clientSecret").then((clientSecret) => {
          cy.visit(getClientURL(clientSecret, publishableKey));
          cy.waitForSDKReady();
        });
      });

      const { cardNo, card_exp_month, card_exp_year, cvc } =
        stripeCards.successCard;

      cy.enterCardDetails({ cardNo, card_exp_month, card_exp_year, cvc });

      cy.get("#submit").click();

      cy.wait("@confirmPayment", { timeout: 15000 }).then((interception) => {
        const body =
          typeof interception.request.body === "string"
            ? JSON.parse(interception.request.body)
            : interception.request.body;

        expect(body).to.have.property("browser_info");
        expect(body.browser_info).to.have.property("user_agent");
        expect(body.browser_info).to.have.property("language");
      });
    });

    it("should include client_secret in confirm request body", () => {
      cy.intercept("POST", "**/payments/*/confirm*").as("confirmPayment");

      cy.createPaymentIntent(secretKey, createPaymentBody).then(() => {
        cy.getGlobalState("clientSecret").then((clientSecret) => {
          cy.visit(getClientURL(clientSecret, publishableKey));
          cy.waitForSDKReady();
        });
      });

      const { cardNo, card_exp_month, card_exp_year, cvc } =
        stripeCards.successCard;

      cy.enterCardDetails({ cardNo, card_exp_month, card_exp_year, cvc });

      cy.get("#submit").click();

      cy.wait("@confirmPayment", { timeout: 15000 }).then((interception) => {
        const body =
          typeof interception.request.body === "string"
            ? JSON.parse(interception.request.body)
            : interception.request.body;

        expect(body).to.have.property("client_secret");
        expect(body.client_secret).to.not.be.empty;
      });
    });
  });

  describe("Request Headers", () => {
    it("should include api-key header with publishable key", () => {
      cy.intercept("GET", "**/account/payment_methods*").as(
        "fetchPaymentMethods",
      );

      cy.createPaymentIntent(secretKey, createPaymentBody).then(() => {
        cy.getGlobalState("clientSecret").then((clientSecret) => {
          cy.visit(getClientURL(clientSecret, publishableKey));
          cy.waitForSDKReady();
        });
      });

      cy.wait("@fetchPaymentMethods", { timeout: 15000 }).then(
        (interception) => {
          const headers = interception.request.headers;
          // Should have either api-key or authorization header
          const hasAuth =
            headers["api-key"] !== undefined ||
            headers["authorization"] !== undefined;
          expect(hasAuth).to.be.true;
        },
      );
    });

    it("should include content-type header in POST requests", () => {
      cy.intercept("POST", "**/payments/session_tokens*").as(
        "fetchSessions",
      );

      cy.createPaymentIntent(secretKey, createPaymentBody).then(() => {
        cy.getGlobalState("clientSecret").then((clientSecret) => {
          cy.visit(getClientURL(clientSecret, publishableKey));
          cy.waitForSDKReady();
        });
      });

      cy.wait("@fetchSessions", { timeout: 15000 }).then((interception) => {
        expect(interception.request.headers["content-type"]).to.include(
          "application/json",
        );
      });
    });
  });

  describe("Payment Methods List Response Handling", () => {
    it("should handle empty payment methods list gracefully", () => {
      cy.intercept("GET", "**/account/payment_methods*", {
        statusCode: 200,
        body: {
          redirect_url: "",
          payment_methods: [],
        },
      }).as("emptyPaymentMethods");

      cy.createPaymentIntent(secretKey, createPaymentBody).then(() => {
        cy.getGlobalState("clientSecret").then((clientSecret) => {
          cy.visit(getClientURL(clientSecret, publishableKey));
        });
      });

      cy.wait("@emptyPaymentMethods", { timeout: 15000 });

      // SDK should still load without crashing
      cy.iframe(iframeSelector).should("exist");
    });

    it("should handle payment methods API server error gracefully", () => {
      cy.intercept("GET", "**/account/payment_methods*", {
        statusCode: 500,
        body: {
          error: {
            type: "internal_server_error",
            message: "Something went wrong",
          },
        },
      }).as("paymentMethodsError");

      cy.createPaymentIntent(secretKey, createPaymentBody).then(() => {
        cy.getGlobalState("clientSecret").then((clientSecret) => {
          cy.visit(getClientURL(clientSecret, publishableKey));
        });
      });

      cy.wait("@paymentMethodsError", { timeout: 15000 });

      // The page should still be accessible (not crashed)
      cy.get("body").should("exist");
    });
  });

  describe("Confirm Payment Error Handling", () => {
    it("should handle declined card response", () => {
      const { cardNo, card_exp_month, card_exp_year, cvc } =
        stripeCards.invalidCard;

      cy.createPaymentIntent(secretKey, createPaymentBody).then(() => {
        cy.getGlobalState("clientSecret").then((clientSecret) => {
          cy.visit(getClientURL(clientSecret, publishableKey));
          cy.waitForSDKReady();
        });
      });

      cy.enterCardDetails({ cardNo, card_exp_month, card_exp_year, cvc });

      cy.get("#submit").click();

      // Payment should fail and show an error message
      cy.get("#payment-message", { timeout: 15000 })
        .should("be.visible")
        .invoke("text")
        .should("not.be.empty");
    });
  });

  describe("Network Error Resilience", () => {
    it("should handle session tokens API failure without crashing", () => {
      cy.intercept("POST", "**/payments/session_tokens*", {
        statusCode: 500,
        body: {
          error: {
            type: "internal_server_error",
            message: "Session tokens unavailable",
          },
        },
      }).as("sessionTokensError");

      cy.createPaymentIntent(secretKey, createPaymentBody).then(() => {
        cy.getGlobalState("clientSecret").then((clientSecret) => {
          cy.visit(getClientURL(clientSecret, publishableKey));
          cy.waitForSDKReady();
        });
      });

      cy.wait("@sessionTokensError", { timeout: 15000 });

      // Card form should still be functional
      getIframeBody()
        .find(`[data-testid=${testIds.cardNoInputTestId}]`)
        .should("be.visible");
    });

    it("should handle customer payment methods API failure gracefully", () => {
      cy.intercept("GET", "**/customers/payment_methods*", {
        statusCode: 500,
        body: {
          error: {
            type: "internal_server_error",
            message: "Customer data unavailable",
          },
        },
      }).as("customerPMsError");

      cy.createPaymentIntent(secretKey, createPaymentBody).then(() => {
        cy.getGlobalState("clientSecret").then((clientSecret) => {
          cy.visit(getClientURL(clientSecret, publishableKey));
          cy.waitForSDKReady();
        });
      });

      cy.wait("@customerPMsError", { timeout: 15000 });

      // Card form should still be functional
      getIframeBody()
        .find(`[data-testid=${testIds.cardNoInputTestId}]`)
        .should("be.visible");
    });

    it("should still allow payment even if session tokens fail", () => {
      cy.intercept("POST", "**/payments/session_tokens*", {
        statusCode: 500,
        body: { error: { message: "Session tokens unavailable" } },
      }).as("sessionTokensError");

      cy.createPaymentIntent(secretKey, createPaymentBody).then(() => {
        cy.getGlobalState("clientSecret").then((clientSecret) => {
          cy.visit(getClientURL(clientSecret, publishableKey));
          cy.waitForSDKReady();
        });
      });

      const { cardNo, card_exp_month, card_exp_year, cvc } =
        stripeCards.successCard;

      cy.enterCardDetails({ cardNo, card_exp_month, card_exp_year, cvc });

      cy.get("#submit").click();

      cy.contains("Thanks for your order!", { timeout: 15000 }).should(
        "be.visible",
      );
    });
  });

  describe("Slow Response Handling", () => {
    it("should handle slow payment methods response", () => {
      cy.intercept("GET", "**/account/payment_methods*", (req) => {
        req.on("response", (res) => {
          res.setDelay(3000);
        });
      }).as("slowPaymentMethods");

      cy.createPaymentIntent(secretKey, createPaymentBody).then(() => {
        cy.getGlobalState("clientSecret").then((clientSecret) => {
          cy.visit(getClientURL(clientSecret, publishableKey));
        });
      });

      cy.wait("@slowPaymentMethods", { timeout: 20000 });

      // After the slow response, the SDK should still render correctly
      cy.waitForSDKReady();
      getIframeBody()
        .find(`[data-testid=${testIds.cardNoInputTestId}]`)
        .should("be.visible");
    });
  });

  describe("Confirm Payment Response", () => {
    it("should receive a successful response from confirm endpoint", () => {
      cy.intercept("POST", "**/payments/*/confirm*").as("confirmPayment");

      cy.createPaymentIntent(secretKey, createPaymentBody).then(() => {
        cy.getGlobalState("clientSecret").then((clientSecret) => {
          cy.visit(getClientURL(clientSecret, publishableKey));
          cy.waitForSDKReady();
        });
      });

      const { cardNo, card_exp_month, card_exp_year, cvc } =
        stripeCards.successCard;

      cy.enterCardDetails({ cardNo, card_exp_month, card_exp_year, cvc });

      cy.get("#submit").click();

      // Verify the confirm call returns a successful status
      cy.wait("@confirmPayment", { timeout: 15000 }).then((interception) => {
        expect(interception.response?.statusCode).to.be.oneOf([200, 303]);
      });
    });
  });
});
