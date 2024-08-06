import * as testIds from "../../src/Utilities/TestUtils.bs";
describe("affirm payment flow test", () => {
  let customerData;
  let paymentMethodsData;
  beforeEach(() => {
    cy.visit("http://localhost:9060");

    cy.wrap(
      Cypress.automation("remote:debugger:protocol", {
        command: "Network.clearBrowserCache",
      })
    );

    cy.fixture("testCustomer").then((customer) => {
      customerData = customer;
    });
    cy.fixture("paymentMethods").then((paymentMethods) => {
      paymentMethodsData = paymentMethods;
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
  it("affirm payment flow successful", () => {
    let iframeSelector =
      "#orca-payment-element-iframeRef-orca-elements-payment-element-payment-element";

    cy.frameLoaded(iframeSelector);
    cy.wait(2000);

    cy.iframe(iframeSelector)
      .find(`[data-testid=${testIds.paymentMethodListTestId}]`)
      .should("be.visible")
      .contains(paymentMethodsData.affirm)
      .click();

    cy.get("#submit").click();

    cy.url().should("include", "sandbox.hyperswitch");
  });
});
