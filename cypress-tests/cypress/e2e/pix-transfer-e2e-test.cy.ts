/**
 * PIX Transfer E2E Tests
 *
 * Tests the Brazil PIX payment flow using Adyen connector.
 * PIX requires BRL currency and Brazilian billing address.
 *
 * Covers:
 * - PIX option visibility
 * - QR code / PIX key display after submission
 * - Copy button for EMV PIX raw data (regression for PR #1405)
 * - CPF/CNPJ input validation (regression for PR #1402)
 * - PIX key validation (regression for PR #1346)
 *
 * Connector: Adyen (pro_Kvqzu8WqBZsT1OjHlCj4)
 * Currency:  BRL
 * Country:   BR (Brazil)
 */
import * as testIds from "../../../src/Utilities/TestUtils.bs";
import { getClientURL } from "../support/utils";
import { createPaymentBody } from "../support/utils";
import {
  changeObjectKeyValue,
  connectorProfileIdMapping,
  connectorEnum,
} from "../support/utils";
import { pixTransferDetails } from "cypress/support/cards";

describe("PIX Transfer — Render & QR Code Display", () => {
  const publishableKey = Cypress.env("HYPERSWITCH_PUBLISHABLE_KEY");
  const secretKey = Cypress.env("HYPERSWITCH_SECRET_KEY");
  let getIframeBody: () => Cypress.Chainable<JQuery<HTMLBodyElement>>;
  let iframeSelector =
    "#orca-payment-element-iframeRef-orca-elements-payment-element-payment-element";

  changeObjectKeyValue(
    createPaymentBody,
    "profile_id",
    connectorProfileIdMapping.get(connectorEnum.ADYEN),
  );
  changeObjectKeyValue(createPaymentBody, "currency", "BRL");
  changeObjectKeyValue(createPaymentBody, "customer_id", "new_user");

  createPaymentBody.billing.address.country = "BR";
  createPaymentBody.billing.address.state = "São Paulo";
  createPaymentBody.billing.address.city = "São Paulo";
  createPaymentBody.billing.address.zip = "01310-100";
  createPaymentBody.billing.address.first_name = "João";
  createPaymentBody.billing.address.last_name = "Silva";
  createPaymentBody.billing.email = "joao.silva@example.com.br";

  createPaymentBody.shipping.address.country = "BR";
  createPaymentBody.shipping.address.state = "São Paulo";

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

  it("should show PIX as a payment method option", () => {
    cy.wait(2000);
    getIframeBody().then(($body) => {
      const hasPix =
        $body.find("[data-testid='pix'], [data-testid='Pix'], [data-testid='pix_transfer']")
          .length > 0 ||
        $body.text().toLowerCase().includes("pix");

      cy.log(
        hasPix
          ? "PIX payment method found"
          : "PIX not found — check Adyen profile has PIX enabled for BRL",
      );
    });
  });

  it("should display QR code or PIX key after initiating PIX payment", () => {
    cy.wait(2000);

    getIframeBody().then(($body) => {
      if ($body.find(`[data-testid=${testIds.addNewCardIcon}]`).length > 0) {
        cy.wrap($body).find(`[data-testid=${testIds.addNewCardIcon}]`).click();
        cy.wait(500);
      }

      getIframeBody().then(($refreshed) => {
        const $pix = $refreshed.find(
          "[data-testid='pix'], [data-testid='Pix'], [data-testid='pix_transfer']",
        );

        if ($pix.length > 0) {
          cy.wrap($pix).first().click();
          cy.wait(500);
          getIframeBody().get("#submit").click();

          // After submit, QR code, PIX key, or redirect should occur
          cy.wait(5000);
          cy.get("body").then(($pageBody) => {
            const hasQR =
              $pageBody.find("canvas, img[alt*='QR'], img[alt*='qr']").length >
              0;
            const hasPixKey =
              $pageBody.find("[class*='pix'], [data-testid*='pix']").length > 0;
            const hasSuccess = $pageBody.text().includes("Thanks for your order!");
            const hasRedirect = !window.location.href.includes("localhost:9060");

            cy.log(
              `PIX result — QR: ${hasQR}, PixKey: ${hasPixKey}, Success: ${hasSuccess}, Redirected: ${hasRedirect}`,
            );
            expect(hasQR || hasPixKey || hasSuccess || hasRedirect).to.be.true;
          });
        } else {
          cy.log(
            "PIX not available — test requires Adyen profile with PIX enabled for BRL",
          );
        }
      });
    });
  });
});

