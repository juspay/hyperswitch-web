import * as testIds from "../../../src/Utilities/TestUtils.bs";
import { getClientURL } from "../support/utils";
import { createPaymentBody } from "../support/utils";
import {
  changeObjectKeyValue,
  connectorProfileIdMapping,
  connectorEnum,
} from "../support/utils";
import { stripeCards } from "cypress/support/cards";

describe("Card payment flow test", () => {
  const publishableKey = Cypress.env("HYPERSWITCH_PUBLISHABLE_KEY");
  const secretKey = Cypress.env("HYPERSWITCH_SECRET_KEY");
  let getIframeBody: () => Cypress.Chainable<JQuery<HTMLBodyElement>>;
  let iframeSelector =
    "#orca-payment-element-iframeRef-orca-elements-payment-element-payment-element";
  changeObjectKeyValue(
    createPaymentBody,
    "profile_id",
    connectorProfileIdMapping.get(connectorEnum.MIFINITY),
  );
  changeObjectKeyValue(createPaymentBody, "currency", "EUR");
  changeObjectKeyValue(createPaymentBody, "billing", {
    address: {
      line1: "1467",
      line2: "Harrison Street",
      line3: "Harrison Street",
      city: "San Fransico",
      state: "California",
      zip: "94122",
      country: "DE",
      first_name: "joseph",
      last_name: "Doe",
    },
    phone: {
      number: "8056594427",
      country_code: "+91",
    },
  });

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

  it("should fail if age is less than 18", () => {
    cy.wait(2000);
    getIframeBody().find(`[data-testid=${testIds.addNewCardIcon}]`).click();
    getIframeBody().contains("div", "Mifinity").click();
    const today = new Date();
    const formattedDate = `${String(today.getDate()).padStart(2, "0")}-${String(
      today.getMonth() + 1,
    ).padStart(2, "0")}-${today.getFullYear()}`;
    getIframeBody()
      .find(`input[placeholder="${testIds.datePickerPlaceHolderText}"]`)
      .type(formattedDate);
    getIframeBody().get("#submit").click();

    getIframeBody()
      .find(".Error.pt-1")
      .should("be.visible")
      .and("contain.text", "Age should be greater than or equal to 18 years");
  });

  it("should complete the mifinity payment successfully", () => {
    cy.wait(2000);
    getIframeBody().find(`[data-testid=${testIds.addNewCardIcon}]`).click();
    getIframeBody().contains("div", "Mifinity").click();
    getIframeBody()
      .find(`input[placeholder="${testIds.datePickerPlaceHolderText}"]`)
      .type("30-04-2000");
    getIframeBody()
      .get("#submit")
      .click()
      .then(() => {
        cy.url().should("include", "api/payments/redirect");
        cy.wait(4000);
        cy.get("iframe")
          .should("have.attr", "src")
          .and("match", /^https:\/\/demo\.mifinity\.com\/iframe2\//);
      });
  });
});
