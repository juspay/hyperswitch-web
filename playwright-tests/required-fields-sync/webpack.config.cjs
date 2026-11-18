const path = require("node:path");
const fs = require("node:fs");
const webpack = require("../../node_modules/webpack");
const root = path.resolve(__dirname, "../..");
if (!fs.existsSync(path.join(root, "src/Utilities/DynamicFieldsUtils.bs.js")))
  throw new Error("Compile pinned W/U ReScript in the disposable copy first");
module.exports = {
  mode: "development",
  devtool: false,
  entry: path.join(__dirname, "browser-entry.js"),
  output: {
    path: path.join(__dirname, "dist/components"),
    filename: "fixture.js",
    publicPath: "/",
    clean: false,
  },
  plugins: [
    new webpack.DefinePlugin({
      __SDK_CONFIG__: JSON.stringify({
        repoName: "required-fields-fixture",
        repoVersion: "0.134.0",
        publicPath: "",
        backendEndPoint: "/forbidden-api",
        confirmEndPoint: "/forbidden-confirm",
        sdkUrl: "",
        logEndpoint: "/forbidden-log",
        sentryDSN: "",
        sentryScriptUrl: "",
        enableLogging: false,
        loggingLevel: "none",
        maxLogsPushedPerEventName: 0,
        isIntegrationEnv: false,
        isSandboxEnv: false,
        isProductionEnv: false,
        isLocal: true,
        isPciCompliant: true,
      }),
      __SDK_VERSION__: JSON.stringify("v1"),
      __VERIFY_SRI__: "false",
    }),
  ],
  module: {
    rules: [
      { test: /\.(svg|png|jpg|woff2?)$/, type: "asset/resource" },
      { test: /\.css$/, type: "asset/source" },
    ],
  },
  resolve: {
    extensions: [".js", ".json"],
    fallback: { fs: false, path: false },
  },
};
