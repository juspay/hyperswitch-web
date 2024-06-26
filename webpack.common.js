const webpack = require("webpack");
const path = require("path");
const dotenv = require("dotenv").config();
const tailwindcss = require("tailwindcss");
const MiniCssExtractPlugin = require("mini-css-extract-plugin");
const CopyPlugin = require("copy-webpack-plugin");
const HtmlWebpackPlugin = require("html-webpack-plugin");
const TerserPlugin = require("terser-webpack-plugin");
const { BundleAnalyzerPlugin } = require("webpack-bundle-analyzer");
const { sentryWebpackPlugin } = require("@sentry/webpack-plugin");

const getEnvVariable = (variable, defaultValue) =>
  process.env[variable] ?? defaultValue;

const sdkEnv = getEnvVariable("sdkEnv", "local");
const envSdkUrl = getEnvVariable("ENV_SDK_URL", "");
const envBackendUrl = getEnvVariable("ENV_BACKEND_URL", "");
const envLoggingUrl = getEnvVariable("ENV_LOGGING_URL", "");

const repoVersion = require("./package.json").version;
const majorVersion = "v" + repoVersion.split(".")[0];
const repoName = require("./package.json").name;
const repoPublicPath =
  sdkEnv === "local" ? "" : `/${repoVersion}/${majorVersion}`;

const getSdkUrl = (env, customUrl) => {
  if (customUrl) return customUrl;
  const urls = {
    prod: "https://checkout.hyperswitch.io",
    sandbox: "https://beta.hyperswitch.io",
    integ: "https://dev.hyperswitch.io",
    local: "http://localhost:9050",
  };
  return urls[env] || urls.local;
};

const sdkUrl = getSdkUrl(sdkEnv, envSdkUrl);
const backendEndPoint =
  envBackendUrl ||
  `https://${sdkEnv === "prod" ? "checkout" : "beta"}.hyperswitch.io/api`;
const confirmEndPoint =
  envBackendUrl ||
  `https://${sdkEnv === "prod" ? "api" : "sandbox"}.hyperswitch.io`;
const logEndpoint =
  envLoggingUrl ||
  `https://${sdkEnv === "prod" ? "api" : "sandbox"}.hyperswitch.io/logs/sdk`;

const enableLogging = true;
const loggingLevel = "DEBUG";
const maxLogsPushedPerEventName = 100;

module.exports = (publicPath = "auto") => {
  const entries = {
    app: "./index.js",
    HyperLoader: "./src/orca-loader/HyperLoader.bs.js",
  };
  const plugins = [
    new MiniCssExtractPlugin(),
    new CopyPlugin({
      patterns: [{ from: "public" }],
    }),
    new webpack.DefinePlugin({
      repoName: JSON.stringify(repoName),
      repoVersion: JSON.stringify(repoVersion),
      publicPath: JSON.stringify(repoPublicPath),
      sdkUrl: JSON.stringify(sdkUrl),
      backendEndPoint: JSON.stringify(backendEndPoint),
      confirmEndPoint: JSON.stringify(confirmEndPoint),
      logEndpoint: JSON.stringify(logEndpoint),
      sentryDSN: JSON.stringify(process.env.SENTRY_DSN),
      sentryScriptUrl: JSON.stringify(process.env.SENTRY_SCRIPT_URL),
      enableLogging: JSON.stringify(enableLogging),
      loggingLevel: JSON.stringify(loggingLevel),
      maxLogsPushedPerEventName: JSON.stringify(maxLogsPushedPerEventName),
    }),
    new HtmlWebpackPlugin({
      inject: false,
      template: "./public/build.html",
    }),
    new HtmlWebpackPlugin({
      // Also generate a test.html
      inject: false,
      filename: "fullscreenIndex.html",
      template: "./public/fullscreenIndexTemplate.html",
    }),
  ];

  if (process.env.NODE_ENV === "production") {
    plugins.push(
      new BundleAnalyzerPlugin({
        analyzerMode: "static",
        reportFilename: "bundle-report.html",
        openAnalyzer: false,
      })
    );
  }

  if (process.env.SENTRY_AUTH_TOKEN && process.env.IS_SENTRY_ENABLED === "true") {
    plugins.push(
      sentryWebpackPlugin({
        org: "sentry",
        project: "hyperswitch-react-sdk",
        authToken: process.env.SENTRY_AUTH_TOKEN,
        url: process.env.SENTRY_URL,
        release: {
          name: "0.2",
          uploadLegacySourcemaps: {
            paths: ["dist"],
          },
        },
      })
    );
  }

  return {
    mode: sdkEnv === "local" ? "development" : "production",
    devtool: sdkEnv === "local" ? "eval-source-map" : "source-map",
    output: {
      path:
        sdkEnv && sdkEnv !== "local"
          ? path.resolve(__dirname, "dist", sdkEnv)
          : path.resolve(__dirname, "dist"),
      clean: true,
      publicPath: `${repoPublicPath}/`,
    },
    optimization:
      sdkEnv === "local"
        ? {}
        : {
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
    plugins,
    module: {
      rules: [
        {
          test: /\.css$/i,
          use: [
            MiniCssExtractPlugin.loader,
            "css-loader",
            {
              loader: "postcss-loader",
              options: {
                postcssOptions: {
                  plugins: [[tailwindcss("./tailwind.config.js")]],
                },
              },
            },
          ],
        },
        {
          test: /\.js$/,
          exclude: /node_modules/,
          use: {
            loader: "babel-loader",
          },
        },
      ],
    },
    entry: entries,
  };
};
