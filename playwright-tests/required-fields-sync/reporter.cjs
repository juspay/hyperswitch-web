const fs = require("node:fs");
const { loadPack, makeReport, stageIds } = require("./contract.cjs");
module.exports = class ContractReporter {
  constructor(options = {}) {
    this.stage = options.stage || "browser-components";
    this.results = new Map();
    this.browsers = new Set();
  }
  onTestEnd(test, result) {
    const id = test.title.split(" ")[0];
    for (const a of test.annotations)
      if (a.type === "browser-version") this.browsers.add(a.description);
    if (this.results.has(id))
      throw new Error(`Duplicate contract result: ${id}`);
    this.results.set(id, {
      id,
      status:
        result.status === "passed"
          ? "passed"
          : result.status === "skipped"
            ? "not_run"
            : "failed",
      detail: `Playwright ${result.status}; ${result.duration}ms`,
    });
  }
  async onEnd() {
    const loaded = loadPack();
    const stage = this.stage;
    const ids = stageIds(loaded.pack, stage);
    for (const id of this.results.keys())
      if (!ids.includes(id))
        throw new Error(`Undeclared contract result: ${id}`);
    const results = ids.map(
      (id) =>
        this.results.get(id) || {
          id,
          status: "not_run",
          detail: "no test result",
        },
    );
    const version = require("@playwright/test/package.json").version;
    const report = makeReport(loaded, stage, results, {
      engine: stage,
      artifact_sha256: process.env.RF_EXECUTED_BUNDLE_SHA256 || null,
      runtime: `Playwright ${version} / Chromium ${[...this.browsers].join(",")} / Node ${process.version}`,
    });
    if (!process.env.RF_REPORT_PATH)
      throw new Error("Missing fixture report path");
    fs.writeFileSync(
      process.env.RF_REPORT_PATH,
      JSON.stringify(report, null, 2) + "\n",
      { flag: "wx" },
    );
  }
};
