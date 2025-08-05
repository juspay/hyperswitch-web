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

const LOCALHOST_SOURCES = [
  "http://localhost:8080",
  "http://localhost:8207",
  "http://localhost:3103",
  "http://localhost:5252",
  "http://127.0.0.1:8080",
  "http://127.0.0.1:8207",
  "http://127.0.0.1:3103",
  "http://127.0.0.1:5252",
];

const CSP_SOURCES = {
  scripts: [
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
    "blob:",
  ],

  styles: [
    "'self'",
    "'unsafe-inline'",
    "https://fonts.googleapis.com",
    "http://fonts.googleapis.com",
    "https://src.mastercard.com",
  ],

  fonts: ["'self'", "https://fonts.gstatic.com", "http://fonts.gstatic.com"],

  images: [
    "'self'",
    "https://www.gstatic.com",
    "https://static.scarf.sh/a.png",
    "https://www.paypalobjects.com",
    "https://googleads.g.doubleclick.net",
    "https://www.google.com",
    "data: *",
  ],

  frames: ["'self'", "https:", ...LOCALHOST_SOURCES],

  connect: [
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
    ...LOCALHOST_SOURCES,
  ],
};

const SDK_URLS = {
  prod: "https://checkout.hyperswitch.io",
  sandbox: "https://beta.hyperswitch.io",
  integ: "https://dev.hyperswitch.io",
  local: "http://localhost:9050",
};

const LOGGING_CONFIG = {
  level: "DEBUG",
  maxLogsPushedPerEventName: 100,
};

const getEnvVariable = (variable, defaultValue) => {
  const value = process.env[variable];
  return value && value.length > 0 ? value : defaultValue;
};

