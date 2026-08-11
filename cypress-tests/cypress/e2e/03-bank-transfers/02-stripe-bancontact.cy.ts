import {
  changeObjectKeyValue,
  connectorEnum,
  connectorProfileIdMapping,
  createPaymentBody,
  getClientURL,
} from "../../support/utils";

describe("Stripe Bancontact Card payment flow", () => {
  let publishableKey: string;
  let secretKey: string;
  let getIframeBody: () => Cypress.Chainable<JQuery<HTMLBodyElement>>;
  const iframeSelector =
    "#orca-payment-element-iframeRef-orca-elements-payment-element-payment-element";

  beforeEach(function () {
    publishableKey = Cypress.env("HYPERSWITCH_PUBLISHABLE_KEY");
    secretKey = Cypress.env("HYPERSWITCH_SECRET_KEY");

    const stripeProfileId = connectorProfileIdMapping.get(connectorEnum.STRIPE);
    if (!stripeProfileId) {
      this.skip();
      return;
    }

    changeObjectKeyValue(createPaymentBody, "profile_id", stripeProfileId);
    changeObjectKeyValue(createPaymentBody, "currency", "EUR");
    createPaymentBody.billing.address.country = "BE";
    createPaymentBody.billing.address.state = "Brussels";
    createPaymentBody.shipping.address.country = "BE";
    createPaymentBody.shipping.address.state = "Brussels";

    getIframeBody = () => cy.iframe(iframeSelector);
    cy.createPaymentIntent(secretKey, createPaymentBody).then(() => {
      cy.getGlobalState("clientSecret").then((clientSecret) => {
        cy.visit(getClientURL(clientSecret, publishableKey));
      });
    });
  });

  it(
    "should redirect a Bancontact Card payment through Stripe",
    function () {
      cy.intercept("POST", "**/payments/*/confirm").as("confirmBancontact");
      cy.get(iframeSelector).should("be.visible");

      cy.selectPaymentMethodOrSkip(getIframeBody, "Bancontact Card").then(
        (skipped) => {
          if (skipped) {
            this.skip();
          }

          // Bancontact via Stripe is a pure redirect flow. The SDK shows only
          // an InfoElement ("After submitting your order, you will be redirected...")
          // — no form inputs. This message is rendered by CardBusinessFields inside
          // ParentCardComponent, and only appears once the inner paymentMethodsSDK
          // iframe loads and sets hasCardFieldStatus=true. Wait for it before
          // submitting; otherwise outerValid check fails silently.
          getIframeBody()
            .contains(
              "After submitting your order, you will be redirected",
              { timeout: 15000 },
            )
            .should("be.visible");

          getIframeBody().get("#submit").click();

          cy.wait("@confirmBancontact").then(({ request, response }) => {
            const requestBody =
              typeof request.body === "string"
                ? JSON.parse(request.body)
                : request.body;

            expect(requestBody.payment_method).to.eq("bank_redirect");
            expect(requestBody.payment_method_type).to.eq("bancontact_card");
            expect(
              requestBody.payment_method_data?.bank_redirect?.bancontact_card,
            ).to.deep.eq({});
            expect(response?.statusCode).to.eq(200);
            expect(response?.body.next_action?.redirect_to_url).to.be.a(
              "string",
            );
          });

          cy.url({ timeout: 30000 }).should("not.include", "localhost:9060");
        },
      );
    },
  );
});
