describe("Card Payment Flow Test", () => {
  let customerData;
  const iframeSelector = "#orca-payment-element-iframeRef-orca-elements-payment-element-payment-element";
  const thankYouMessage = "Thanks for your order!";

  beforeEach(() => {
    cy.visit("http://localhost:9060");
    cy.hardReload();

    cy.fixture("testCustomer").then((customer) => {
      customerData = customer;
    });
  });

  it("should load the page successfully", () => {
    // Page load is validated by the presence of subsequent elements
    cy.url().should('eq', 'http://localhost:9060');
  });

  it("should render the title correctly", () => {
    cy.contains("Hyperswitch Unified Checkout").should("be.visible");
  });

  it("should load the Orca payment element iframe", () => {
    cy.get(iframeSelector)
      .should("be.visible")
      .then(iframe => {
        // Check iframe content document loaded
        cy.wrap(iframe.contents().find('body')).should('be.visible');
      });
  });

  it("should complete card payment flow successfully", () => {
    cy.iframe(iframeSelector)
      .find(`[data-testid=${testIds.addNewCardIcon}]`)
      .should("be.visible")
      .click();

    // Fill in the card details
    cy.testDynamicFields(customerData, ["expiryInput", "cardNoInput", "email"]);

    // Submit the payment form
    cy.get("#submit").click();

    // Validate success message
    cy.contains(thankYouMessage).should("be.visible");
  });
});
