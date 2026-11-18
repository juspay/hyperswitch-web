// Bounded request/receipt envelope around the unchanged Step 1 case/report contract.
const assert = require("node:assert/strict");
const fs = require("node:fs");
const base = require("../required-fields-sync/contract.cjs");
// Object member order is not an input semantic. Arrays and raw response/request bytes are preserved.
function canonical(value) {
  if (Array.isArray(value)) return "[" + value.map(canonical).join(",") + "]";
  if (value && typeof value === "object")
    return (
      "{" +
      Object.keys(value)
        .sort()
        .map((k) => JSON.stringify(k) + ":" + canonical(value[k]))
        .join(",") +
      "}"
    );
  return JSON.stringify(value);
}
const phases = ["projected_before", "projected_after", "post_apply"];
const digest = (v) =>
  assert(typeof v === "string" && /^[a-f0-9]{64}$/.test(v), "digest");
function keys(v, allowed) {
  assert(v && !Array.isArray(v) && typeof v === "object");
  assert.deepEqual(Object.keys(v).sort(), [...allowed].sort());
}
// JSON.parse alone silently accepts duplicate keys. Parse structure first, preserving raw bytes
// for hashes and refusing unsafe keys, huge/deep documents and non-finite/unsafe numbers.
function parse(bytes, limit = 1048576) {
  assert(Buffer.byteLength(bytes) <= limit, "byte limit");
  const s = bytes.toString("utf8");
  assert(Buffer.from(s).equals(Buffer.from(bytes)), "invalid UTF-8");
  let i = 0,
    nodes = 0;
  const ws = () => {
    while (/\s/.test(s[i] || "") && i < s.length) i++;
  };
  function string() {
    const m = /^"(?:[^"\\\x00-\x1f]|\\(?:["\\/bfnrt]|u[0-9a-fA-F]{4}))*"/.exec(
      s.slice(i),
    );
    assert(m, "string");
    i += m[0].length;
    return JSON.parse(m[0]);
  }
  function value(depth) {
    ws();
    assert(depth <= 16 && ++nodes <= 20000, "structure limit");
    if (s[i] === "{") {
      i++;
      ws();
      const seen = new Set();
      if (s[i] === "}") {
        i++;
        return;
      }
      while (true) {
        ws();
        const k = string();
        assert(
          !seen.has(k) &&
            !["__proto__", "prototype", "constructor"].includes(k),
          "duplicate/unsafe key",
        );
        seen.add(k);
        assert(seen.size <= 512);
        ws();
        assert(s[i++] === ":");
        value(depth + 1);
        ws();
        const c = s[i++];
        if (c === "}") return;
        assert(c === ",");
      }
    }
    if (s[i] === "[") {
      i++;
      ws();
      if (s[i] === "]") {
        i++;
        return;
      }
      let n = 0;
      while (true) {
        assert(++n <= 256);
        value(depth + 1);
        ws();
        const c = s[i++];
        if (c === "]") return;
        assert(c === ",");
      }
    }
    if (s[i] === '"') {
      string();
      return;
    }
    const m =
      /^(?:true|false|null|-?(?:0|[1-9]\d*)(?:\.\d+)?(?:[eE][+-]?\d+)?)/.exec(
        s.slice(i),
      );
    assert(m, "scalar");
    i += m[0].length;
    const v = JSON.parse(m[0]);
    if (typeof v === "number")
      assert(
        Number.isFinite(v) && Math.abs(v) <= Number.MAX_SAFE_INTEGER,
        "unsafe number",
      );
  }
  value(0);
  ws();
  assert.equal(i, s.length);
  return JSON.parse(s);
}
function load(file, loaded = base.loadPack()) {
  const bytes = fs.readFileSync(file),
    input = parse(bytes);
  keys(input, [
    "schema_version",
    "run",
    "target",
    "plan",
    "reader",
    "parent_pack_sha256",
    "cases",
  ]);
  assert.equal(input.schema_version, 1);
  for (const k of ["run", "target", "plan", "reader", "parent_pack_sha256"])
    digest(input[k]);
  assert.equal(input.reader, base.sha256(canonical(loaded.pack.provenance)));
  assert.equal(input.parent_pack_sha256, loaded.pack_sha256);
  assert.equal(input.cases.length, 3);
  input.cases.forEach((c, i) => {
    keys(c, [
      "phase",
      "response_utf8",
      "response_sha256",
      "input",
      "input_sha256",
      "expected",
    ]);
    assert.equal(c.phase, phases[i]);
    digest(c.response_sha256);
    digest(c.input_sha256);
    assert.equal(
      base.sha256(c.response_utf8),
      c.response_sha256,
      "response drift",
    );
    parse(Buffer.from(c.response_utf8), 262144);
    assert.equal(
      base.sha256(canonical(c.input)),
      c.input_sha256,
      "input drift",
    );
    keys(c.input, ["method", "type", "country", "client"]);
    assert.equal(c.input.method, "card");
    assert.equal(c.input.type, "debit");
    assert.equal(c.input.country, "US");
    keys(c.expected, ["context", "connectors", "label", "path", "value"]);
    base.bounded(c.expected);
    // This package's complete-checkout driver is deliberately bounded to provisioned Card/Debit.
    // Unsupported cases fail rather than claiming another payment method's coverage.
    assert.equal(c.expected.path, "payment_method_data.billing.address.line1");
    assert.equal(c.expected.value, "Fixture lane");
    assert(
      !/(authorization|password|api[_-]?key|client_secret|private_key|access_token)"\s*:/i.test(
        c.response_utf8 + JSON.stringify(c.input),
      ),
      "credential-bearing input",
    );
  });
  const pack = {
    ...loaded.pack,
    browser_case_ids: phases
      .flatMap((_, i) => [`B-response-${i}`, `E-response-${i}`])
      .concat("E-retained"),
  };
  base.validatePack(pack);
  const packBytes = Buffer.from(canonical(pack));
  return {
    input,
    bytes,
    request_sha256: base.sha256(bytes),
    pack,
    packBytes,
    pack_sha256: base.sha256(packBytes),
  };
}
function receipt(request, artifacts, reports, observations, regressions) {
  digest(artifacts);
  assert.equal(reports.length, 2);
  const baseline = base.loadPack();
  assert.equal(regressions.length, 3);
  for (const [i, stage] of [
    "browser-components",
    "checkout",
    "js-resolver",
  ].entries()) {
    const r = base.validateReport(regressions[i], baseline);
    assert.equal(r.stage, stage);
    assert.equal(r.status, "passed");
    if (stage !== "js-resolver")
      assert.equal(r.execution.artifact_sha256, artifacts);
  }
  for (const [i, stage] of ["browser-components", "checkout"].entries()) {
    const r = base.validateReport(reports[i], request);
    assert.equal(r.stage, stage);
    assert.equal(r.execution.artifact_sha256, artifacts);
    assert.equal(r.status, "passed");
  }
  assert.deepEqual(
    Object.keys(observations).sort(),
    request.pack.browser_case_ids.slice().sort(),
  );
  for (const v of Object.values(observations)) digest(v);
  return {
    schema_version: 1,
    scope: "synthetic_local",
    request_sha256: request.request_sha256,
    run: request.input.run,
    target: request.input.target,
    plan: request.input.plan,
    reader: request.input.reader,
    cases_sha256: request.pack_sha256,
    artifacts_sha256: artifacts,
    bindings: request.input.cases.map((c) => ({
      phase: c.phase,
      response_sha256: c.response_sha256,
      input_sha256: c.input_sha256,
    })),
    parent_pack_sha256: request.input.parent_pack_sha256,
    regressions,
    reports,
    observations,
    status: "passed",
    platform_credential_isolation: "pending",
  };
}
module.exports = { canonical, load, parse, receipt, phases, keys };
