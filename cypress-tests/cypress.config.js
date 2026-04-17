const { defineConfig } = require("cypress");

module.exports = defineConfig({
  projectId: "6r9ayw",
  chromeWebSecurity: false,

  e2e: {
    baseUrl: "http://localhost:9050",
    supportFile: "cypress/support/e2e.ts",
    experimentalModifyObstructiveThirdPartyCode: true,
    defaultCommandTimeout: 10000,
    requestTimeout: 10000,
    responseTimeout: 10000,
    pageLoadTimeout: 30000,
    viewportWidth: 1280,
    viewportHeight: 720,
    video: false,
    screenshotOnRunFailure: true,
    trashAssetsBeforeRuns: true,
  },

  retries: { 
    runMode: 2,    // Retry twice in CI for flaky tests
    openMode: 0    // No retry in interactive mode
  },

  env: {
    HYPERSWITCH_API_URL: "https://sandbox.hyperswitch.io",
  },

  // component: {
  //   devServer: {
  //     framework: "react",
  //     bundler: "webpack",
  //   },
  // },
});
