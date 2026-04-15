// Mock webpack DefinePlugin globals that are injected at build time.
// These values mirror the defaults from webpack.common.js definePluginValues.

// Core SDK URLs
global.sdkUrl = "https://beta.hyperswitch.io/v1";
global.publicPath = "/";

// API endpoints
global.backendEndPoint = "https://beta.hyperswitch.io";
global.confirmEndPoint = "https://beta.hyperswitch.io";
global.logEndpoint = "https://beta.hyperswitch.io/logs";

// Logging
global.enableLogging = true;
global.loggingLevel = "DEBUG";
global.maxLogsPushedPerEventName = "100";

// Sentry
global.sentryDSN = "";
global.sentryScriptUrl = "";

// Environment flags
global.isIntegrationEnv = false;
global.isSandboxEnv = false;
global.isProductionEnv = false;
global.isLocal = false;

// Repo metadata
global.repoName = "hyperswitch-web";
global.repoVersion = "0.0.0-test";

// Visa Click-to-Pay
global.visaAPIKeyId = "";
global.visaAPICertificatePem = "";
