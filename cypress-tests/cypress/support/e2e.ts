// ***********************************************************
// This example support/e2e.js is processed and
// loaded automatically before your test files.
//
// This is a great place to put global configuration and
// behavior that modifies Cypress.
//
// You can change the location of this file or turn off
// automatically serving support files with the
// 'supportFile' configuration option.
//
// You can read more here:
// https://on.cypress.io/configuration
// ***********************************************************

// Import commands.js using ES2015 syntax:
import "./commands";

// Environment validation - fails fast if required vars missing
const requiredEnvVars = [
  "HYPERSWITCH_PUBLISHABLE_KEY",
  "HYPERSWITCH_SECRET_KEY"
];

before(() => {
  const missing = requiredEnvVars.filter(key => !Cypress.env(key));
  if (missing.length > 0) {
    throw new Error(
      `❌ Missing required environment variables:\n${missing.map(v => `  - ${v}`).join('\n')}\n\n` +
      `Please set them in cypress.env.json or as environment variables.`
    );
  }
  cy.log("✅ All required environment variables are set");
});

// Global test cleanup
afterEach(() => {
  cy.clearCookies();
  cy.clearLocalStorage();
});
