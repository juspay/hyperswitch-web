/**
 * Get environment configuration based on the SDK environment
 * @param {Object} options - Configuration options
 * @returns {Object} Environment configuration
 */
function getEnvironmentConfig({
  sdkEnv,
  sdkVersion,
  repoVersion,
  envSdkUrl,
  envBackendUrl,
  envLoggingUrl,
}) {
  // Repository public path
  const repoPublicPath =
    sdkEnv === "local" ? "" : `/web/${repoVersion}/${sdkVersion}`;

  // Get SDK URL based on environment
  const sdkUrl = getSdkUrl(sdkEnv, envSdkUrl);

  // Environment domains
  const backendDomain = getEnvironmentDomain(sdkEnv, "checkout", "dev", "beta");
  const confirmDomain = getEnvironmentDomain(sdkEnv, "live", "integ", "app");

  // Backend and confirm endpoints
  const backendEndPoint =
    envBackendUrl || `https://${backendDomain}.hyperswitch.io/api`;
  const confirmEndPoint =
    envBackendUrl || `https://${confirmDomain}.hyperswitch.io/api`;
  const logEndpoint = envLoggingUrl;

  // Environment type flags
  const envType = getEnvironmentType(sdkEnv);

  return {
    repoPublicPath,
    sdkUrl,
    backendEndPoint,
    confirmEndPoint,
    logEndpoint,
    ...envType,
  };
}

/**
 * Get SDK URL based on environment
 * @param {string} env - SDK environment
 * @param {string} customUrl - Custom SDK URL
 * @returns {string} SDK URL
 */
function getSdkUrl(env, customUrl) {
  if (customUrl) return customUrl;

  const urls = {
    prod: "https://checkout.hyperswitch.io",
    sandbox: "https://beta.hyperswitch.io",
    integ: "https://dev.hyperswitch.io",
    local: "http://localhost:9050",
  };

  return urls[env] || urls.local;
}

/**
 * Determine environment domain
 * @param {string} env - SDK environment
 * @param {string} prodDomain - Production domain
 * @param {string} integDomain - Integration domain
 * @param {string} defaultDomain - Default domain
 * @returns {string} Domain
 */
function getEnvironmentDomain(env, prodDomain, integDomain, defaultDomain) {
  switch (env) {
    case "prod":
      return prodDomain;
    case "integ":
      return integDomain;
    default:
      return defaultDomain;
  }
}

/**
 * Determine the current environment type
 * @param {string} env - SDK environment
 * @returns {Object} Environment type flags
 */
function getEnvironmentType(env) {
  return {
    isLocal: env === "local",
    isIntegrationEnv: env === "integ",
    isProductionEnv: env === "prod",
    isSandboxEnv: env === "sandbox" || env === "local",
  };
}

module.exports = {
  getEnvironmentConfig,
};
