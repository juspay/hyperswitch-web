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
const AddReactDisplayNamePlugin = require("babel-plugin-add-react-displayname");
const { SubresourceIntegrityPlugin } = require("webpack-subresource-integrity");

const localhostSources = [
  "http://localhost:8080",
  "http://localhost:8207",
  "http://localhost:3103",
  "http://localhost:5252",
  "http://127.0.0.1:8080",
  "http://127.0.0.1:8207",
  "http://127.0.0.1:3103",
  "http://127.0.0.1:5252",
];

// List of authorized external script sources (for Content Security Policy)
const authorizedScriptSources = [
  "'self'",
  "https://js.braintreegateway.com",
  "https://tpgw.trustpay.eu/js/v1.js",
  "https://test-tpgw.trustpay.eu/js/v1.js",
  "https://applepay.cdn-apple.com/jsapi/v1/apple-pay-sdk.js",
  "https://pay.google.com",
  "https://img.mpay.samsung.com/gsmpi/sdk/samsungpay_web_sdk.js",
  "https://apple.com/apple-pay",
  "https://x.klarnacdn.net/kp/lib/v1/api.js",
  "https://www.paypal.com/sdk/js",
  "https://sandbox.digitalwallet.earlywarning.com/web/resources/js/digitalwallet-sdk.js",
  "https://checkout.paze.com/web/resources/js/digitalwallet-sdk.js",
  "https://cdn.plaid.com/link/v2/stable/link-initialize.js",
  "https://www.sandbox.paypal.com",
  "https://www.paypal.com",
  "https://www.google.com/pay",
  "https://sandbox.secure.checkout.visa.com",
  "https://secure.checkout.visa.com",
  "https://src.mastercard.com",
  "https://sandbox.src.mastercard.com",
  "https://x.klarnacdn.net",
  "https://js.playground.klarna.com",
  "https://js.verygoodvault.com/vgs-collect/2.27.2/vgs-collect.js",
  "https://vgs-collect-keeper.apps.verygood.systems/vgs",
  "https://static-na.payments-amazon.com",
  "blob:",
  // Add other trusted sources here
];

// List of authorized external styles sources
const authorizedStyleSources = [
  "'self'",
  "'unsafe-inline'",
  "https://fonts.googleapis.com",
  "http://fonts.googleapis.com",
  "https://src.mastercard.com",
  // Add other trusted sources here
];

// List of authorized external font sources
const authorizedFontSources = [
  "'self'",
  "https://fonts.gstatic.com",
  "http://fonts.gstatic.com",
  // Add other trusted sources here
];

// List of authorized external image sources
const authorizedImageSources = [
  "'self'",
  "https://www.gstatic.com",
  "https://static.scarf.sh/a.png",
  "https://www.paypalobjects.com",
  "https://googleads.g.doubleclick.net",
  "https://www.google.com",
  "data: *",
  // Add other trusted sources here
];

