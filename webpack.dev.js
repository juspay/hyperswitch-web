const path = require("path");
require("dotenv").config();
const { merge } = require("webpack-merge");
const common = require("./webpack.common.js");

const sdkEnv = process.env.sdkEnv ?? "local";

const endpointMap = {
  prod: "https://api.hyperswitch.io/payments",
  sandbox: "http://localhost:8080/payments",
  integ: "https://integ-api.hyperswitch.io/payments",
  local: "http://localhost:8080/payments", // Default or local environment endpoint
};

const backendEndPoint = endpointMap[sdkEnv] || endpointMap.local;

const devServer = {
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
    // * Uncomment the following if needed for 3DS method proxying
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

module.exports = merge(common(), {
  mode: "development",
  devServer,
});
