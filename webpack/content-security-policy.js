/**
 * CSP domain configuration
 * Organized by service provider to make maintenance easier
 */
const CSP_DOMAINS = {
  hyperswitch: [
    "checkout.hyperswitch.io",
    "dev.hyperswitch.io",
    "beta.hyperswitch.io",
    "live.hyperswitch.io",
    "integ.hyperswitch.io",
    "integ-api.hyperswitch.io",
    "app.hyperswitch.io",
    "sandbox.hyperswitch.io",
    "api.hyperswitch.io",
  ],
  payment: {
    google: ["pay.google.com", "google.com/pay", "www.google.com/pay"],
    paypal: ["www.sandbox.paypal.com", "www.paypal.com"],
    apple: ["apple.com/apple-pay", "applepay.cdn-apple.com"],
    visa: ["sandbox.secure.checkout.visa.com", "secure.checkout.visa.com"],
    mastercard: ["src.mastercard.com", "sandbox.src.mastercard.com"],
    samsung: ["img.mpay.samsung.com"],
    klarna: ["x.klarnacdn.net"],
    trustpay: ["tpgw.trustpay.eu", "test-tpgw.trustpay.eu"],
    paze: ["checkout.paze.com"],
    earlywarning: [
      "sandbox.digitalwallet.earlywarning.com",
      "checkout.wallet.cat.earlywarning.io",
    ],
  },
  thirdParty: {
    fonts: ["fonts.googleapis.com", "fonts.gstatic.com"],
    plaid: ["cdn.plaid.com"],
    braintree: ["js.braintreegateway.com"],
    netcetera: ["ndm-prev.3dss-non-prod.cloud.netcetera.com"],
    analytics: [
      "static.scarf.sh",
      "googleads.g.doubleclick.net",
      "www.gstatic.com",
    ],
  },
};

/**
 * Get localhost sources for development
 * @returns {Array} Localhost sources
 */
function getLocalhostSources() {
  const ports = [8080, 8207, 3103, 5252];
  const hosts = ["localhost", "127.0.0.1"];

  return hosts.flatMap((host) => ports.map((port) => `http://${host}:${port}`));
}

/**
 * Format domain list to include protocol
 * @param {Array} domains - List of domains
 * @param {String} protocol - Protocol to use (defaults to https)
 * @returns {Array} Formatted domain URLs
 */
function formatDomains(domains, protocol = "https") {
  return domains.map((domain) => `${protocol}://${domain}`);
}

/**
 * Format script URLs for specific paths
 * @param {Object} config - Configuration with domains and paths
 * @returns {Array} Formatted script URLs
 */
function formatScriptUrls(config) {
  const urls = [];

  // Process domains with specific script paths
  if (config.domains && config.paths) {
    const domains = Array.isArray(config.domains)
      ? config.domains
      : [config.domains];
    const paths = Array.isArray(config.paths) ? config.paths : [config.paths];

    domains.forEach((domain) => {
      paths.forEach((path) => {
        urls.push(`https://${domain}${path}`);
      });
    });
  }

  return urls;
}

/**
 * Get authorized sources for Content Security Policy
 * @param {Object} options - Configuration options
 * @returns {Object} Authorized sources
 */
