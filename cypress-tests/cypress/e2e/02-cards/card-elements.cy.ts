import {
  CLIENT_BASE_URL,
  createPaymentBody,
  changeObjectKeyValue,
} from "../../support/utils";
import { stripeCards } from "../../support/cards";

describe("Card Elements", () => {
  let publishableKey: string;
  let secretKey: string;

  // The harness mounts each element into a <type>-mount div, and the SDK names the
  // iframe after that div.
  const iframeFor = (elementType: string) =>
    `#orca-payment-element-iframeRef-${elementType}-mount`;

  const visitHarness = (...elements: string[]) => {
    const baseUrl =
      (Cypress.env("CLIENT_BASE_URL") as string | undefined) || CLIENT_BASE_URL;
    cy.createPaymentIntent(secretKey, createPaymentBody).then(() => {
      cy.getGlobalState("clientSecret").then((clientSecret) => {
        const query = new URLSearchParams({
          publishableKey,
          clientSecret: clientSecret as unknown as string,
        });
        elements.forEach((element) => query.append("element", element));
        cy.visit(`${baseUrl}/widgets.html?${query.toString()}`);
      });
    });
  };

  // The harness records one row per element event.
  const events = () => cy.get("#events");

  changeObjectKeyValue(
    createPaymentBody,
    "customer_id",
    "card_elements_test_user",
  );

  beforeEach(() => {
    publishableKey = Cypress.env("HYPERSWITCH_PUBLISHABLE_KEY");
    secretKey = Cypress.env("HYPERSWITCH_SECRET_KEY");
  });

  describe("cardNumber / cardExpiry / cardCvc", () => {
    // Skipped: Cypress remaps `parent` inside proxied frames, so the submit path's
    // sibling cross-read resolves to the frame itself and always reads empty.
    it.skip("should confirm a payment from the three individual elements", () => {
      const { cardNo, card_exp_month, card_exp_year, cvc } =
        stripeCards.successCard;
      visitHarness("cardNumber", "cardExpiry", "cardCvc");

      cy.iframe(iframeFor("cardNumber")).find("#card-number").type(cardNo);
      cy.iframe(iframeFor("cardExpiry"))
        .find("#card-expiry")
        .type(`${card_exp_month}${card_exp_year}`);
      cy.iframe(iframeFor("cardCvc")).find("#card-cvc").type(cvc);

      cy.get("#submit").click();

      cy.get("#status", { timeout: 20000 }).should("contain.text", "succeeded");
    });

    it("should expose each field under the id the submit path cross-reads", () => {
      // The cardNumber iframe reads its siblings by these ids, so losing one silently
      // fails validation instead of erroring.
      visitHarness("cardNumber", "cardExpiry", "cardCvc");

      cy.iframe(iframeFor("cardNumber")).find("#card-number").should("exist");
      cy.iframe(iframeFor("cardExpiry")).find("#card-expiry").should("exist");
      cy.iframe(iframeFor("cardCvc")).find("#card-cvc").should("exist");
    });

    it("should emit ready for each element", () => {
      // Only cardCvc used to emit it, which stalled confirmPayment's ready-gate.
      visitHarness("cardNumber", "cardExpiry", "cardCvc");

      ["cardNumber", "cardExpiry", "cardCvc"].forEach((elementType) => {
        events()
          .find("tr")
          .filter(`:contains("${elementType}")`)
          .filter(':contains("ready")')
          .should("exist");
      });
    });
  });

  describe("combined card element", () => {
    it("should emit ready and confirm a payment", () => {
      // This element collects all three fields itself, so it exercises the confirm
      // ready-gate rather than the sibling cross-read.
      const { cardNo, card_exp_month, card_exp_year, cvc } =
        stripeCards.successCard;
      visitHarness("card");

      events()
        .find("tr")
        .filter(':contains("ready")')
        .should("contain.text", "card");

      const cardFrame = () => cy.iframe(iframeFor("card"));
      cardFrame().find('input[autocomplete="cc-number"]').type(cardNo);
      cardFrame()
        .find('input[autocomplete="cc-exp"]')
        .type(`${card_exp_month}${card_exp_year}`);
      cardFrame().find('input[autocomplete="cc-csc"]').type(cvc);

      cy.get("#submit").click();

      cy.get("#status", { timeout: 20000 }).should("contain.text", "succeeded");
    });
  });
});
