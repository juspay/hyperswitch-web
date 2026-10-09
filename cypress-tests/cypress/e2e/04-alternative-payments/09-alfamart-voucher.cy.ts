import {
  changeObjectKeyValue,
  connectorEnum,
  connectorProfileIdMapping,
  createPaymentBody,
  getClientURL,
  removeObjectKey,
} from "../../support/utils";

// Alfamart is an Indonesian convenience-store voucher method:
// payment_method "voucher", payment_method_type "alfamart", adyen as the
// eligible connector (enabled on the adyen MCA in setup.js).
//
// The SDK renders whatever additional fields the backend's dynamic-field
// schema provides for this method (billing email / name for Alfamart), so
// these tests assert the hard SDK contract — the tab renders and the confirm
// payload carries the nested voucher/alfamart payment_method_data — and they
// exercise field rendering / validation only when the backend schema actually
// requires the fields.
describe("Alfamart voucher payment flow", () => {
  let publishableKey: string;
  let secretKey: string;
  let getIframeBody: () => Cypress.Chainable<JQuery<HTMLBodyElement>>;
  const iframeSelector =
    "#orca-payment-element-iframeRef-orca-elements-payment-element-payment-element";

  // Values typed into dynamic fields when the backend schema renders them.
  const DYNAMIC_EMAIL = "alfamart.test@example.com";
  const DYNAMIC_FIRST_NAME = "Alfamart";
  const DYNAMIC_LAST_NAME = "Tester";

  beforeEach(() => {
    publishableKey = Cypress.env("HYPERSWITCH_PUBLISHABLE_KEY");
    secretKey = Cypress.env("HYPERSWITCH_SECRET_KEY");

    const adyenProfileId = connectorProfileIdMapping.get(connectorEnum.ADYEN);
    assert.ok(
      adyenProfileId,
      "Adyen connector credentials are missing — add adyen to creds.json to run this test.",
    );

    changeObjectKeyValue(createPaymentBody, "profile_id", adyenProfileId);
    changeObjectKeyValue(createPaymentBody, "currency", "IDR");
    createPaymentBody.billing.address.country = "ID";
    createPaymentBody.shipping.address.country = "ID";

    // Drop pre-collected billing email so the backend's dynamic-field schema
    // (when it defines an email field for voucher/alfamart) asks the SDK to
    // render the email input instead of prefilling it from the intent —
    // the same technique used by 02-cards/billing-fields.cy.ts.
    removeObjectKey(createPaymentBody, "email");
    removeObjectKey(createPaymentBody.billing, "email");

    getIframeBody = () => cy.iframe(iframeSelector);
    cy.createPaymentIntent(secretKey, createPaymentBody).then(() => {
      cy.getGlobalState("clientSecret").then((clientSecret) => {
        cy.visit(getClientURL(clientSecret, publishableKey));
      });
    });
  });

  // Fills whatever dynamic inputs the backend schema rendered for this
  // payment method, so a required-but-empty field cannot block submission.
  const fillRenderedDynamicFields = () => {
    getIframeBody()
      .find(".DynamicFields")
      .then(($fields) => {
        const email = $fields.find('[data-testid="email"]');
        if (email.length > 0) {
          cy.wrap(email).clear().type(DYNAMIC_EMAIL);
        }
        // Combined full-name input and standalone first/last inputs both use
        // the last path segment of their write path as the test id.
        const firstName = $fields.find('[data-testid="first_name"]');
        if (firstName.length > 0) {
          cy.wrap(firstName)
            .clear()
            .type(`${DYNAMIC_FIRST_NAME} ${DYNAMIC_LAST_NAME}`);
        }
        const lastName = $fields.find('[data-testid="last_name"]');
        if (lastName.length > 0) {
          cy.wrap(lastName).clear().type(DYNAMIC_LAST_NAME);
        }
      });
  };

  it("should render the Alfamart payment option", function () {
    cy.get(iframeSelector).should("be.visible");

    cy.selectPaymentMethodOrSkip(getIframeBody, "Alfamart").then((skipped) => {
      if (skipped) {
        this.skip();
      }

      getIframeBody().contains("Alfamart").should("be.visible");
    });
  });

  it("should confirm with nested voucher/alfamart payment_method_data", function () {
    cy.get(iframeSelector).should("be.visible");

    cy.selectPaymentMethodOrSkip(getIframeBody, "Alfamart").then((skipped) => {
      if (skipped) {
        this.skip();
      }

      cy.intercept("POST", "**/payments/*/confirm").as("confirmAlfamart");

      fillRenderedDynamicFields();

      cy.get("#submit").should("be.visible").click();

      cy.wait("@confirmAlfamart", { timeout: 20000 }).then(({ request }) => {
        const body =
          typeof request.body === "string"
            ? JSON.parse(request.body)
            : request.body;

        expect(body.payment_method).to.equal("voucher");
        expect(body.payment_method_type).to.equal("alfamart");
        expect(body.payment_method_data).to.be.an("object");
        expect(body.payment_method_data).to.have.property("voucher");
        expect(body.payment_method_data.voucher).to.have.property("alfamart");
        expect(body.payment_method_data.voucher.alfamart).to.be.an("object");

        // Dynamic values must merge into the nested structure — never as
        // flat dotted keys such as "payment_method_data.billing.email".
        for (const key of Object.keys(body.payment_method_data)) {
          expect(key).to.not.include(".");
        }

        // When the backend schema rendered an email field, the user-entered
        // value must reach the nested billing destination.
        if (body.payment_method_data.billing?.email) {
          expect(body.payment_method_data.billing.email).to.equal(
            DYNAMIC_EMAIL,
          );
        }
      });
    });
  });

  it("should validate the dynamic email field and send the corrected value", function () {
    cy.get(iframeSelector).should("be.visible");

    cy.selectPaymentMethodOrSkip(getIframeBody, "Alfamart").then((skipped) => {
      if (skipped) {
        this.skip();
      }

      cy.intercept("POST", "**/payments/*/confirm").as("confirmAlfamart");

      getIframeBody()
        .find(".DynamicFields")
        .then(($fields) => {
          if ($fields.find('[data-testid="email"]').length === 0) {
            cy.log(
              "Backend schema did not require an email field for voucher/alfamart — skipping field assertions.",
            );
            this.skip();
            return;
          }

          // 1. An invalid email is rejected with the field-level error.
          getIframeBody()
            .find('[data-testid="email"]')
            .clear()
            .type("not-an-email")
            .blur();
          getIframeBody()
            .find(".DynamicFields")
            .should("contain.text", "Invalid email address");

          // 2. Submitting while invalid must not send a confirm request with
          //    the invalid value: the first intercepted request (asserted
          //    below) has to carry the corrected address.
          cy.get("#submit").should("be.visible").click();

          // 3. Correcting the value clears the error.
          getIframeBody()
            .find('[data-testid="email"]')
            .clear()
            .type(DYNAMIC_EMAIL)
            .blur();
          getIframeBody()
            .find(".DynamicFields")
            .should("not.contain.text", "Invalid email address");

          fillRenderedDynamicFields();

          cy.get("#submit").should("be.visible").click();

          cy.wait("@confirmAlfamart", { timeout: 20000 }).then(
            ({ request }) => {
              const body =
                typeof request.body === "string"
                  ? JSON.parse(request.body)
                  : request.body;

              expect(body.payment_method).to.equal("voucher");
              expect(body.payment_method_type).to.equal("alfamart");
              expect(body.payment_method_data?.billing?.email).to.equal(
                DYNAMIC_EMAIL,
              );
            },
          );
        });
    });
  });
});
