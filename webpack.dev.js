const path = require("path");
require("dotenv").config();
const { merge } = require("webpack-merge");
const common = require("./webpack.common.js");

const sdkEnv = process.env.sdkEnv ?? "local";

const endpointMap = {
  prod: "https://api.hyperswitch.io/payments",
  sandbox: "https://sandbox.hyperswitch.io/payments",
  integ: "https://integ.hyperswitch.io/api/payments",
  local: "https://sandbox.hyperswitch.io/payments", // Default or local environment endpoint
};

const backendEndPoint = endpointMap[sdkEnv] || endpointMap.local;

const WS_URL = process.env.WS_URL || null;

const parseAllowedHosts = (envVar) => {
  if (!envVar) return [];
  return envVar.split(',').map(host => host.trim());
};

const allowedHosts = parseAllowedHosts(process.env.ALLOWED_HOSTS);

const devServer = {
  static: {
    directory: path.join(__dirname, "dist"),
  },
  hot: true,
  allowedHosts: allowedHosts,
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
      target: "https://beta.hyperswitch.io",
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
  client: {
    webSocketURL: WS_URL || {
      protocol: "wss",
      hostname: process.env.WS_HOSTNAME || "localhost",
      port: process.env.WS_PORT || 9050,
      pathname: process.env.WS_PATHNAME || "/ws",
    },
    logging: "info",
    overlay: true,
    reconnect: 10,
  },
};

module.exports = merge(common(), {
  mode: "development",
  devServer,
});
