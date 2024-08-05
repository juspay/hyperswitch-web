const path = require("path");
const { merge } = require("webpack-merge");
const common = require("./webpack.common.js");

const devServer = {
  static: {
    directory: path.join(__dirname, "dist"),
  },
  hot: true,
  host: "0.0.0.0",
  port: 9060,
  historyApiFallback: true,
  proxy: [
    {
      context: ["/payments"],
      target: "http://localhost:5252",
      changeOrigin: true,
      secure: true,
      pathRewrite: { "^/payments": "" },
    },
  ],
  headers: {
    "Cache-Control": "must-revalidate",
  },
};

module.exports = merge(common("/payments"), {
  mode: "development",
  devServer,
});
