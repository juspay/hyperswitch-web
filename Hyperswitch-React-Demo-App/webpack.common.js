const path = require("path");
const webpack = require("webpack");
const MiniCssExtractPlugin = require("mini-css-extract-plugin");
const CopyPlugin = require("copy-webpack-plugin");
const HtmlWebpackPlugin = require("html-webpack-plugin");
const TerserPlugin = require("terser-webpack-plugin");
const { BundleAnalyzerPlugin } = require("webpack-bundle-analyzer");
require("dotenv").config({ path: "./.env" });

// Helper function to get environment variables with fallback
const getEnvVariable = (variable, defaultValue) => {
  const value = process.env[variable];
  return value && value.length > 0 ? value : defaultValue;
};

// Extract SDK version and other variables
const sdkVersionValue = getEnvVariable("SDK_VERSION", "v1");
const repoVersion = getEnvVariable("SDK_TAG_VERSION", "0.1.0");
const sdkEnv = getEnvVariable("sdkEnv", "local");

// Define public path based on SDK version and environment
const repoPublicPath =
  sdkEnv === "local" ? "" : `/web/${repoVersion}/${sdkVersionValue}`;

module.exports = (endpoint, publicPath = "auto") => {
  const entries = {
    app: "./src/index.js",
  };

  return {
    mode: "development",
    devtool: "source-map",
    output: {
      path: path.resolve(__dirname, "dist", sdkEnv, sdkVersionValue),
      clean: true,
      publicPath: `${repoPublicPath}/`,
    },
    // Add this resolve section to fix the jsx-runtime issue
    resolve: {
      extensions: [".js", ".jsx", ".json", ".mjs"],
      alias: {
        "react/jsx-runtime": require.resolve("react/jsx-runtime"),
      },
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
          { from: path.resolve(__dirname, "server.js") },
        ],
      }),
      new HtmlWebpackPlugin({
        inject: false,
        template: "./public/playgroundIndex.html",
      }),
      new webpack.DefinePlugin({
        ENDPOINT: JSON.stringify(endpoint),
        SCRIPT_SRC: JSON.stringify(process.env.HYPERSWITCH_CLIENT_URL),
        SELF_SERVER_URL: JSON.stringify(process.env.SELF_SERVER_URL ?? ""),
        SDK_VERSION: JSON.stringify(sdkVersionValue),
        REPO_VERSION: JSON.stringify(repoVersion),
        PUBLIC_PATH: JSON.stringify(repoPublicPath),
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
