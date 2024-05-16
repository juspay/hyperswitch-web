const path = require("path");
const dotenv = require("dotenv").config();
const { merge } = require("webpack-merge");
const common = require("./webpack.common.js");
const sdkEnv = process.env.sdkEnv ?? "local";

let backendEndPoint =
  sdkEnv === "prod"
    ? "https://api.hyperswitch.io/payments"
    : sdkEnv === "sandbox"
    ? "https://sandbox.hyperswitch.io/payments"
    : sdkEnv === "integ"
    ? "https://integ-api.hyperswitch.io/payments"
    : "http://localhost:8080/payments";

let devServer = {
  contentBase: path.join(__dirname, "dist"),
  hot: true,
  host: "0.0.0.0",
  port: 9050,
  historyApiFallback: true,
  compress: true,
  proxy: {
    "/payments": {
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
  disableHostCheck: true,
};

module.exports = merge([
  common(),
  {
    mode: "development",
    devServer: devServer,
  },
]);
