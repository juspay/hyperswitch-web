/*
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
    // cy.wait(1000);
    // cy.frameLoaded(iframeSelector);

    // cy.iframe(iframeSelector)
    //   .find(`[data-testid=${testIds.addNewCardIcon}]`)
    //   .should("be.visible")
    //   .click();

    cy.iframe(iframeSelector)
      .find(`[data-testid=card-1]`)
      .should("be.visible")
      .click();

    // cy.wait(5000);

    const mapping = {
      [testIds.cardNoInputTestId]: customerData.cardNo,
      [testIds.expiryInputTestId]: customerData.cardExpiry,
      [testIds.cardCVVInputTestId]: customerData.cardCVV,
      [testIds.fullNameInputTestId]: customerData.cardHolderName,
      [testIds.cardHolderNameInputTestId]: customerData.cardHolderName,
      [testIds.emailInputTestId]: customerData.email,
      [testIds.addressLine1InputTestId]: customerData.address,
      [testIds.cityInputTestId]: customerData.city,
      [testIds.countryDropDownTestId]: customerData.country,
      [testIds.stateDropDownTestId]: customerData.state,
      [testIds.postalCodeInputTestId]: customerData.postalCode,
    };

    let clientSecret;
    cy.request({
      method: "GET",
      url: "http://localhost:5252/create-payment-intent",
    }).then((response) => {
      clientSecret = response.body.clientSecret;

      cy.request({
        method: "GET",
        url: `https://sandbox.hyperswitch.io/account/payment_methods?client_secret=${clientSecret}`,
        headers: {
          "Content-Type": "application/json",
          "api-key": publishableKey,
        }, // Replace with your API endpoint
      }).then((response) => {
        // Check the response status
        console.warn(response.body.payment_methods);

        let paymentMethods = response.body.payment_methods;

        const foundElement = paymentMethods.find(
          (element) => element.payment_method === "card"
        );

        const ele = foundElement.payment_method_types.find(
          (element) => element.payment_method_type === "debit"
        );
        console.log(ele.required_fields);

        let requiredFieldsArr = ele.required_fields;
        let idArr = [];
        for (const key in requiredFieldsArr) {
          idArr.push(testIds.fieldTestIdMapping[key]);
        }

        let stringsToRemove = ["expiryInput", "cardNoInput", "email"];
        idArr = idArr.filter((item) => !stringsToRemove.includes(item));
        const countryIndex = idArr.indexOf("Country");
        const stateIndex = idArr.indexOf("State");

        // Move "State" after "Country"
        if (
          countryIndex !== -1 &&
          stateIndex !== -1 &&
          stateIndex < countryIndex
        ) {
          idArr.splice(stateIndex, 1);
          idArr.splice(countryIndex, 0, "State");
        }

        console.warn(idArr);

        expect(response.status).to.eq(200);

        idArr.forEach((ele) => {
          cy.iframe(iframeSelector)
            .find(`[data-testid=${ele}]`)
            .should("be.visible")
            .type(mapping[ele], { force: true });

          if (ele === "Country" || ele === "State") {
            cy.iframe(iframeSelector)
              .find(`[data-testid=${ele}]`)
              .should("be.visible")
              .select(mapping[ele]);
          }
        });
      });
    });

    cy.get("#submit").click();
    // cy.url().should("include", "sandbox.hyperswitch");

    cy.iframe(`#challengeFrame`)
      .find(`id=test-source-authorize-3ds`)
      .should("be.visible")
      .click();
    cy.wait(20000);
    cy.contains("Thanks for your order!").should("be.visible");
  });
});
*/
