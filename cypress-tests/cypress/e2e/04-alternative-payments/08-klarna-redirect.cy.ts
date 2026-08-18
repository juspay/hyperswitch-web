import {
  changeObjectKeyValue,
  connectorEnum,
  connectorProfileIdMapping,
  createPaymentBody,
  getClientURL,
} from "../../support/utils";

describe("Klarna redirect payment flow", () => {
  let publishableKey: string;
  let secretKey: string;
  let getIframeBody: () => Cypress.Chainable<JQuery<HTMLBodyElement>>;
  const iframeSelector =
    "#orca-payment-element-iframeRef-orca-elements-payment-element-payment-element";

  const configureKlarnaPayment = () => {
    const stripeProfileId = connectorProfileIdMapping.get(connectorEnum.STRIPE);
    if (!stripeProfileId) {
      return null;
    }

    changeObjectKeyValue(createPaymentBody, "profile_id", stripeProfileId);
    changeObjectKeyValue(createPaymentBody, "currency", "USD");
    createPaymentBody.billing.address.country = "US";
    createPaymentBody.billing.address.state = "NY";
    createPaymentBody.billing.address.city = "New York";
    createPaymentBody.billing.address.zip = "10001";
    createPaymentBody.shipping.address.country = "US";
    createPaymentBody.shipping.address.state = "NY";
    createPaymentBody.shipping.address.city = "New York";
    createPaymentBody.shipping.address.zip = "10001";
    (createPaymentBody.order_details[0] as any).tax_rate = 1900;
    (createPaymentBody.order_details[0] as any).total_tax_amount = 479;

    return stripeProfileId;
  };

  const setupPaymentIntent = () => {
    publishableKey = Cypress.env("HYPERSWITCH_PUBLISHABLE_KEY");
    secretKey = Cypress.env("HYPERSWITCH_SECRET_KEY");
    getIframeBody = () => cy.iframe(iframeSelector);
    cy.createPaymentIntent(secretKey, createPaymentBody).then(() => {
      cy.getGlobalState("clientSecret").then((clientSecret) => {
        cy.visit(getClientURL(clientSecret, publishableKey));
      });
    });
  };

  it("should complete Klarna redirect flow with email", function () {
    const stripeProfileId = configureKlarnaPayment();
    if (!stripeProfileId) {
      Cypress.log({
        name: "skip",
        message: "Stripe was not provisioned. Cannot run Klarna test.",
      });
      this.skip();
      return;
    }

    createPaymentBody.email = "hyperswitch_sdk_demo_id@gmail.com";
    createPaymentBody.billing.email = "hyperswitch_sdk_demo_id@gmail.com";

    setupPaymentIntent();

    cy.intercept("POST", "**/payments/*/confirm").as("confirmKlarna");
    cy.get(iframeSelector).should("be.visible");

    cy.selectPaymentMethodOrSkip(getIframeBody, "Klarna").then((skipped) => {
      if (skipped) {
        this.skip();
      }

      getIframeBody().get("#submit").click();

      cy.wait("@confirmKlarna").then(({ request, response }) => {
        const requestBody =
          typeof request.body === "string"
            ? JSON.parse(request.body)
            : request.body;

        expect(requestBody.payment_method).to.eq("pay_later");
        expect(requestBody.payment_method_type).to.eq("klarna");
        expect(requestBody.payment_experience).to.eq("redirect_to_url");
        expect(requestBody.payment_method_data?.pay_later).to.be.an("object");
        expect(response?.statusCode).to.eq(200);
        expect(response?.body.next_action?.redirect_to_url).to.be.a("string");
      });

      // Verify redirect to Klarna
      cy.url({ timeout: 30000 }).should("include", "klarna");

      // Wait for the Klarna page to render (heavy JS SPA)
      cy.wait(5000);
      cy.document({ timeout: 30000 }).its("readyState").should("eq", "complete");
      cy.get("body").should("not.be.empty");
      cy.get("body", { timeout: 30000 }).invoke("text").should("not.be.empty");

      cy.log("Klarna page rendered successfully");
    });
  });
});
