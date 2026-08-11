import {
  changeObjectKeyValue,
  connectorEnum,
  connectorProfileIdMapping,
  createPaymentBody,
  getClientURL,
} from "../../support/utils";

describe("Trustpay SEPA Bank Transfer payment flow", () => {
  let publishableKey: string;
  let secretKey: string;
  let getIframeBody: () => Cypress.Chainable<JQuery<HTMLBodyElement>>;
  const iframeSelector =
    "#orca-payment-element-iframeRef-orca-elements-payment-element-payment-element";

  beforeEach(() => {
    publishableKey = Cypress.env("HYPERSWITCH_PUBLISHABLE_KEY");
    secretKey = Cypress.env("HYPERSWITCH_SECRET_KEY");

    const trustpayProfileId = connectorProfileIdMapping.get(
      connectorEnum.TRUSTPAY,
    );
    assert.ok(
      trustpayProfileId,
      "Trustpay connector credentials are missing from creds.json — " +
        "connector was not provisioned. Add trustpay to creds.json to run this test.",
    );

    changeObjectKeyValue(createPaymentBody, "profile_id", trustpayProfileId);
    changeObjectKeyValue(createPaymentBody, "currency", "EUR");
    changeObjectKeyValue(createPaymentBody, "email", "test@example.com");
    createPaymentBody.billing.address.country = "DE";
    createPaymentBody.billing.address.state = "Berlin";
    createPaymentBody.billing.address.line1 = "123 Test Street";
    createPaymentBody.billing.address.city = "Berlin";
    createPaymentBody.billing.address.zip = "10115";
    createPaymentBody.shipping.address.country = "DE";
    createPaymentBody.shipping.address.state = "Berlin";

    getIframeBody = () => cy.iframe(iframeSelector);
    cy.createPaymentIntent(secretKey, createPaymentBody).then(() => {
      cy.getGlobalState("clientSecret").then((clientSecret) => {
        cy.visit(getClientURL(clientSecret, publishableKey));
      });
    });
  });

  it("should redirect a SEPA Bank Transfer through Trustpay", function () {
    cy.intercept("POST", "**/payments/*/confirm").as("confirmSepaTransfer");
    cy.get(iframeSelector).should("be.visible");

    cy.selectPaymentMethodOrSkip(getIframeBody, "SEPA Bank Transfer").then(
      (skipped) => {
        if (skipped) {
          this.skip();
        }

        // Wait for the SepaBankTransferLazy component to fully mount before clicking.
        // The info text signals the lazy chunk is loaded and the submit listener is registered.
        getIframeBody()
          .contains("After submitting these details", { timeout: 15000 })
          .should("be.visible");

        getIframeBody().get("#submit").click();

        cy.wait("@confirmSepaTransfer", { timeout: 30000 }).then(({ request, response }) => {
          const requestBody =
            typeof request.body === "string"
              ? JSON.parse(request.body)
              : request.body;

          expect(requestBody.payment_method).to.eq("bank_transfer");
          expect(requestBody.payment_method_type).to.eq("sepa_bank_transfer");
          expect(
            requestBody.payment_method_data?.bank_transfer?.sepa_bank_transfer,
          ).to.deep.eq({});
          expect(response?.statusCode).to.eq(200);
          expect(response?.body.next_action?.type).to.be.oneOf([
            "redirect_to_url",
            "display_bank_transfer_information",
          ]);
        });
      },
    );
  });
});
