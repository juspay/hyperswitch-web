// NOTE: this test is for we chat QR flow, please ensure we chat is enabled in stripe connector on dashboard
describe("We Chat payment flow test", () => {
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
  it("WeChat pay payment flow successful", () => {
    let iframeSelector =
      "#orca-payment-element-iframeRef-orca-elements-payment-element-payment-element";

    cy.frameLoaded(iframeSelector);
    cy.wait(2000);
    cy.iframe(iframeSelector)
      .find("[data-testid=paymentMethodsSelect]")
      .should("be.visible")
      .select(paymentMethodsData.weChatPay);

    cy.get("#submit").click();
    cy.wait(4000);

    cy.iframe("#orca-fullscreen").contains("QR Code").should("be.visible");

    cy.iframe("#orca-fullscreen").contains("TEST DATA").should("be.visible");

    // cy.url().should("include", "sandbox.hyperswitch");
  });
});
