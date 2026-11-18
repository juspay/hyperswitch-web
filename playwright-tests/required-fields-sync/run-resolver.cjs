const assert = require("node:assert/strict");
const { loadPack, inspectConfig, makeReport } = require("./contract.cjs");
const { evaluator } = require("./evaluator.cjs");
const loaded = loadPack();
const evaluate = evaluator(loaded.pack);
const results = loaded.pack.resolver_cases.map((c) => {
  try {
    assert.equal(inspectConfig(c.config), c.expected_diagnostic);
    const result = evaluate(c);
    assert.deepEqual(result.value, c.expected_js);
    assert.deepEqual(result.errors, []);
    return {
      id: c.id,
      status: "passed",
      detail: c.expected_diagnostic
        ? `SDK behavior observed; contract refuses ${c.expected_diagnostic}`
        : "actual pinned CacReader matches independent expectation",
    };
  } catch (error) {
    return {
      id: c.id,
      status: "failed",
      detail: String(error.message).slice(0, 512),
    };
  }
});
const report = makeReport(loaded, "js-resolver", results);
process.stdout.write(JSON.stringify(report, null, 2) + "\n");
if (report.status !== "passed") process.exitCode = 1;