function getAuthorizedSources(options = {}) {
  const localhostSources = getLocalhostSources();
  const { additionalSources = {} } = options;

  // Default sources that should always be included
  const defaultSources = {
    script: ["'self'"],
    style: ["'self'", "'unsafe-inline'"],
    font: ["'self'"],
    image: ["'self'", "data: *"],
    frame: ["'self'"],
    connect: ["'self'"],
  };

  // Build script sources
  const scriptSources = [
    ...defaultSources.script,
    ...formatDomains(CSP_DOMAINS.hyperswitch),
    ...formatDomains(CSP_DOMAINS.payment.google),
    ...formatDomains(CSP_DOMAINS.payment.paypal),
    ...formatDomains(CSP_DOMAINS.payment.apple),
    ...formatDomains(CSP_DOMAINS.payment.visa),
    ...formatDomains(CSP_DOMAINS.payment.mastercard),
    ...formatScriptUrls({
      domains: CSP_DOMAINS.payment.samsung,
      paths: ["/gsmpi/sdk/samsungpay_web_sdk.js"],
    }),
    ...formatScriptUrls({
      domains: CSP_DOMAINS.payment.klarna,
      paths: ["/kp/lib/v1/api.js"],
    }),
    ...formatScriptUrls({
      domains: CSP_DOMAINS.payment.paypal,
      paths: ["/sdk/js"],
    }),
    ...formatScriptUrls({
      domains: CSP_DOMAINS.payment.earlywarning,
      paths: ["/web/resources/js/digitalwallet-sdk.js"],
    }),
    ...formatScriptUrls({
      domains: CSP_DOMAINS.payment.paze,
      paths: ["/web/resources/js/digitalwallet-sdk.js"],
    }),
    ...formatScriptUrls({
      domains: CSP_DOMAINS.thirdParty.plaid,
      paths: ["/link/v2/stable/link-initialize.js"],
    }),
    ...formatScriptUrls({
      domains: CSP_DOMAINS.payment.trustpay,
      paths: ["/js/v1.js"],
    }),
    ...formatScriptUrls({
      domains: CSP_DOMAINS.payment.apple,
      paths: ["/jsapi/v1/apple-pay-sdk.js"],
    }),
    ...formatDomains(CSP_DOMAINS.thirdParty.braintree),
    ...(additionalSources.script || []),
  ];

  // Build style sources
  const styleSources = [
    ...defaultSources.style,
    ...formatDomains(CSP_DOMAINS.thirdParty.fonts, "https"),
    ...formatDomains(CSP_DOMAINS.thirdParty.fonts, "http"),
    ...formatDomains([CSP_DOMAINS.payment.mastercard[0]]),
    ...(additionalSources.style || []),
  ];

  // Build font sources
  const fontSources = [
    ...defaultSources.font,
    ...formatDomains(CSP_DOMAINS.thirdParty.fonts, "https"),
    ...formatDomains(CSP_DOMAINS.thirdParty.fonts, "http"),
    ...(additionalSources.font || []),
  ];

  // Build image sources
  const imageSources = [
    ...defaultSources.image,
    ...formatDomains(CSP_DOMAINS.thirdParty.analytics),
    ...formatDomains(["www.paypalobjects.com", "www.google.com"]),
    ...(additionalSources.image || []),
  ];

  // Build frame sources
  const frameSources = [
    ...defaultSources.frame,
    ...formatDomains(CSP_DOMAINS.hyperswitch),
    ...formatDomains(CSP_DOMAINS.payment.google),
    ...formatDomains(CSP_DOMAINS.payment.paypal),
    ...formatDomains(CSP_DOMAINS.payment.mastercard),
    ...formatDomains(CSP_DOMAINS.payment.visa),
    ...formatDomains([CSP_DOMAINS.payment.earlywarning[1]]),
    ...formatDomains([CSP_DOMAINS.thirdParty.netcetera[0]]),
    ...localhostSources,
    ...(additionalSources.frame || []),
  ];

  // Build connect sources
  const connectSources = [
    ...defaultSources.connect,
    ...formatDomains(CSP_DOMAINS.hyperswitch),
    ...formatDomains(CSP_DOMAINS.payment.google),
    ...formatDomains(CSP_DOMAINS.payment.paypal),
    ...formatDomains(CSP_DOMAINS.payment.visa),
    ...formatDomains(CSP_DOMAINS.payment.mastercard),
    ...localhostSources,
    ...(additionalSources.connect || []),
  ];

  return {
    scriptSources,
    styleSources,
    fontSources,
    imageSources,
    frameSources,
    connectSources,
  };
}

/**
 * Generate Content Security Policy meta tag content
 * @param {Object} options - Options including sources and log endpoint
 * @returns {string} CSP meta tag content
 */
function getContentSecurityPolicy(options = {}) {
  const {
    scriptSources,
    styleSources,
    frameSources,
    imageSources,
    fontSources,
    connectSources,
    logEndpoint = "",
  } = options;

  // Ensure all arrays exist to avoid issues
  const scripts = scriptSources || [];
  const styles = styleSources || [];
  const frames = frameSources || [];
  const images = imageSources || [];
  const fonts = fontSources || [];
  const connects = [...(connectSources || [])];

  // Add log endpoint to connect-src if provided
  if (logEndpoint && logEndpoint.trim() !== "") {
    connects.push(logEndpoint);
  }

  // Format the CSP directives properly
  return [
    "default-src 'self';",
    `script-src ${scripts.join(" ")};`,
    `style-src ${styles.join(" ")};`,
    `frame-src ${frames.join(" ")};`,
    `img-src ${images.join(" ")};`,
    `font-src ${fonts.join(" ")};`,
    `connect-src ${connects.join(" ")};`,
  ].join(" ");
}

module.exports = {
  getAuthorizedSources,
  getContentSecurityPolicy,
  CSP_DOMAINS,
};