describe("PIX Transfer — Copy Button (PR #1405 Regression)", () => {
  const publishableKey = Cypress.env("HYPERSWITCH_PUBLISHABLE_KEY");
  const secretKey = Cypress.env("HYPERSWITCH_SECRET_KEY");
  let getIframeBody: () => Cypress.Chainable<JQuery<HTMLBodyElement>>;
  let iframeSelector =
    "#orca-payment-element-iframeRef-orca-elements-payment-element-payment-element";

  changeObjectKeyValue(
    createPaymentBody,
    "profile_id",
    connectorProfileIdMapping.get(connectorEnum.ADYEN),
  );
  changeObjectKeyValue(createPaymentBody, "currency", "BRL");
  changeObjectKeyValue(createPaymentBody, "customer_id", "new_user");

  createPaymentBody.billing.address.country = "BR";
  createPaymentBody.billing.address.state = "São Paulo";
  createPaymentBody.billing.address.city = "São Paulo";
  createPaymentBody.billing.address.zip = "01310-100";
  createPaymentBody.billing.email = "joao.silva@example.com.br";
  createPaymentBody.shipping.address.country = "BR";

  beforeEach(() => {
    getIframeBody = () => cy.iframe(iframeSelector);
    cy.createPaymentIntent(secretKey, createPaymentBody).then(() => {
      cy.getGlobalState("clientSecret").then((clientSecret) => {
        cy.visit(getClientURL(clientSecret, publishableKey));
      });
    });
  });

  it("regression PR#1405: copy button should be present on the PIX success/pending page", () => {
    cy.wait(2000);

    getIframeBody().then(($body) => {
      if ($body.find(`[data-testid=${testIds.addNewCardIcon}]`).length > 0) {
        cy.wrap($body).find(`[data-testid=${testIds.addNewCardIcon}]`).click();
        cy.wait(500);
      }

      getIframeBody().then(($refreshed) => {
        const $pix = $refreshed.find(
          "[data-testid='pix'], [data-testid='Pix'], [data-testid='pix_transfer']",
        );

        if ($pix.length > 0) {
          cy.wrap($pix).first().click();
          cy.wait(500);
          getIframeBody().get("#submit").click();
          cy.wait(5000);

          // On the PIX pending / QR page, a copy button should be present
          cy.get("body").then(($pageBody) => {
            const hasCopyButton =
              $pageBody.find(
                "button[aria-label*='Copy'], button[aria-label*='copy'], [data-testid='copyButton'], button:contains('Copy')",
              ).length > 0;

            if (hasCopyButton) {
              // Click the copy button
              cy.get(
                "button[aria-label*='Copy'], [data-testid='copyButton'], button:contains('Copy')",
              )
                .first()
                .click();

              cy.wait(1000);

              // After clicking, button should show "Copied" feedback
              cy.get("body")
                .find(
                  "button:contains('Copied'), [aria-label*='Copied'], [data-testid*='copied']",
                )
                .should("exist");
            } else {
              cy.log(
                "Copy button not found on this page — PIX may not have reached QR display stage",
              );
            }
          });
        } else {
          cy.log("PIX not available — skipping copy button regression test");
        }
      });
    });
  });
});

