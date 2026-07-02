import {
  getClientURL,
  createPaymentBody,
  changeObjectKeyValue,
  connectorProfileIdMapping,
  connectorEnum,
} from "../../support/utils";
import { redsysCards } from "../../support/cards";
import * as testIds from "../../../../src/Utilities/TestUtils.bs";

type updatesType = [Record<string, any>, string, string | boolean][];

describe("External 3DS using Redsys flow test", () => {
  let getIframeBody: () => Cypress.Chainable<JQuery<HTMLBodyElement>>;
  let publishableKey: string;
  let secretKey: string;
  const iframeSelector =
    "#orca-payment-element-iframeRef-orca-elements-payment-element-payment-element";

  const shippingAddressBody = createPaymentBody.shipping.address;
  const billingAddressBody = createPaymentBody.billing.address;

  const enterCardDetails = ({ cardNo, cvc, card_exp_month, card_exp_year }) => {
    getIframeBody().find("[data-testid=cardNoInput]").type(cardNo);
    getIframeBody().find("[data-testid=expiryInput]").type(card_exp_month);
    getIframeBody().find("[data-testid=expiryInput]").type(card_exp_year);
    getIframeBody().find("[data-testid=cvvInput]").type(cvc);
  };

  const handleRedsysIframeError = () => {
    cy.origin("https://sis-d.redsys.es", () => {
      cy.on("uncaught:exception", (err) => {
        if (err.message.includes("$ is not defined")) {
          return false;
        }
      });
    });
  };

  beforeEach(() => {
    publishableKey = Cypress.env("HYPERSWITCH_PUBLISHABLE_KEY");
    secretKey = Cypress.env("HYPERSWITCH_SECRET_KEY");
    getIframeBody = () => cy.iframe(iframeSelector);

    changeObjectKeyValue(
      createPaymentBody,
      "profile_id",
      connectorProfileIdMapping.get(connectorEnum.REDSYS),
    );
    changeObjectKeyValue(
      createPaymentBody,
      "request_external_three_ds_authentication",
      true,
    );
    changeObjectKeyValue(createPaymentBody, "authentication_type", "three_ds");
    changeObjectKeyValue(createPaymentBody, "currency", "EUR");
    changeObjectKeyValue(shippingAddressBody, "state", "Ceuta");
    changeObjectKeyValue(shippingAddressBody, "country", "ES");
    changeObjectKeyValue(billingAddressBody, "state", "Ceuta");
    changeObjectKeyValue(billingAddressBody, "country", "ES");

    cy.createPaymentIntent(secretKey, createPaymentBody).then(() => {
      cy.getGlobalState("clientSecret").then((clientSecret) => {
        cy.visit(getClientURL(clientSecret, publishableKey));
      });
    });
  });

  it("title rendered correctly", () => {
    cy.contains("Hyperswitch Unified Checkout").should("be.visible");
  });

  it("orca-payment-element iframe loaded", () => {
    cy.get(iframeSelector)
      .should("be.visible")
      .its("0.contentDocument")
      .its("body");
  });

  it("3ds invoke: challenge test", function () {
    cy.wait(2000);
    cy.selectPaymentMethodOrSkip(getIframeBody, "Card").then((skipped) => {
      if (skipped) {
        this.skip();
      }
      enterCardDetails(redsysCards.threedsInvokeChallengeTestCard);
      getIframeBody().get("#submit").click();

      handleRedsysIframeError();
      cy.url({ timeout: 20000 }).should("include", "sis-d.redsys.es");
    });
  });

  it("3ds invoke: frictionless flow", function () {
    cy.wait(2000);
    cy.selectPaymentMethodOrSkip(getIframeBody, "Card").then((skipped) => {
      if (skipped) {
        this.skip();
      }
      enterCardDetails(redsysCards.threedsInvokeFrictionlessTestCard);
      getIframeBody().get("#submit").click();
      cy.contains("Thanks for your order!", { timeout: 16000 }).should(
        "be.visible",
      );
    });
  });

  it("No 3ds invoke: challenge flow", function () {
    cy.wait(2000);
    cy.selectPaymentMethodOrSkip(getIframeBody, "Card").then((skipped) => {
      if (skipped) {
        this.skip();
      }
      enterCardDetails(redsysCards.challengeTestCard);
      handleRedsysIframeError();
      getIframeBody().get("#submit").click();
      cy.url({ timeout: 10000 }).should("include", "sis-d.redsys.es");
    });
  });

  it("No 3ds invoke: frictionless flow", function () {
    cy.wait(2000);
    cy.selectPaymentMethodOrSkip(getIframeBody, "Card").then((skipped) => {
      if (skipped) {
        this.skip();
      }
      enterCardDetails(redsysCards.frictionlessTestCard);
      getIframeBody().get("#submit").click();
      cy.contains("Thanks for your order!", { timeout: 10000 }).should(
        "be.visible",
      );
    });
  });
});
