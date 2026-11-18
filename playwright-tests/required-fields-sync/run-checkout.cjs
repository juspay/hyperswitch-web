const fs = require("node:fs");
const path = require("node:path");
const assert = require("node:assert/strict");
const { target, child, staticServer, environment } = require("./fixture.cjs");
const {
  loadPack,
  verifyArtifacts,
  sha256,
  validateReport,
} = require("./contract.cjs");

(async () => {
  const owned = target(),
    loaded = loadPack();
  verifyArtifacts(loaded.pack, owned.web);
  const run = fs.mkdtempSync(path.join(owned.root, "checkout-"));
  const sdk = await staticServer(path.join(__dirname, "dist/checkout-sdk"));
  let demo;
  try {
    demo = await staticServer(path.join(__dirname, "dist/checkout-demo"));
    const inputs = {
      owner: owned.owner,
      stage: "checkout",
      sdk_origin: sdk.origin,
      demo_origin: demo.origin,
      router_origin: "https://required-fields-router.invalid",
    };
    fs.writeFileSync(
      path.join(run, "target.json"),
      JSON.stringify(inputs, null, 2) + "\n",
      { flag: "wx" },
    );
    const env = environment({
      SDK_VERSION: "v1",
      ENV_SDK_URL: sdk.origin,
      ENV_BACKEND_URL: inputs.router_origin,
      HYPERSWITCH_CLIENT_URL: sdk.origin,
      SELF_SERVER_URL: "",
      TEST_ENV: "local",
      LOCAL_API_URL: inputs.router_origin,
      SDK_URL: sdk.origin,
      CLIENT_BASE_URL: demo.origin,
      DEMO_SERVER_URL: demo.origin,
      REQUIRED_FIELDS_CASE_PACK: process.env.REQUIRED_FIELDS_CASE_PACK,
      PLAYWRIGHT_BROWSERS_PATH: path.join(owned.root, "browsers"),
    });
    const build = await Promise.all([
      child(
        [
          path.join(owned.web, "node_modules/webpack-cli/bin/cli.js"),
          "--config",
          path.join(__dirname, "checkout-sdk.webpack.cjs"),
        ],
        owned.web,
        env,
      ),
      child(
        [
          path.join(
            owned.web,
            "Hyperswitch-React-Demo-App/node_modules/webpack-cli/bin/cli.js",
          ),
          "--config",
          path.join(__dirname, "checkout-demo.webpack.cjs"),
        ],
        path.join(owned.web, "Hyperswitch-React-Demo-App"),
        env,
      ),
    ]);
    assert(
      build.every((code) => code === 0),
      "checkout fixture build failed",
    );
    const artifacts = { sdk: sdk.seal(), demo: demo.seal() },
      digest = sha256(JSON.stringify(artifacts));
    const registration = path.join(run, "registration.json"),
      report = path.join(run, "report.json");
    fs.writeFileSync(
      registration,
      JSON.stringify(
        { ...inputs, artifact_sha256: digest, artifacts },
        null,
        2,
      ) + "\n",
      { flag: "wx" },
    );
    Object.assign(env, {
      RF_RUN_REGISTRATION: registration,
      RF_EXECUTED_BUNDLE_SHA256: digest,
      RF_REPORT_PATH: report,
      RF_OUTPUT_DIR: path.join(run, "test-results"),
    });
    process.exitCode = await child(
      [
        path.join(
          owned.web,
          "playwright-tests/node_modules/@playwright/test/cli.js",
        ),
        "test",
        "--config",
        path.join(__dirname, "checkout.config.ts"),
      ],
      owned.web,
      env,
    );
    sdk.verify();
    demo.verify();
    verifyArtifacts(loadPack().pack, owned.web);
    if (
      validateReport(JSON.parse(fs.readFileSync(report)), loaded).status !==
      "passed"
    )
      process.exitCode = 1;
    console.log("Checkout evidence: " + run);
  } finally {
    await sdk.close();
    if (demo) await demo.close();
  }
})().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
