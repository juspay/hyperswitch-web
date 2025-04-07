// webpack/content-security-policy.js

/**
 * Get localhost sources for development
 * @returns {Array} Localhost sources
 */
function getLocalhostSources() {
  return [
    "http://localhost:8080",
    "http://localhost:8207",
    "http://localhost:3103",
    "http://localhost:5252",
    "http://127.0.0.1:8080",
    "http://127.0.0.1:8207",
    "http://127.0.0.1:3103",
    "http://127.0.0.1:5252",
  ];
}

/**
 * Get authorized sources for Content Security Policy
 * @returns {Object} Authorized sources
 */
function getAuthorizedSources() {
  const localhostSources = getLocalhostSources();

  return {
    scriptSources: [
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
    ],
    styleSources: [
      "'self'",
      "'unsafe-inline'",
      "https://fonts.googleapis.com",
      "http://fonts.googleapis.com",
      "https://src.mastercard.com",
    ],
    fontSources: [
      "'self'",
      "https://fonts.gstatic.com",
      "http://fonts.gstatic.com",
    ],
    imageSources: [
      "'self'",
      "https://www.gstatic.com",
      "https://static.scarf.sh/a.png",
      "https://www.paypalobjects.com",
      "https://googleads.g.doubleclick.net",
      "https://www.google.com",
      "data: *",
    ],
    frameSources: [
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
      "https://pay.google.com",
      "https://www.sandbox.paypal.com",
      "https://www.paypal.com",
      "https://sandbox.src.mastercard.com",
      "https://src.mastercard.com",
      "https://sandbox.secure.checkout.visa.com",
      "https://secure.checkout.visa.com",
      "https://checkout.wallet.cat.earlywarning.io/",
      "https://ndm-prev.3dss-non-prod.cloud.netcetera.com/",
      ...localhostSources,
    ],
    connectSources: [
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
      ...localhostSources,
    ],
  };
}

/**
 * Generate Content Security Policy meta tag content
 * @param {Object} sources - Authorized sources
 * @param {string} logEndpoint - Logging endpoint
 * @returns {string} CSP meta tag content
 */
function getContentSecurityPolicy({
  scriptSources,
  styleSources,
  frameSources,
  imageSources,
  fontSources,
  connectSources,
  logEndpoint,
}) {
  return `default-src 'self'; 
            script-src ${scriptSources.join(" ")}; 
            style-src ${styleSources.join(" ")};
            frame-src ${frameSources.join(" ")};
            img-src ${imageSources.join(" ")};
            font-src ${fontSources.join(" ")}; 
            connect-src ${connectSources.join(" ")} ${logEndpoint};
    `;
}

module.exports = {
  getAuthorizedSources,
  getContentSecurityPolicy,
};
