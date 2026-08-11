import {
  changeObjectKeyValue,
  connectorEnum,
  connectorProfileIdMapping,
  createPaymentBody,
  getClientURL,
} from "../../support/utils";

describe("Fiuu DuitNow payment flow", () => {
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
    createPaymentBody.shipping.address.country = "MY";

    getIframeBody = () => cy.iframe(iframeSelector);
    cy.createPaymentIntent(secretKey, createPaymentBody).then(() => {
      cy.getGlobalState("clientSecret").then((clientSecret) => {
        cy.visit(getClientURL(clientSecret, publishableKey));
      });
    });
  });

  it("should display the DuitNow QR code through Fiuu", function () {
    cy.get(iframeSelector).should("be.visible");

    cy.selectPaymentMethodOrSkip(getIframeBody, "DuitNow").then((skipped) => {
      if (skipped) {
        this.skip();
      }

      getIframeBody().get("#submit").click();

      cy.wait(5000);

      cy.get("#orca-fullscreen", { timeout: 30000 }).should("be.visible");
      cy.frameLoaded("#orca-fullscreen");
      cy.iframe("#orca-fullscreen")
        .find("img", { timeout: 30000 })
        .should("be.visible")
        .and("have.attr", "src")
        .and("not.be.empty");
      cy.iframe("#orca-fullscreen")
        .contains("MALAYSIA NATIONAL QR", { timeout: 30000 })
        .should("be.visible");
    });
  });

  it("should reject an invalid DuitNow QR payment variant", function () {
    cy.intercept("POST", "**/payments/*/confirm", (request) => {
      const body =
        typeof request.body === "string"
          ? JSON.parse(request.body)
          : request.body;
      const realTimePayment = body.payment_method_data?.real_time_payment;

      if (realTimePayment?.duit_now) {
        realTimePayment.duit_now_qr = realTimePayment.duit_now;
        delete realTimePayment.duit_now;
        request.body = body;
      }
    }).as("confirmInvalidDuitNow");

    cy.get(iframeSelector).should("be.visible");

    cy.selectPaymentMethodOrSkip(getIframeBody, "DuitNow").then((skipped) => {
      if (skipped) {
        this.skip();
      }

      getIframeBody().get("#submit").click();

      cy.wait("@confirmInvalidDuitNow").then(({ request, response }) => {
        expect(
          request.body.payment_method_data.real_time_payment,
        ).to.have.property("duit_now_qr");
        expect(response?.statusCode).to.eq(400);
      });

      cy.contains("Json deserialize error: unknown variant", {
        timeout: 15000,
      }).should("be.visible");
      cy.get("#orca-fullscreen").should("not.exist");
    });
  });
});