// List of authorized external frame sources
const authorizedFrameSources = [
  "'self'",
  "https:",
  ...localhostSources,
  // Add other trusted sources here
];
function extractBaseDSNUrl(dsn) {
  const match = dsn.match(/^https:\/\/[^@]+@([^/]+)\//);
  if (match && match[1]) {
    return `https://${match[1]}`;
  }
  return null;
}
// List of authorized external connect sources
const authorizedConnectSources = [
  "'self'",
  "https://checkout.hyperswitch.io",
  "https://dev.hyperswitch.io",
  "https://beta.hyperswitch.io",
  "https://live.hyperswitch.io",
  "https://integ.hyperswitch.io",
  "https://integ-api.hyperswitch.io",
  "https://app.hyperswitch.io",
  "https://sandbox.hyperswitch.io",
  "https://api.hyperswitch.io",
  "https://www.google.com/pay",
  "https://pay.google.com",
  "https://google.com/pay",
  "https://www.sandbox.paypal.com",
  "https://www.paypal.com",
  "https://integ-api.hyperswitch.io",
  "https://sandbox.secure.checkout.visa.com",
  "https://secure.checkout.visa.com",
  "https://src.mastercard.com",
  "https://sandbox.src.mastercard.com",
  "https://eu.klarnaevt.com",
  "https://js.verygoodvault.com/vgs-collect/2.27.2/vgs-collect.js",
  "https://vgs-collect-keeper.apps.verygood.systems/vgs",
  "https://eu.playground.klarnaevt.com",
  "https://apay-us.amazon.com",
  extractBaseDSNUrl(process.env.SENTRY_DSN),
  ...localhostSources,
  // Add other trusted sources here
];

// Helper function to get environment variables with fallback
const getEnvVariable = (variable, defaultValue) => {
  const value = process.env[variable];
  return value && value.length > 0 ? value : defaultValue;
};

const sdkEnv = getEnvVariable("sdkEnv", "local");
const ENABLE_LOGGING = getEnvVariable("ENABLE_LOGGING", "false") === "true";
const DISABLE_CSP = getEnvVariable("DISABLE_CSP", "false") === "true";
const envSdkUrl = getEnvVariable("ENV_SDK_URL", "");
const envBackendUrl = getEnvVariable("ENV_BACKEND_URL", "");
const envLoggingUrl = getEnvVariable("ENV_LOGGING_URL", "");
const visaAPIKeyId = getEnvVariable("VISA_API_KEY_ID", "");
const visaAPICertificatePem = getEnvVariable("VISA_API_CERTIFICATE_PEM", "");
const repoVersion = getEnvVariable(
  "SDK_TAG_VERSION",
  require("./package.json").version
);

/*
* SDK Version Compatibility:

* v0: Compatible with API v1
* v1: Compatible with API v1
* v2: Compatible with API v2

* The default SDK version is "v1".
*/
const sdkVersionValue = getEnvVariable("SDK_VERSION", "v1");

// Repository info
const repoName = require("./package.json").name;
const repoPublicPath =
  sdkEnv === "local" ? "" : `/web/${repoVersion}/${sdkVersionValue}`;

// Helper function to get SDK URL based on environment
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

// Determine SDK URL
const sdkUrl = getSdkUrl(sdkEnv, envSdkUrl);

// Helper function to determine environment domains
const getEnvironmentDomain = (prodDomain, integDomain, defaultDomain) => {
  switch (sdkEnv) {
    case "prod":
      return prodDomain;
    case "integ":
      return integDomain;
    default:
      return defaultDomain;
  }
};

// Environment endpoints
const backendDomain = getEnvironmentDomain("checkout", "dev", "beta");
const confirmDomain = getEnvironmentDomain("live", "integ", "app");

// Backend and confirm endpoints
const backendEndPoint =
  envBackendUrl || `https://${backendDomain}.hyperswitch.io/api`;

const confirmEndPoint =
  envBackendUrl || `https://${confirmDomain}.hyperswitch.io/api`;

const logEndpoint = envLoggingUrl;

const loggingLevel = "DEBUG";
const maxLogsPushedPerEventName = 100;

// Function to determine the current environment type
const getEnvironmentType = (env) => {
  const envType = {
    isLocal: env === "local",
    isIntegrationEnv: env === "integ",
    isProductionEnv: env === "prod",
    isSandboxEnv: env === "sandbox" || env === "local",
  };
  return envType;
};

const { isLocal, isIntegrationEnv, isProductionEnv, isSandboxEnv } =
  getEnvironmentType(sdkEnv);

module.exports = (publicPath = "auto") => {
  const entries = {
    app: "./index.js",
    HyperLoader: "./src/hyper-loader/HyperLoader.bs.js",
    ClickToPayAuthenticationSession:
      "./src/hyper-loader/AuthenticationSessionMethods.bs.js",
  };

  const definePluginValues = {
    repoName: JSON.stringify(repoName),
    repoVersion: JSON.stringify(repoVersion),
    publicPath: JSON.stringify(repoPublicPath),
    sdkUrl: JSON.stringify(sdkUrl),
    backendEndPoint: JSON.stringify(backendEndPoint),
    confirmEndPoint: JSON.stringify(confirmEndPoint),
    logEndpoint: JSON.stringify(logEndpoint),
    sentryDSN: JSON.stringify(process.env.SENTRY_DSN),
    sentryScriptUrl: JSON.stringify(process.env.SENTRY_SCRIPT_URL),
    enableLogging: ENABLE_LOGGING,
    loggingLevel: JSON.stringify(loggingLevel),
    maxLogsPushedPerEventName: JSON.stringify(maxLogsPushedPerEventName),
    sdkVersionValue: JSON.stringify(sdkVersionValue),
    isIntegrationEnv,
    isSandboxEnv,
    isProductionEnv,
    isLocal,
    visaAPIKeyId: JSON.stringify(visaAPIKeyId),
    visaAPICertificatePem: JSON.stringify(visaAPICertificatePem),
  };

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
      // Add CSP meta tag conditionally
      meta: DISABLE_CSP
        ? {}
        : {
            "Content-Security-Policy": {
              "http-equiv": "Content-Security-Policy",
              content: `default-src 'self' ; script-src ${authorizedScriptSources.join(
                " "
              )};
                style-src ${authorizedStyleSources.join(" ")};
                frame-src ${authorizedFrameSources.join(" ")};
                img-src ${authorizedImageSources.join(" ")};
                font-src ${authorizedFontSources.join(" ")};
                connect-src ${authorizedConnectSources.join(
                  " "
                )} ${logEndpoint} ${backendEndPoint};
      `,
            },
          },
    }),
    new HtmlWebpackPlugin({
      // Also generate a test.html
      inject: true,
      filename: "fullscreenIndex.html",
      template: "./public/fullscreenIndexTemplate.html",
      // Add CSP meta tag conditionally
      meta: DISABLE_CSP
        ? {}
        : {
            "Content-Security-Policy": {
              "http-equiv": "Content-Security-Policy",
              content: `default-src 'self' ; script-src ${authorizedScriptSources.join(
                " "
              )};
          style-src ${authorizedStyleSources.join(" ")};
          frame-src ${authorizedFrameSources.join(" ")};
          img-src ${authorizedImageSources.join(" ")};
          font-src ${authorizedFontSources.join(" ")};
          connect-src ${authorizedConnectSources.join(
            " "
          )} ${logEndpoint} ${backendEndPoint};
          `,
            },
          },
    }),
    new SubresourceIntegrityPlugin({
      hashFuncNames: ["sha384"],
      enabled: process.env.NODE_ENV === "production",
    }),
    // Build-time verification plugin
    new webpack.DefinePlugin({
      // Custom verification to ensure SRI is enforced
      __VERIFY_SRI__: JSON.stringify(process.env.NODE_ENV === "production"),
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

  return {
    mode: isLocal ? "development" : "production",
    devtool: isLocal ? "cheap-module-source-map" : "source-map",
    output: {
      path: isLocal
        ? path.resolve(__dirname, "dist")
        : path.resolve(__dirname, "dist", sdkEnv, sdkVersionValue),
      crossOriginLoading: "anonymous",
      clean: true,
      publicPath: `${repoPublicPath}/`,
      hashFunction: "sha384",
    },
    optimization: isLocal
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
                  keep_fnames: true, // Prevent function names from being mangled
                  keep_classnames: true, // Prevent class names from being mangled
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
          test: /\.jsx?$/, // Matches both .js and .jsx files
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
    entry: entries,
    resolve: {
      extensions: [".js", ".jsx"],
    },
  };
};
