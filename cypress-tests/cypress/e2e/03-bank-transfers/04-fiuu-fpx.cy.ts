import {
  changeObjectKeyValue,
  connectorEnum,
  connectorProfileIdMapping,
  createPaymentBody,
  getClientURL,
} from "../../support/utils";

describe("Fiuu Online Banking FPX payment flow", () => {
  let publishableKey: string;
  let secretKey: string;
  let getIframeBody: () => Cypress.Chainable<JQuery<HTMLBodyElement>>;
  const iframeSelector =
    "#orca-payment-element-iframeRef-orca-elements-payment-element-payment-element";

  beforeEach(function () {
    publishableKey = Cypress.env("HYPERSWITCH_PUBLISHABLE_KEY");
    secretKey = Cypress.env("HYPERSWITCH_SECRET_KEY");

    const fiuuProfileId = connectorProfileIdMapping.get(connectorEnum.FIUU);
    if (!fiuuProfileId) {
      this.skip();
      return;
    }

    changeObjectKeyValue(createPaymentBody, "profile_id", fiuuProfileId);
    changeObjectKeyValue(createPaymentBody, "currency", "MYR");
    createPaymentBody.billing.address.country = "MY";
    createPaymentBody.billing.address.state = "Kuala Lumpur";
    createPaymentBody.shipping.address.country = "MY";
    createPaymentBody.shipping.address.state = "Kuala Lumpur";

    getIframeBody = () => cy.iframe(iframeSelector);
    cy.createPaymentIntent(secretKey, createPaymentBody).then(() => {
      cy.getGlobalState("clientSecret").then((clientSecret) => {
        cy.visit(getClientURL(clientSecret, publishableKey));
      });
    });
  });

  it("should redirect an FPX payment through Fiuu", function () {
    cy.intercept("POST", "**/payments/*/confirm").as("confirmFpx");
    cy.get(iframeSelector).should("be.visible");

    cy.selectPaymentMethodOrSkip(getIframeBody, "Online Banking Fpx").then(
      (skipped) => {
        if (skipped) {
          this.skip();
        }

        getIframeBody().get("#submit").click();

        cy.wait("@confirmFpx").then(({ request, response }) => {
          const requestBody =
            typeof request.body === "string"
              ? JSON.parse(request.body)
              : request.body;

          expect(requestBody.payment_method).to.eq("bank_redirect");
          expect(requestBody.payment_method_type).to.eq("online_banking_fpx");
          expect(response?.statusCode).to.eq(200);
          expect(response?.body.next_action?.redirect_to_url).to.be.a("string");
        });

        cy.url({ timeout: 30000 }).should("not.include", "localhost:9060");
        cy.document({ timeout: 30000 })
          .its("readyState")
          .should("eq", "complete");
        cy.get("body").invoke("text").should("not.be.empty");
        cy.url().then((currentUrl) => {
          expect(currentUrl).to.not.eq("http://localhost:9060/");
        });
      },
    );
  });
});