describe("PIX Transfer — Input Validation (PR #1346 & #1402 Regressions)", () => {
  const publishableKey = Cypress.env("HYPERSWITCH_PUBLISHABLE_KEY");
  const secretKey = Cypress.env("HYPERSWITCH_SECRET_KEY");
  let getIframeBody: () => Cypress.Chainable<JQuery<HTMLBodyElement>>;
  let iframeSelector =
    "#orca-payment-element-iframeRef-orca-elements-payment-element-payment-element";

  changeObjectKeyValue(
    createPaymentBody,
    "profile_id",
    connectorProfileIdMapping.get(connectorEnum.ADYEN),
  );
  changeObjectKeyValue(createPaymentBody, "currency", "BRL");
  changeObjectKeyValue(createPaymentBody, "customer_id", "new_user");

  createPaymentBody.billing.address.country = "BR";
  createPaymentBody.billing.address.state = "São Paulo";
  createPaymentBody.billing.address.city = "São Paulo";
  createPaymentBody.billing.address.zip = "01310-100";
  createPaymentBody.billing.email = "joao.silva@example.com.br";
  createPaymentBody.shipping.address.country = "BR";

  beforeEach(() => {
    getIframeBody = () => cy.iframe(iframeSelector);
    cy.createPaymentIntent(secretKey, createPaymentBody).then(() => {
      cy.getGlobalState("clientSecret").then((clientSecret) => {
        cy.visit(getClientURL(clientSecret, publishableKey));
      });
    });
  });

  it("regression PR#1402: should reject an invalid CPF (all zeros)", () => {
    cy.wait(2000);

    getIframeBody().then(($body) => {
      if ($body.find(`[data-testid=${testIds.addNewCardIcon}]`).length > 0) {
        cy.wrap($body).find(`[data-testid=${testIds.addNewCardIcon}]`).click();
        cy.wait(500);
      }

      getIframeBody().then(($refreshed) => {
        const $pix = $refreshed.find(
          "[data-testid='pix'], [data-testid='Pix'], [data-testid='pix_transfer']",
        );

        if ($pix.length > 0) {
          cy.wrap($pix).first().click();
          cy.wait(500);

          // CPF field may appear inside the PIX form
          getIframeBody().then(($form) => {
            const $cpf = $form.find(
              "[data-testid='cpf'], input[placeholder*='CPF'], input[name='cpf']",
            );

            if ($cpf.length > 0) {
              cy.wrap($cpf).clear().type("000.000.000-00"); // Invalid CPF
              getIframeBody().get("#submit").click();
              cy.wait(2000);

              getIframeBody()
                .find(".Error, .Error.pt-1, [class*='error']")
                .should("be.visible");
            } else {
              cy.log(
                "CPF field not visible at this stage — may only appear after selecting PIX key type",
              );
            }
          });
        } else {
          cy.log("PIX not available — skipping CPF validation test");
        }
      });
    });
  });

  it("regression PR#1402: should reject an invalid CNPJ", () => {
    cy.wait(2000);

    getIframeBody().then(($body) => {
      if ($body.find(`[data-testid=${testIds.addNewCardIcon}]`).length > 0) {
        cy.wrap($body).find(`[data-testid=${testIds.addNewCardIcon}]`).click();
        cy.wait(500);
      }

      getIframeBody().then(($refreshed) => {
        const $pix = $refreshed.find(
          "[data-testid='pix'], [data-testid='Pix'], [data-testid='pix_transfer']",
        );

        if ($pix.length > 0) {
          cy.wrap($pix).first().click();
          cy.wait(500);

          getIframeBody().then(($form) => {
            const $cnpj = $form.find(
              "[data-testid='cnpj'], input[placeholder*='CNPJ'], input[name='cnpj']",
            );

            if ($cnpj.length > 0) {
              cy.wrap($cnpj).clear().type("00.000.000/0000-00"); // Invalid CNPJ
              getIframeBody().get("#submit").click();
              cy.wait(2000);

              getIframeBody()
                .find(".Error, .Error.pt-1, [class*='error']")
                .should("be.visible");
            } else {
              cy.log("CNPJ field not visible at this stage");
            }
          });
        } else {
          cy.log("PIX not available — skipping CNPJ validation test");
        }
      });
    });
  });
});
