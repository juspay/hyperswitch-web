const fs = require("node:fs");
const path = require("node:path");
const assert = require("node:assert/strict");
const { target } = require("./fixture.cjs");
const owned = target();
assert(
  !fs.existsSync(path.join(owned.web, "Hyperswitch-React-Demo-App/.env")),
  "refuse ambient dotenv input",
);
const origin = new URL(process.env.HYPERSWITCH_CLIENT_URL);
assert(
  origin.protocol === "http:" && origin.hostname === "127.0.0.1" && origin.port,
);
const config = require(
  path.join(owned.web, "Hyperswitch-React-Demo-App/webpack.common.js"),
)("/payments");
config.output.path = path.join(__dirname, "dist/checkout-demo");
config.devtool = false;
config.optimization.minimize = false;
module.exports = config;
