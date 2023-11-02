const webpack = require("webpack");
const path = require("path");
const tailwindcss = require("tailwindcss");
const MiniCssExtractPlugin = require("mini-css-extract-plugin");
const CopyPlugin = require("copy-webpack-plugin");
const HtmlWebpackPlugin = require("html-webpack-plugin");
const TerserPlugin = require("terser-webpack-plugin");
const BundleAnalyzerPlugin =
  require("webpack-bundle-analyzer").BundleAnalyzerPlugin;
const { sentryWebpackPlugin } = require("@sentry/webpack-plugin");

//git rev-parse --abbrev-ref HEAD
let repoVersion = require("./package.json").version;
let majorVersion = "v" + repoVersion.split(".")[0];

let repoName = require("./package.json").name;
let repoPublicPath = `/${repoVersion}/${majorVersion}`;

let branchName = require("child_process")
  .execSync("git rev-parse --abbrev-ref HEAD")
  .toString()
  .trim();

const sdkEnv = process.env.sdkEnv;

let sdkUrl =
  sdkEnv === "prod"
    ? "https://checkout.hyperswitch.io"
    : sdkEnv === "sandbox"
    ? "https://beta.hyperswitch.io"
    : sdkEnv === "integ"
    ? "https://dev.hyperswitch.io"
    : "http://localhost:9050";

let backendEndPoint =
  sdkEnv === "prod"
    ? "https://checkout.hyperswitch.io/api"
    : sdkEnv === "sandbox"
    ? "https://beta.hyperswitch.io/api"
    : sdkEnv === "integ"
    ? "https://integ-api.hyperswitch.io"
    : "https://beta.hyperswitch.io/api";

let logEndpoint =
  sdkEnv === "prod"
    ? "https://api.hyperswitch.io/sdk-logs"
    : "https://sandbox.juspay.io/godel/analytics";

module.exports = (publicPath = "auto") => {
  let entries = {
    app: "./index.js",
    HyperLoader: "./src/orca-loader/HyperLoader.bs.js",
  };
  return {
    mode: "development",
    devtool: "source-map",
    output: {
      path:
        sdkEnv && sdkEnv !== "local"
          ? path.resolve(__dirname, "dist", sdkEnv)
          : path.resolve(__dirname, "dist"),
      clean: true,
      publicPath: `${repoPublicPath}/`,
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
        // For webpack@5 you can use the `...` syntax to extend existing minimizers (i.e. `terser-webpack-plugin`), uncomment the next line
        // `...`,
        // new CssMinimizerPlugin(),
      ],
    },
    plugins: [
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
        logEndpoint: JSON.stringify(logEndpoint),
        sentryDSN: JSON.stringify(process.env.SENTRY_DSN),
        sentryScriptUrl: JSON.stringify(process.env.SENTRY_SCRIPT_URL),
      }),
      new HtmlWebpackPlugin({
        inject: false,
        template: "./public/build.html",
      }),
      new BundleAnalyzerPlugin({
        analyzerMode: "static",
        reportFilename: "bundle-report.html",
        openAnalyzer: false,
      }),
      // new webpack.HTMLInjectPlugin({
      //   publicPath: JSON.stringify(repoVersion),
      // }),
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
      }),
    ],
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
      ],
    },
    entry: entries,
  };
};
