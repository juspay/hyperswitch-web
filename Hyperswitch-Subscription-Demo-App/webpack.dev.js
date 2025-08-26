const path = require("path");
const { merge } = require("webpack-merge");
const common = require("./webpack.common.js");

const devServer = {
  static: {
    directory: path.join(__dirname, "dist"),
  },
  hot: true,
  host: "0.0.0.0",
  port: 9061,
  historyApiFallback: true,
  proxy: [
    {
      context: ["/subscriptions"],
      target: "http://localhost:5253",
      changeOrigin: true,
      secure: true,
      pathRewrite: { "^/subscriptions": "" },
    },
  ],
  headers: {
    "Cache-Control": "must-revalidate",
  },
};

module.exports = merge(common("/subscriptions"), {
  mode: "development",
  devServer,
});
