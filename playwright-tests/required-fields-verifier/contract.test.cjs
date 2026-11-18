const { test } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { parse, load, receipt } = require("./contract.cjs");
const { fixture } = require("./fixture-input.cjs");
const {
  makeReport,
  stageIds,
  loadPack,
} = require("../required-fields-sync/contract.cjs");
const { environment } = require("./environment.cjs");
function withInput(fn) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), "rf-verifier-contract-"));
  fs.writeFileSync(
    path.join(root, "owner.json"),
    JSON.stringify({
      purpose: "synthetic contract test",
      root,
      cleanup_scope: root,
    }),
  );
  try {
    const file = path.join(root, "input.json");
    fs.writeFileSync(file, JSON.stringify(fixture()));
    return fn(file);
  } finally {
    const m = JSON.parse(fs.readFileSync(path.join(root, "owner.json")));
    assert.equal(m.root, root);
    assert.equal(m.cleanup_scope, root);
    fs.rmSync(root, { recursive: true });
  }
}
test("strict duplicate unsafe large deep and numeric input refusal", () => {
  for (const text of [
    '{"a":1,"a":2}',
    '{"__proto__":{}}',
    '{"a":1e999}',
    "[9007199254740992]",
    "[".repeat(18) + "0" + "]".repeat(18),
  ])
    assert.throws(() => parse(Buffer.from(text)));
  assert.throws(() => parse(Buffer.alloc(1048577)));
});
test("bind exact raw response and input, reject unsupported dimensions/cases", () =>
  withInput((file) => {
    const good = load(file);
    assert.equal(good.input.cases.length, 3);
    for (const change of [
      (v) => (v.cases[0].response_utf8 += " "),
      (v) => (v.cases[0].input.country = "CA"),
      (v) => v.cases.pop(),
      (v) => (v.parent_pack_sha256 = "0".repeat(64)),
    ]) {
      const v = fixture();
      change(v);
      fs.writeFileSync(file, JSON.stringify(v));
      assert.throws(() => load(file));
    }
  }));
test("missing/failed/stale artifacts or observations never pass", () =>
  withInput((file) => {
    const q = load(file),
      a = "1".repeat(64);
    const reports = ["browser-components", "checkout"].map((stage) =>
      makeReport(
        q,
        stage,
        stageIds(q.pack, stage).map((id) => ({
          id,
          status: "passed",
          detail: "synthetic validator test only",
        })),
        { engine: stage, artifact_sha256: a, runtime: "synthetic test only" },
      ),
    );
    const baseline = loadPack();
    const regressions = ["browser-components", "checkout", "js-resolver"].map(
      (stage) =>
        makeReport(
          baseline,
          stage,
          stageIds(baseline.pack, stage).map((id) => ({
            id,
            status: "passed",
            detail: "synthetic validator test only",
          })),
          {
            engine: stage,
            artifact_sha256:
              stage === "js-resolver"
                ? baseline.pack.provenance.files[
                    "shared-code/sdk-utils/superposition/superposition.js"
                  ]
                : a,
            runtime: "synthetic validator test",
          },
        ),
    );
    const obs = Object.fromEntries(
      q.pack.browser_case_ids.map((id) => [id, a]),
    );
    assert.equal(
      receipt(q, a, reports, obs, regressions).scope,
      "synthetic_local",
    );
    assert.throws(() => receipt(q, "2".repeat(64), reports, obs, regressions));
    assert.throws(() => receipt(q, a, reports, {}, regressions));
    reports[1].results[0].status = "not_run";
    assert.throws(() => receipt(q, a, reports, obs, regressions));
  }));
test("child credentials sentinel and ambient runtime injection are absent", () => {
  process.env.RF_CREDENTIAL_SENTINEL = "synthetic-do-not-inherit";
  process.env.NODE_OPTIONS = "synthetic-do-not-inherit";
  try {
    const env = environment();
    assert(!env.HOME && !env.NODE_OPTIONS && !env.RF_CREDENTIAL_SENTINEL);
    const r = require("node:child_process").spawnSync(
      process.execPath,
      [
        "-e",
        "if(process.env.RF_CREDENTIAL_SENTINEL || process.env.NODE_OPTIONS || process.env.HOME) process.exit(9)",
      ],
      { env },
    );
    assert.equal(r.status, 0);
    assert.throws(() => environment({ WRITER_TOKEN: "synthetic" }));
  } finally {
    delete process.env.RF_CREDENTIAL_SENTINEL;
    delete process.env.NODE_OPTIONS;
  }
});

test("canonical object hashing preserves ordered arrays and numeric-looking keys", () => {
  const { canonical } = require("./contract.cjs");
  assert.equal(
    canonical({ b: 2, a: ["B", "A", "A"] }),
    '{"a":["B","A","A"],"b":2}',
  );
  assert.equal(canonical({ 2: 2, 10: 10 }), '{"10":10,"2":2}');
  assert.notEqual(canonical(["B", "A"]), canonical(["A", "B"]));
});
