const { test } = require("node:test");
const assert = require("node:assert/strict");
const {
  loadPack,
  validatePack,
  inspectConfig,
  makeReport,
  validateReport,
  bounded,
  verifyArtifacts,
} = require("./contract.cjs");
const { evaluator } = require("./evaluator.cjs");
const loaded = loadPack();
const evaluate = evaluator(loaded.pack);
for (const c of loaded.pack.resolver_cases) {
  test(c.id, () => {
    assert.equal(inspectConfig(c.config), c.expected_diagnostic);
    const result = evaluate(c);
    assert.deepEqual(result.value, c.expected_js);
    assert.deepEqual(result.errors, []);
  });
}
test("Rust missing-default expectation is deliberately different; no Rust execution claimed", () => {
  const c = loaded.pack.resolver_cases.find(
    (c) => c.id === "R09-missing-default",
  );
  assert.deepEqual(c.expected_rust, {});
  assert.notDeepEqual(c.expected_rust, c.expected_js);
});
test("counterexample detects dropping explicit mandate values equal to defaults", () => {
  const c = structuredClone(loaded.pack.resolver_cases[0]);
  delete c.config.overrides.mandate;
  c.config.contexts.pop();
  assert.notDeepEqual(evaluate(c).value, c.expected_js);
});
test("counterexample detects sorting semantic option arrays", () => {
  const c = structuredClone(loaded.pack.resolver_cases[9]);
  Object.values(c.config.overrides.common)[0].sort();
  assert.notDeepEqual(evaluate(c).value, c.expected_js);
});
test("missing references and null options refuse the contract despite permissive SDK", () => {
  assert.equal(
    inspectConfig(loaded.pack.resolver_cases[13].config),
    "missing-override",
  );
  assert.equal(
    inspectConfig(loaded.pack.resolver_cases[11].config),
    "invalid-options",
  );
});
test("unknown fields and duplicate case/context IDs rejected", () => {
  const p = structuredClone(loaded.pack);
  p.force = true;
  assert.throws(() => validatePack(p));
  delete p.force;
  p.resolver_cases.push(p.resolver_cases[0]);
  assert.throws(() => validatePack(p));
  p.resolver_cases.pop();
  p.resolver_cases[0].config.contexts.push(
    p.resolver_cases[0].config.contexts[0],
  );
  assert.throws(() => validatePack(p));
});
test("depth, arrays and unsafe property bounds", () => {
  assert.throws(() => bounded(Array(257).fill(0)));
  let deep = {};
  for (let i = 0; i < 18; i++) deep = { child: deep };
  assert.throws(() => bounded(deep));
  assert.throws(() => bounded(JSON.parse('{"__proto__":{}}')));
});
test("missing or changed evaluator identity refuses execution", () => {
  const p = structuredClone(loaded.pack);
  p.provenance.files["shared-code/sdk-utils/superposition/superposition.js"] =
    "0".repeat(64);
  assert.throws(() => verifyArtifacts(p), /artifact drift/);
  p.provenance.files = {};
  assert.throws(() => verifyArtifacts(p), /missing required artifact/);
});
test("reports bind exact corpus, stage and artifacts; missing evidence cannot pass", () => {
  const rows = loaded.pack.resolver_cases.map((c) => ({
    id: c.id,
    status: "not_run",
    detail: "not executed",
  }));
  const report = makeReport(loaded, "rust-resolver", rows);
  assert.equal(report.status, "incomplete");
  assert.throws(() => validateReport({ ...report, status: "passed" }, loaded));
  assert.throws(() =>
    validateReport({ ...report, results: rows.slice(1) }, loaded),
  );
  assert.throws(() =>
    validateReport({ ...report, pack_sha256: "0".repeat(64) }, loaded),
  );
  assert.throws(() =>
    validateReport({ ...report, stage: "browser-components" }, loaded),
  );
  assert.throws(() =>
    validateReport({ ...report, results: [...rows, rows[0]] }, loaded),
  );
  assert.throws(
    () =>
      makeReport(
        loaded,
        "rust-resolver",
        rows.map((r) => ({ ...r, status: "passed" })),
      ),
    /executed artifact/,
  );
  assert.throws(
    () =>
      validateReport(
        {
          ...report,
          execution: { ...report.execution, runtime: "x".repeat(65537) },
        },
        loaded,
      ),
    /report byte limit/,
  );
  const emptyStage = structuredClone(loaded);
  emptyStage.pack.browser_case_ids = [];
  assert.throws(
    () =>
      makeReport(emptyStage, "browser-components", [], {
        engine: "browser-components",
        artifact_sha256: "0".repeat(64),
        runtime: "fixture",
      }),
    /empty result set/,
  );
});
