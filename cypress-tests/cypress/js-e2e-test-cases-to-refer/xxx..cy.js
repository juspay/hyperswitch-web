const enterValueInIframeIfExsist = (selector, value) => {
  // cy.iframe(iframeSelector)
  //   .find(selector)
  //   .then(($input) => {
  //     if ($input.length > 0) {
  //       cy.wrap($input).type(value);
  //       // You can continue with other actions or assertions here
  //     } else {
  //       cy.log(
  //         `Element with selector ${selector} does not exist in the iframe`
  //       );
  //       // You can choose to take additional actions or assertions here if needed
  //     }
  //   });
  // // cy.iframe(iframeSelector).find(selector).should("be.visible").type(value);

  cy.iframe(iframeSelector).find(selector).should("be.visible").type(value);
  // cy.on("uncaught:exception", (err, runnable) => {
  //   // expect(err.message).to.include("something about the error");
  //   cy.log("failed------------->");
  //   cy.get("#submit").click();
  //   done();
  //   return false;
  // });

  cy.on("fail", (err, runnable) => {
    // expect(err.message).to.include("something about the error");
    console.warn(`here-----?> ${err}`);
    cy.iframe(iframeSelector).find("#submit").click();
    console.log("Sanskar");
    return true;
  });

  // cy.iframe(iframeSelector)
  //   .find(selector)
  //   .then(($input) => {
  //     if ($input.length > 0) {
  //       cy.log("11111");
  //     } else {
  //       cy.log("22222");
  //     }
  //   });
};
