const fs = require("node:fs");
const path = require("node:path");
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
  const run = fs.mkdtempSync(path.join(owned.root, "components-"));
  const server = await staticServer(
    path.join(__dirname, "dist/components"),
    '<!doctype html><div id="root"></div><script src="/fixture.js"></script>',
  );
  try {
    const artifacts = server.seal(),
      digest = sha256(JSON.stringify(artifacts));
    fs.writeFileSync(
      path.join(run, "registration.json"),
      JSON.stringify(
        {
          owner: owned.owner,
          stage: "browser-components",
          origin: server.origin,
          artifact_sha256: digest,
          artifacts,
        },
        null,
        2,
      ) + "\n",
      { flag: "wx" },
    );
    const report = path.join(run, "report.json");
    const env = environment({
      REQUIRED_FIELDS_CASE_PACK: process.env.REQUIRED_FIELDS_CASE_PACK,
      PLAYWRIGHT_BROWSERS_PATH: path.join(owned.root, "browsers"),
      RF_FIXTURE_ORIGIN: server.origin,
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
        path.join(__dirname, "playwright.config.ts"),
      ],
      owned.web,
      env,
    );
    server.verify();
    verifyArtifacts(loadPack().pack, owned.web);
    if (
      validateReport(JSON.parse(fs.readFileSync(report)), loaded).status !==
      "passed"
    )
      process.exitCode = 1;
    console.log("Component evidence: " + run);
  } finally {
    await server.close();
  }
})().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
