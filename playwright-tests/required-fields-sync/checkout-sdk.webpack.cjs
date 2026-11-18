const fs = require("node:fs");
const path = require("node:path");
const assert = require("node:assert/strict");
const { target } = require("./fixture.cjs");
const owned = target();
assert(
  !fs.existsSync(path.join(owned.web, ".env")),
  "refuse ambient dotenv input",
);
const origin = new URL(process.env.ENV_SDK_URL);
assert(
  origin.protocol === "http:" && origin.hostname === "127.0.0.1" && origin.port,
);
assert.equal(
  process.env.ENV_BACKEND_URL,
  "https://required-fields-router.invalid",
);
// Use the pinned SDK entry points, loaders and HTML/CSS generation. Explicit
// fixture settings prevent optional upload plugins and secret build inputs.
Object.assign(process.env, {
  sdkEnv: "local",
  SDK_VERSION: "v1",
  IS_SENTRY_ENABLED: "false",
  SENTRY_DSN: "",
  SENTRY_AUTH_TOKEN: "",
  SENTRY_SCRIPT_URL: "",
  VISA_API_KEY_ID: "",
  VISA_API_CERTIFICATE_PEM: "",
  ENABLE_LOGGING: "false",
  ENV_LOGGING_URL: "",
  DISABLE_CSP: "true",
  HYPERSWITCH_STACK: "",
});
const config = require(path.join(owned.web, "webpack.common.js"))();
config.output.path = path.join(__dirname, "dist/checkout-sdk");
config.devtool = false;
module.exports = config;
