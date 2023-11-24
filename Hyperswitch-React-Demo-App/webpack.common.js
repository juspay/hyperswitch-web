const path = require("path");
const webpack = require("webpack");
const MiniCssExtractPlugin = require("mini-css-extract-plugin");
const CopyPlugin = require("copy-webpack-plugin");
const HtmlWebpackPlugin = require("html-webpack-plugin");
const TerserPlugin = require("terser-webpack-plugin");
const BundleAnalyzerPlugin =
  require("webpack-bundle-analyzer").BundleAnalyzerPlugin;
require("dotenv").config({ path: "./.env" });

module.exports = (endpoint, publicPath = "auto") => {
  let entries = {
    app: "./src/index.js",
  };
  return {
    mode: "development",
    devtool: "source-map",
    output: {
      path: path.resolve(__dirname, "dist"),
      clean: true,
    },
    optimization: {
      sideEffects: true,
      minimize: true,
      minimizer: [
        new TerserPlugin({
          terserOptions: {
            compress: {
              drop_console: false,
            },
          },
        }),
      ],
    },
    plugins: [
      new MiniCssExtractPlugin(),
      new CopyPlugin({
        patterns: [
          { from: "public" },
          {
            from: path.resolve(__dirname, "server.js"),
          },
        ],
      }),
      new HtmlWebpackPlugin({
        inject: false,
        template: "./public/playgroundIndex.html",
      }),
      new webpack.DefinePlugin({
        endPoint:
          typeof endpoint === "string"
            ? JSON.stringify(endpoint)
            : JSON.stringify(process.env.SELF_SERVER_URL),
        SCRIPT_SRC: JSON.stringify(process.env.HYPERSWITCH_CLIENT_URL),
      }),
      new BundleAnalyzerPlugin({
        analyzerMode: "static",
        reportFilename: "bundle-report.html",
        openAnalyzer: false,
      }),
    ],
    module: {
      rules: [
        {
          test: /\.?js$/,
          exclude: /node_modules/,
          use: {
            loader: "babel-loader",
            options: {
              presets: ["@babel/preset-env", "@babel/preset-react"],
            },
          },
        },
        {
          test: /\.(jpe?g|png|gif|svg)$/i,
          loader: "file-loader",
          options: {
            name: "/public/assets/[name].[ext]",
          },
        },
        {
          test: /\.css$/i,
          use: ["style-loader", "css-loader"],
        },
      ],
    },
    entry: entries,
  };
};
