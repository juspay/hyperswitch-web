import * as testIds from "../../src/Utilities/TestUtils.bs";
describe("klarna payment flow test", () => {
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
  it("klarna payment flow successful", () => {
    let iframeSelector =
      "#orca-payment-element-iframeRef-orca-elements-payment-element-payment-element";

    cy.reload(true);
    cy.frameLoaded(iframeSelector);
    cy.wait(2000);

    cy.iframe(iframeSelector)
      .find("[data-testid=paymentList]")
      .should("be.visible")
      .contains(paymentMethodsData.klarna)
      .click();

    const enterValueInIframe = (selector, value) => {
      cy.iframe(iframeSelector).find(selector).should("be.visible").type(value);
    };

    const selectValueInIframe = (selector, value) => {
      cy.iframe(iframeSelector)
        .find(selector)
        .should("be.visible")
        .select(value);
    };

    enterValueInIframe(
      `[data-testid=${testIds.fullNameInputTestId}]`,
      customerData.cardHolderName
    );
    // enterValueInIframe(
    //   `[data-testid=${testIds.emailInputTestId}]`,
    //   customerData.email
    // );
    selectValueInIframe(
      `[data-testid=${testIds.countryDropDownTestId}]`,
      customerData.country
    );

    cy.get("#submit").click();

    cy.url().should("include", "sandbox.hyperswitch");
  });
});
