const { defineConfig } = require("cypress");

module.exports = defineConfig({
  watchForFileChanges:true,
  projectId: "6r9ayw",
  chromeWebSecurity: false,
  e2e: {
    baseUrl: "http://localhost:9050",
  },
  retries: { runMode: 1, openMode: 1 },
});