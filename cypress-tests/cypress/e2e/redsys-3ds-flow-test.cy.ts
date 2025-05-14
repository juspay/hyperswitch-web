import {
  getClientURL,
  createPaymentBody,
  changeObjectKeyValue,
  connectorProfileIdMapping,
  connectorEnum,
} from "../support/utils";
import { redsysCards } from "cypress/support/cards";
import * as testIds from "../../../src/Utilities/TestUtils.bs";

type updatesType = [Record<string, any>, string, string | boolean][];

describe("External 3DS using Redsys flow test", () => {
  let getIframeBody: () => Cypress.Chainable<JQuery<HTMLBodyElement>>;
  const publishableKey = Cypress.env("HYPERSWITCH_PUBLISHABLE_KEY");
  const secretKey = Cypress.env("HYPERSWITCH_SECRET_KEY");
  const iframeSelector =
    "#orca-payment-element-iframeRef-orca-elements-payment-element-payment-element";

  const shippingAddressBody = createPaymentBody.shipping.address;
  const billingAddressBody = createPaymentBody.billing.address;

  const updates: updatesType = [
    [
      createPaymentBody,
      "profile_id",
      connectorProfileIdMapping.get(connectorEnum.REDSYS),
    ],
    [createPaymentBody, "request_external_three_ds_authentication", true],
    [createPaymentBody, "authentication_type", "three_ds"],
    [createPaymentBody, "currency", "EUR"],
    [shippingAddressBody, "state", "Ceuta"],
    [shippingAddressBody, "country", "ES"],
    [billingAddressBody, "state", "Ceuta"],
    [billingAddressBody, "country", "ES"],
  ];

  updates.forEach(([obj, key, value]) => {
    changeObjectKeyValue(obj, key, value);
  });

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

  const openDirectChallengeAndTest = (checkboxOrder : string, testType : string) => {
    cy.wait(2000);
    getIframeBody().find(`[data-testid=${testIds.addNewCardIcon}]`).click();
    enterCardDetails(redsysCards.challengeTestCard);
    handleRedsysIframeError();
    getIframeBody().get("#submit").click();
    cy.wait(6000);
    cy.url().should("include", "sis-d.redsys.es");
    cy.get(`input[type="radio"][value=${checkboxOrder}]`).check();
    cy.get("input[id=boton][value=Enviar]").click();
    if (testType === "success") {
      cy.contains("Thanks for your order!").should("be.visible");
    } else {
      cy.contains("Payment failed. Please check your payment method.").should(
        "be.visible"
      );
    }
  };

  beforeEach(() => {
    getIframeBody = () => cy.iframe(iframeSelector);

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

  it("should open redsys authentication page", () => {
    cy.wait(2000);
    getIframeBody().find(`[data-testid=${testIds.addNewCardIcon}]`).click();
    enterCardDetails(redsysCards.threedsInvokeChallengeTestCard);
    getIframeBody().get("#submit").click();

    handleRedsysIframeError();
    cy.wait(16000);
    cy.url().should("include", "sis-d.redsys.es");
  });

  it("Redsys 3ds frictionless flow test", () => {
    cy.wait(2000);
    getIframeBody().find(`[data-testid=${testIds.addNewCardIcon}]`).click();
    enterCardDetails(redsysCards.threedsInvokeFrictionlessTestCard);
    getIframeBody().get("#submit").click();
    cy.wait(16000);
    cy.contains("Thanks for your order!").should("be.visible");
  });

  it("No 3ds invoke: challenge flow - success case", () => openDirectChallengeAndTest("1", "success"));

  it("No 3ds invoke: challenge flow - failure case", () => openDirectChallengeAndTest("2", "failure"));

  it("No 3ds invoke: challenge flow - cancel case", () => openDirectChallengeAndTest("3", "cancel"));

  it("No 3ds invoke frictionless flow test", () => {
    cy.wait(2000);
    getIframeBody().find(`[data-testid=${testIds.addNewCardIcon}]`).click();
    enterCardDetails(redsysCards.frictionlessTestCard);
    getIframeBody().get("#submit").click();
    cy.contains("Thanks for your order!").should("be.visible");
  });
});
