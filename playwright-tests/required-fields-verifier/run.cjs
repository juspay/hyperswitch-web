const fs = require("node:fs");
const path = require("node:path");
const assert = require("node:assert/strict");
const { target, staticServer } = require("../required-fields-sync/fixture.cjs");
const { environment, child } = require("./environment.cjs");
const { load } = require("./contract.cjs");
const {
  loadPack,
  verifyArtifacts,
  sha256,
  validateReport,
} = require("../required-fields-sync/contract.cjs");

(async () => {
  const owned = target(),
    loaded = loadPack();
  verifyArtifacts(loaded.pack, owned.web);
  const inputPath = fs.realpathSync(process.env.RF_VERIFIER_INPUT || "");
  assert(
    inputPath.startsWith(owned.root + path.sep),
    "input must be provisioned in owned fixture",
  );
  const request = load(inputPath, loaded);
  const run = fs.mkdtempSync(path.join(owned.root, "verifier-"));
  const sdk = await staticServer(
    path.join(__dirname, "../required-fields-sync/dist/checkout-sdk"),
  );
  let demo, components;
  try {
    demo = await staticServer(
      path.join(__dirname, "../required-fields-sync/dist/checkout-demo"),
    );
    components = await staticServer(
      path.join(__dirname, "../required-fields-sync/dist/components"),
      '<!doctype html><div id="root"></div><script src="/fixture.js"></script>',
    );
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
      RF_VERIFIER_INPUT: inputPath,
      RF_FIXTURE_ORIGIN: components.origin,
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
          path.join(
            __dirname,
            "../required-fields-sync/checkout-sdk.webpack.cjs",
          ),
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
          path.join(
            __dirname,
            "../required-fields-sync/checkout-demo.webpack.cjs",
          ),
        ],
        path.join(owned.web, "Hyperswitch-React-Demo-App"),
        env,
      ),
    ]);
    assert(
      build.every((code) => code === 0),
      "checkout fixture build failed",
    );
    const artifacts = {
        node: sha256(fs.readFileSync(process.execPath)),
        sdk: sdk.seal(),
        demo: demo.seal(),
        components: components.seal(),
        sources: loaded.pack.provenance,
        companion: require("../required-fields-sync/fixture.cjs").manifest(
          __dirname,
        ),
        chromium: require("../required-fields-sync/fixture.cjs").manifest(
          path.join(owned.root, "browsers"),
        ),
      },
      digest = sha256(JSON.stringify(artifacts));
    const registration = path.join(run, "registration.json"),
      report = path.join(run, "candidate.json");
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
    const regressions = [];
    for (const [stage, config] of [
      ["browser-components", "playwright.config.ts"],
      ["checkout", "checkout.config.ts"],
    ]) {
      const stageReport = path.join(run, stage + ".json");
      const code = await child(
        [
          path.join(
            owned.web,
            "playwright-tests/node_modules/@playwright/test/cli.js",
          ),
          "test",
          "--config",
          path.join(__dirname, "../required-fields-sync", config),
        ],
        owned.web,
        { ...env, RF_REPORT_PATH: stageReport },
      );
      assert.equal(code, 0, "Step 1 browser regression failed");
      const value = validateReport(
        JSON.parse(fs.readFileSync(stageReport)),
        loaded,
      );
      assert.equal(value.status, "passed");
      regressions.push(value);
    }
    const js = require("node:child_process").spawnSync(
      process.execPath,
      [path.join(__dirname, "../required-fields-sync/run-resolver.cjs")],
      {
        cwd: owned.web,
        env,
        encoding: "utf8",
        timeout: 30000,
        maxBuffer: 65536,
      },
    );
    assert.equal(js.status, 0, "Step 1 JS resolver failed");
    const jsReport = validateReport(JSON.parse(js.stdout), loaded);
    assert.equal(jsReport.status, "passed");
    regressions.push(jsReport);
    env.RF_REGRESSION_REPORTS = path.join(run, "regressions.json");
    fs.writeFileSync(env.RF_REGRESSION_REPORTS, JSON.stringify(regressions), {
      flag: "wx",
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
    assert.deepEqual(
      require("../required-fields-sync/fixture.cjs").manifest(__dirname),
      artifacts.companion,
    );
    assert.deepEqual(
      require("../required-fields-sync/fixture.cjs").manifest(
        path.join(owned.root, "browsers"),
      ),
      artifacts.chromium,
    );
    components.verify();
    assert.equal(
      load(inputPath, loaded).request_sha256,
      request.request_sha256,
      "input changed during execution",
    );
    sdk.verify();
    demo.verify();
    verifyArtifacts(loadPack().pack, owned.web);
    if (JSON.parse(fs.readFileSync(report)).status !== "passed")
      process.exitCode = 1;
    assert.equal(process.exitCode, 0, "verifier failed");
    fs.renameSync(report, path.join(run, "report.json"));
    console.log("Checkout evidence: " + run);
  } finally {
    if (components) await components.close();
    await sdk.close();
    if (demo) await demo.close();
  }
})().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
