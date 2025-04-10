// webpack.config.js
const path = require("path");
const webpack = require("webpack");
const dotenv = require("dotenv").config();
const packageJson = require("./package.json");

// Webpack plugins
const MiniCssExtractPlugin = require("mini-css-extract-plugin");
const CopyPlugin = require("copy-webpack-plugin");
const HtmlWebpackPlugin = require("html-webpack-plugin");
const TerserPlugin = require("terser-webpack-plugin");
const { BundleAnalyzerPlugin } = require("webpack-bundle-analyzer");
const { sentryWebpackPlugin } = require("@sentry/webpack-plugin");
const AddReactDisplayNamePlugin = require("babel-plugin-add-react-displayname");
const { SubresourceIntegrityPlugin } = require("webpack-subresource-integrity");
const tailwindcss = require("tailwindcss");

// Import configurations
const {
  getContentSecurityPolicy,
  getAuthorizedSources,
} = require("./webpack/content-security-policy");
const { getEnvironmentConfig } = require("./webpack/environment-config");

/**
 * Main webpack configuration
 * @param {string} [publicPath="auto"] - The public path for assets
 * @returns {Object} webpack configuration
 */
module.exports = (publicPath = "auto") => {
  // Environment and config variables
  const sdkEnv = process.env.sdkEnv || "local";
  const ENABLE_LOGGING = process.env.ENABLE_LOGGING === "true";
  const sdkVersionValue = process.env.SDK_VERSION || "v1";
  const NODE_ENV = process.env.NODE_ENV || "development";
  const IS_PRODUCTION = NODE_ENV === "production";
  const IS_LOCAL = sdkEnv === "local";

  // Get environment configuration
  const {
    repoPublicPath,
    sdkUrl,
    backendEndPoint,
    confirmEndPoint,
    logEndpoint,
    isProductionEnv,
    isIntegrationEnv,
    isSandboxEnv,
  } = getEnvironmentConfig({
    sdkEnv,
    sdkVersionValue,
    repoVersion: packageJson.version,
    envSdkUrl: process.env.ENV_SDK_URL,
    envBackendUrl: process.env.ENV_BACKEND_URL,
    envLoggingUrl: process.env.ENV_LOGGING_URL,
  });

  // Get Content Security Policy sources
  const authorizedSources = getAuthorizedSources();
  const cspMetaTag = getContentSecurityPolicy({
    ...authorizedSources,
    logEndpoint,
  });

  // Define entry points
  const entries = {
    app: "./index.js",
    HyperLoader: "./src/hyper-loader/HyperLoader.bs.js",
  };

  // Define environment variables for DefinePlugin
  const definePluginValues = {
    repoName: JSON.stringify(packageJson.name),
    repoVersion: JSON.stringify(packageJson.version),
    publicPath: JSON.stringify(repoPublicPath),
    sdkUrl: JSON.stringify(sdkUrl),
    backendEndPoint: JSON.stringify(backendEndPoint),
    confirmEndPoint: JSON.stringify(confirmEndPoint),
    logEndpoint: JSON.stringify(logEndpoint),
    sentryDSN: JSON.stringify(process.env.SENTRY_DSN),
    sentryScriptUrl: JSON.stringify(process.env.SENTRY_SCRIPT_URL),
    enableLogging: ENABLE_LOGGING,
    loggingLevel: JSON.stringify("DEBUG"),
    maxLogsPushedPerEventName: JSON.stringify(100),
    sdkVersionValue: JSON.stringify(sdkVersionValue),
    isIntegrationEnv,
    isSandboxEnv,
    isProductionEnv,
  };

  // Configure plugins
  const plugins = [
    new MiniCssExtractPlugin(),
    new CopyPlugin({
      patterns: [{ from: "public" }],
    }),
    new webpack.DefinePlugin(definePluginValues),
    new HtmlWebpackPlugin({
      inject: true,
      template: "./public/build.html",
      chunks: ["app"],
      scriptLoading: "blocking",
      meta: {
        "Content-Security-Policy": {
          "http-equiv": "Content-Security-Policy",
          content: cspMetaTag,
        },
      },
    }),
    new HtmlWebpackPlugin({
      inject: true,
      filename: "fullscreenIndex.html",
      template: "./public/fullscreenIndexTemplate.html",
      meta: {
        "Content-Security-Policy": {
          "http-equiv": "Content-Security-Policy",
          content: cspMetaTag,
        },
      },
    }),
    new SubresourceIntegrityPlugin({
      hashFuncNames: ["sha384"],
      enabled: IS_PRODUCTION,
    }),
    new webpack.DefinePlugin({
      __VERIFY_SRI__: JSON.stringify(IS_PRODUCTION),
    }),
  ];

  // Add production-only plugins
  if (IS_PRODUCTION) {
    plugins.push(
      new BundleAnalyzerPlugin({
        analyzerMode: "static",
        reportFilename: "bundle-report.html",
        openAnalyzer: false,
      })
    );
  }

  // Add Sentry plugin if enabled
  if (
    process.env.SENTRY_AUTH_TOKEN &&
    process.env.IS_SENTRY_ENABLED === "true"
  ) {
    plugins.push(
      sentryWebpackPlugin({
        org: "hyperswitch",
        project: "hyperswitch-web-react",
        authToken: process.env.SENTRY_AUTH_TOKEN,
        url: process.env.SENTRY_URL,
        release: {
          name: "0.3",
          uploadLegacySourcemaps: {
            paths: ["dist"],
          },
        },
      })
    );
  }

  // Configure optimization
  const optimization = IS_LOCAL
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
              mangle: {
                keep_fnames: true,
                keep_classnames: true,
              },
            },
          }),
        ],
      };

  // Return webpack configuration
  return {
    mode: IS_LOCAL ? "development" : "production",
    devtool: IS_LOCAL ? "cheap-module-source-map" : "source-map",
    entry: entries,
    output: {
      path: IS_LOCAL
        ? path.resolve(__dirname, "dist")
        : path.resolve(__dirname, "dist", sdkEnv, sdkVersionValue),
      crossOriginLoading: "anonymous",
      clean: true,
      publicPath: `${repoPublicPath}/`,
      hashFunction: "sha384",
    },
    optimization,
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
          test: /\.jsx?$/,
          exclude: /node_modules/,
          use: {
            loader: "babel-loader",
            options: {
              presets: ["@babel/preset-env", "@babel/preset-react"],
              plugins: [AddReactDisplayNamePlugin],
            },
          },
        },
      ],
    },
    resolve: {
      extensions: [".js", ".jsx"],
    },
  };
};
