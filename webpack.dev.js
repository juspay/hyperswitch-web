const path = require("path");
const fs = require("fs");
const dotenv = require("dotenv");
const { merge } = require("webpack-merge");
const common = require("./webpack.common.js");

// * Load environment variables from .env file
const envPath = path.resolve(__dirname, ".env");
const envVars = fs.existsSync(envPath)
  ? dotenv.parse(fs.readFileSync(envPath))
  : {};

const sdkEnv = envVars.SDK_ENV ?? "local";

let backendEndPoint =
  sdkEnv === "prod"
    ? "https://checkout.hyperswitch.io/api/payments"
    : sdkEnv === "sandbox"
    ? "https://beta.hyperswitch.io/api/payments"
    : sdkEnv === "integ"
    ? "https://integ-api.hyperswitch.io/payments"
    : "https://beta.hyperswitch.io/api/payments";

let devServer = {
  contentBase: path.join(__dirname, "dist"),
  hot: true,
  host: "0.0.0.0",
  port: 9050,
  historyApiFallback: true,
  proxy: {
    "/api/payments": {
      target: backendEndPoint,
      changeOrigin: true,
      secure: true,
      pathRewrite: { "^/payments": "" },
    },
    // "/3dsmethod": {
    //   target: "https://acs40.sandbox.3dsecure.io",
    //   changeOrigin: true,
    //   secure: false,
    // },
  },
  headers: {
    "Cache-Control": "must-revalidate",
  },
};

module.exports = merge([
  common(),
  {
    mode: "development",
    devServer: devServer,
  },
]);
