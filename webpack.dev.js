const path = require("path");
const { merge } = require("webpack-merge");
const common = require("./webpack.common.js");

const sdkEnv = process.env.sdkEnv;

let backendEndPoint =
  sdkEnv === "prod"
    ? "https://api.hyperswitch.io/payments"
    : sdkEnv === "sandbox"
    ? "https://sandbox.hyperswitch.io/payments"
    : sdkEnv === "integ"
    ? "https://integ-api.hyperswitch.io/payments"
    : "https://sandbox.hyperswitch.io/payments";

let devServer = {
  contentBase: path.join(__dirname, "dist"),
  hot: true,
  port: 9050,
  historyApiFallback: true,
  proxy: {
    "/payments": {
      target: backendEndPoint,
      changeOrigin: true,
      secure: true,
      pathRewrite: { "^/payments": "" },
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