const extractBaseDSNUrl = (dsn) => {
  const match = dsn?.match(/^https:\/\/[^@]+@([^/]+)\//);
  return match?.[1] ? `https://${match[1]}` : null;
};

const getSdkUrl = (env, customUrl) => {
  return customUrl || SDK_URLS[env] || SDK_URLS.local;
};

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

const getEnvironmentType = (env) => ({
  isLocal: env === "local",
  isIntegrationEnv: env === "integ",
  isProductionEnv: env === "prod",
  isSandboxEnv: env === "sandbox" || env === "local",
});

const generateCSPPolicy = (sources, logEndpoint, backendEndPoint) => {
  const sentryDSN = extractBaseDSNUrl(process.env.SENTRY_DSN);
  const connectSources = [...sources.connect];

  if (sentryDSN) connectSources.push(sentryDSN);

  return [
    `default-src 'self'`,
    `script-src ${sources.scripts.join(" ")}`,
    `style-src ${sources.styles.join(" ")}`,
    `frame-src ${sources.frames.join(" ")}`,
    `img-src ${sources.images.join(" ")}`,
    `font-src ${sources.fonts.join(" ")}`,
    `connect-src ${connectSources.join(" ")} ${logEndpoint} ${backendEndPoint}`,
  ].join("; ");
};

const sdkEnv = getEnvVariable("sdkEnv", "local");
const ENABLE_LOGGING = getEnvVariable("ENABLE_LOGGING", "false") === "true";
const DISABLE_CSP = getEnvVariable("DISABLE_CSP", "false") === "true";

const envSdkUrl = getEnvVariable("ENV_SDK_URL", "");
const envBackendUrl = getEnvVariable("ENV_BACKEND_URL", "");
const envLoggingUrl = getEnvVariable("ENV_LOGGING_URL", "");
const sdkUrl = getSdkUrl(sdkEnv, envSdkUrl);

const visaAPIKeyId = getEnvVariable("VISA_API_KEY_ID", "");
const visaAPICertificatePem = getEnvVariable("VISA_API_CERTIFICATE_PEM", "");

const repoVersion = getEnvVariable(
  "SDK_TAG_VERSION",
  require("./package.json").version
);
const sdkVersionValue = getEnvVariable("SDK_VERSION", "v1");
const repoName = require("./package.json").name;
const repoPublicPath =
  sdkEnv === "local" ? "" : `/web/${repoVersion}/${sdkVersionValue}`;

const backendDomain = getEnvironmentDomain("checkout", "dev", "beta");
const confirmDomain = getEnvironmentDomain("live", "integ", "app");
const backendEndPoint =
  envBackendUrl || `https://${backendDomain}.hyperswitch.io/api`;
const confirmEndPoint =
  envBackendUrl || `https://${confirmDomain}.hyperswitch.io/api`;
const logEndpoint = envLoggingUrl;

const { isLocal, isIntegrationEnv, isProductionEnv, isSandboxEnv } =
  getEnvironmentType(sdkEnv);

const createDefinePluginValues = () => ({
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
  loggingLevel: JSON.stringify(LOGGING_CONFIG.level),
  maxLogsPushedPerEventName: JSON.stringify(
    LOGGING_CONFIG.maxLogsPushedPerEventName
  ),
  sdkVersionValue: JSON.stringify(sdkVersionValue),
  isIntegrationEnv,
  isSandboxEnv,
  isProductionEnv,
  isLocal,
  visaAPIKeyId: JSON.stringify(visaAPIKeyId),
  visaAPICertificatePem: JSON.stringify(visaAPICertificatePem),
});

const createHtmlPlugin = ({ filename = "index.html", template, chunks }) => {
  const cspPolicy = generateCSPPolicy(
    CSP_SOURCES,
    logEndpoint,
    backendEndPoint
  );

  const config = {
    inject: true,
    template,
    scriptLoading: "blocking",
    meta: DISABLE_CSP
      ? {}
      : {
          "Content-Security-Policy": {
            "http-equiv": "Content-Security-Policy",
            content: cspPolicy,
          },
        },
  };

  if (filename !== "index.html") {
    config.filename = filename;
  }

  if (chunks) {
    config.chunks = chunks;
  }

  return new HtmlWebpackPlugin(config);
};

const createBasePlugins = () => [
  new MiniCssExtractPlugin(),
  new CopyPlugin({
    patterns: [{ from: "public" }],
  }),
  new webpack.DefinePlugin(createDefinePluginValues()),

  createHtmlPlugin({
    template: "./public/build.html",
    chunks: ["app"],
  }),

  createHtmlPlugin({
    filename: "fullscreenIndex.html",
    template: "./public/fullscreenIndexTemplate.html",
  }),

  new SubresourceIntegrityPlugin({
    hashFuncNames: ["sha384"],
    enabled: true,
  }),

  new webpack.DefinePlugin({
    __VERIFY_SRI__: JSON.stringify(true),
  }),
];

const addConditionalPlugins = (plugins) => {
  plugins.push(
    new BundleAnalyzerPlugin({
      analyzerMode: "static",
      reportFilename: "bundle-report.html",
      openAnalyzer: false,
    })
  );

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

  return plugins;
};

const createOptimization = () => {
  if (isLocal) return {};

  return {
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
};

const createModuleRules = () => ({
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
});

module.exports = (publicPath = "auto") => {
  const entries = {
    app: "./index.js",
    HyperLoader: "./src/hyper-loader/HyperLoader.bs.js",
  };

  const basePlugins = createBasePlugins();
  const plugins = addConditionalPlugins(basePlugins);

  return {
    mode: isLocal ? "development" : "production",
    devtool: isLocal ? "cheap-module-source-map" : "source-map",

    entry: entries,

    output: {
      path: isLocal
        ? path.resolve(__dirname, "dist")
        : path.resolve(__dirname, "dist", sdkEnv, sdkVersionValue),
      crossOriginLoading: "anonymous",
      clean: true,
      publicPath: `${repoPublicPath}/`,
      hashFunction: "sha384",
    },

    optimization: createOptimization(),
    plugins,
    module: createModuleRules(),

    resolve: {
      extensions: [".js", ".jsx"],
    },
  };
};
