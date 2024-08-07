import * as testIds from "../../src/Utilities/TestUtils.bs";
describe("Card payment flow test", () => {
  let customerData;
  let publishableKey = "pk_snd_3b33cd9404234113804aa1accaabe22f";
  beforeEach(() => {
    cy.visit("http://localhost:9060");

    cy.hardReload();

    cy.fixture("testCustomer").then((customer) => {
      customerData = customer;
    });
  });
  it("page loaded successfully", () => {
    cy.visit("http://localhost:9060");
  });
  it("title rendered correctly", () => {
    cy.contains("Hyperswitch Unified Checkout").should("be.visible");
  });

  it("orca-payment-element iframe loaded", () => {
    cy.get(
      "#orca-payment-element-iframeRef-orca-elements-payment-element-payment-element"
    )
      .should("be.visible")
      .its("0.contentDocument")
      .its("body");
  });

  it("card payment flow successful", () => {
    let iframeSelector =
      "#orca-payment-element-iframeRef-orca-elements-payment-element-payment-element";
    // cy.wait(1000);
    // cy.frameLoaded(iframeSelector);
    // cy.wait(1000);

    cy.visit("http://localhost:9060");

    cy.frameLoaded(iframeSelector);
    cy.wait(4000);

    cy.iframe(iframeSelector)
      .find(`[data-testid=${testIds.addNewCardIcon}]`)
      .should("be.visible")
      .click();

    cy.testDynamicFields(customerData, ["email"], true);
    cy.get("#submit").click();

    // it("orca-payment-element iframe loaded", () => {
    //     cy.get(
    //       "#__privateStripeFrame7904"
    //     )
    //       .should("be.visible")
    //       .its("0.contentDocument")
    //       .its("body");
    //   });
    // cy.contains("Thanks for your order!").should("be.visible");
  });
});
