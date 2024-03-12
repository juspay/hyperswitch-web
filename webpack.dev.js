const path = require("path");
const { merge } = require("webpack-merge");
const common = require("./webpack.common.js");

const sdkEnv = process.env.sdkEnv;

let backendEndPoint =
  sdkEnv === "prod"
    ? "https://checkout.hyperswitch.io/api"
    : sdkEnv === "sandbox"
    ? "https://beta.hyperswitch.io/api"
    : sdkEnv === "integ"
    ? "https://integ-api.hyperswitch.io"
    : "https://beta.hyperswitch.io/api";

let devServer = {
  contentBase: path.join(__dirname, "dist"),
  hot: true,
  port: 9050,
  historyApiFallback: true,
  proxy: {
    "/payments": {
      target: backendEndPoint + "/payments",
      changeOrigin: true,
      secure: true,
      pathRewrite: { "^/payments": "" },
    },
    "/customers": {
      target: backendEndPoint + "/customers",
      changeOrigin: true,
      secure: true,
      pathRewrite: { "^/customers": "" },
    },
    "/account": {
      target: backendEndPoint + "/account",
      changeOrigin: true,
      secure: true,
      pathRewrite: { "^/account": "" },
    },
  },
  headers: {
    "Cache-Control": "max-age=31536000,must-revalidate",
  },
};

module.exports = merge([
  common(),
  {
    mode: "development",
    devServer: devServer,
  },
]);
