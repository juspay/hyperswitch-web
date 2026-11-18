const fs = require("node:fs");
const { load, receipt } = require("./contract.cjs");
const {
  makeReport,
  stageIds,
} = require("../required-fields-sync/contract.cjs");
module.exports = class {
  constructor() {
    this.results = new Map();
    this.observations = {};
    this.browsers = new Set();
  }
  onTestEnd(test, result) {
    const id = test.title.split(" ")[0];
    if (this.results.has(id)) throw Error("duplicate case");
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
    for (const a of test.annotations) {
      if (a.type === "observation") this.observations[id] = a.description;
      if (a.type === "browser-version") this.browsers.add(a.description);
    }
  }
  onEnd() {
    const request = load(process.env.RF_VERIFIER_INPUT);
    const reports = ["browser-components", "checkout"].map((stage) =>
      makeReport(
        request,
        stage,
        stageIds(request.pack, stage).map(
          (id) =>
            this.results.get(id) || {
              id,
              status: "not_run",
              detail: "not executed",
            },
        ),
        {
          engine: stage,
          artifact_sha256: process.env.RF_EXECUTED_BUNDLE_SHA256,
          runtime: `Playwright ${require("@playwright/test/package.json").version} / Chromium ${[...this.browsers]} / Node ${process.version}`,
        },
      ),
    );
    // Preserve failed subreports as evidence; never write a successful bound receipt on failure.
    fs.writeFileSync(
      process.env.RF_REPORT_PATH + ".stages.json",
      JSON.stringify(reports, null, 2) + "\n",
      { flag: "wx" },
    );
    const bound = receipt(
      request,
      process.env.RF_EXECUTED_BUNDLE_SHA256,
      reports,
      this.observations,
      JSON.parse(fs.readFileSync(process.env.RF_REGRESSION_REPORTS)),
    );
    fs.writeFileSync(
      process.env.RF_REPORT_PATH,
      JSON.stringify(bound, null, 2) + "\n",
      { flag: "wx" },
    );
  }
};
