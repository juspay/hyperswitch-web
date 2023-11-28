const path = require("path");
const { merge } = require("webpack-merge");
const common = require("./webpack.common.js");

let devServer = {
  contentBase: path.join(__dirname, "dist"),
  hot: true,
  port: 9060,
  historyApiFallback: true,
  proxy: {
    "/payments": {
      target: "http://localhost:5252",
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
  common("/payments"),
  {
    mode: "development",
    devServer: devServer,
  },
]);
