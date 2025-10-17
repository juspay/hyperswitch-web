const path = require("path");
require("dotenv").config();
const { merge } = require("webpack-merge");
const common = require("./webpack.common.js");

const sdkEnv = process.env.sdkEnv ?? "local";

const endpointMap = {
  prod: "https://api.hyperswitch.io/payments",
  sandbox: "https://sandbox.hyperswitch.io/payments",
  integ: "https://integ.hyperswitch.io/api/payments",
  local: "http://localhost:8080/payments", // Default or local environment endpoint
};

const backendEndPoint = endpointMap[sdkEnv] || endpointMap.local;

const devServer = {
  static: {
    directory: path.join(__dirname, "dist"),
  },
  hot: true,
  host: "0.0.0.0",
  port: process.env.PORT || 9050,
  historyApiFallback: true,
  proxy: [
    {
      context: ["/payments"],
      target: backendEndPoint,
      changeOrigin: true,
      secure: true,
      pathRewrite: { "^/payments": "" },
    },
    {
      context: ["/assets/v1/jsons/location/"],
      target: "http://localhost:8080",
      changeOrigin: true,
      secure: true,
      pathRewrite: {
        "^/assets/v1/jsons/location/": "/assets/v1/jsons/location/",
      },
    },
    // Uncomment the following if needed for 3DS method proxying
    // {
    //   context: ["/3dsmethod"],
    //   target: "https://acs40.sandbox.3dsecure.io",
    //   changeOrigin: true,
    //   secure: false,
    // },
  ],
  headers: {
    "Cache-Control": "must-revalidate",
  },
};

module.exports = merge(common(), {
  mode: "development",
  devServer,
});
