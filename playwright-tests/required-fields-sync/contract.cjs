// Test-only case/report boundary. No router, credentials, network or renderer.
const fs = require("node:fs");
const path = require("node:path");
const crypto = require("node:crypto");
const assert = require("node:assert/strict");

const MAX_PACK_BYTES = 262144;
const MAX_REPORT_BYTES = 65536;
const sha256 = (value) =>
  crypto.createHash("sha256").update(value).digest("hex");
const object = (value) =>
  value !== null && typeof value === "object" && !Array.isArray(value);
function keys(value, allowed, required = allowed) {
  assert(object(value), "expected object");
  assert(
    Object.keys(value).every((k) => allowed.includes(k)),
    "unknown property",
  );
  assert(
    required.every((k) => Object.hasOwn(value, k)),
    "missing property",
  );
}
function bounded(value, depth = 0) {
  assert(depth <= 16, "depth limit");
  if (typeof value === "string") assert(value.length <= 4096, "string limit");
  else if (typeof value === "number")
    assert(Number.isFinite(value), "finite numbers only");
  else if (Array.isArray(value)) {
    assert(value.length <= 256, "array limit");
    value.forEach((v) => bounded(v, depth + 1));
  } else if (object(value)) {
    assert(Object.keys(value).length <= 512, "object limit");
    for (const [key, child] of Object.entries(value)) {
      assert(
        !["__proto__", "prototype", "constructor"].includes(key),
        "unsafe property",
      );
      bounded(key, depth + 1);
      bounded(child, depth + 1);
    }
  } else
    assert(value === null || typeof value === "boolean", "JSON values only");
}
function uniqueIds(values) {
  assert(values.length <= 128, "case limit");
  assert(
    values.every(
      (v) => typeof v === "string" && /^[A-Z][A-Za-z0-9-]{1,79}$/.test(v),
    ),
    "invalid case id",
  );
  assert(new Set(values).size === values.length, "duplicate case id");
}
function validatePack(pack) {
  bounded(pack);
  keys(pack, [
    "schema_version",
    "contract_id",
    "provenance",
    "review",
    "resolver_cases",
    "mapping_cases",
    "country_cases",
    "browser_case_ids",
  ]);
  assert.equal(pack.schema_version, 1);
  assert.equal(pack.contract_id, "required-fields-sdk-v1");
  keys(pack.provenance, [
    "web_revision",
    "utils_revision",
    "rust_core_version",
    "files",
  ]);
  for (const key of ["web_revision", "utils_revision"])
    assert(/^[a-f0-9]{40}$/.test(pack.provenance[key]));
  assert.equal(pack.provenance.rust_core_version, "0.119.0");
  assert(object(pack.provenance.files));
  assert(
    Object.keys(pack.provenance.files).length >= 5 &&
      Object.keys(pack.provenance.files).length <= 128,
    "artifact count",
  );
  keys(pack.review, ["status", "owners"]);
  assert.equal(pack.review.status, "pending-owner-review");
  assert.deepEqual(pack.review.owners, []); // Executable examples are not owner approval.
  for (const [file, digest] of Object.entries(pack.provenance.files)) {
    assert(
      !path.isAbsolute(file) && !file.split("/").includes(".."),
      "relative artifact paths only",
    );
    assert(/^[a-f0-9]{64}$/.test(digest), "invalid artifact digest");
  }
  for (const group of [
    "resolver_cases",
    "mapping_cases",
    "country_cases",
    "browser_case_ids",
  ])
    assert(Array.isArray(pack[group]));
  uniqueIds(
    [...pack.resolver_cases, ...pack.mapping_cases, ...pack.country_cases]
      .map((c) => c.id)
      .concat(pack.browser_case_ids),
  );
  assert(pack.resolver_cases.length > 0, "empty corpus");
  for (const c of pack.resolver_cases) {
    keys(c, [
      "id",
      "plan_tests",
      "config",
      "context",
      "expected_js",
      "expected_rust",
      "expected_diagnostic",
    ]);
    assert(
      Array.isArray(c.plan_tests) &&
        c.plan_tests.length > 0 &&
        c.plan_tests.length <= 38 &&
        c.plan_tests.every((id) => /^T(0[1-9]|[12][0-9]|3[0-8])$/.test(id)),
    );
    assert(
      object(c.context) && object(c.expected_js) && object(c.expected_rust),
    );
    assert(
      [null, "invalid-options", "missing-override"].includes(
        c.expected_diagnostic,
      ),
    );
    keys(c.config, ["default_configs", "contexts", "overrides", "dimensions"]);
    assert(
      object(c.config.default_configs) &&
        object(c.config.overrides) &&
        object(c.config.dimensions),
    );
    assert(Array.isArray(c.config.contexts) && c.config.contexts.length <= 64);
    const rowIds = new Set();
    for (const row of c.config.contexts) {
      keys(row, [
        "id",
        "condition",
        "override_with_keys",
        "priority",
        "weight",
      ]);
      assert(
        typeof row.id === "string" && !rowIds.has(row.id),
        "duplicate context id",
      );
      rowIds.add(row.id);
      assert(object(row.condition));
      assert(
        Array.isArray(row.override_with_keys) &&
          row.override_with_keys.length === 1 &&
          typeof row.override_with_keys[0] === "string",
      );
      assert(Number.isInteger(row.priority) && Number.isInteger(row.weight));
    }
  }
  for (const c of pack.mapping_cases) {
    keys(c, [
      "id",
      "connector",
      "method",
      "type",
      "sdk_type",
      "source_path",
      "field_id",
      "write_path",
      "read_path",
      "value",
      "expected_payload",
    ]);
    assert(
      Object.entries(c)
        .filter(([k]) => k !== "expected_payload")
        .every(([, v]) => typeof v === "string"),
    );
    assert(object(c.expected_payload));
  }
  for (const c of pack.country_cases) {
    keys(c, ["id", "options", "expected_names"]);
    assert(Array.isArray(c.options) && Array.isArray(c.expected_names));
    assert(
      c.options.every((v) => typeof v === "string") &&
        c.expected_names.every((v) => typeof v === "string"),
    );
  }
  return pack;
}
function loadPack(filename = process.env.REQUIRED_FIELDS_CASE_PACK) {
  assert(
    filename,
    "Set REQUIRED_FIELDS_CASE_PACK to the reviewed H sdk-v1/cases.json",
  );
  assert(fs.statSync(filename).size <= MAX_PACK_BYTES, "pack byte limit");
  const bytes = fs.readFileSync(filename);
  assert(bytes.length <= MAX_PACK_BYTES, "pack byte limit");
  return { pack: validatePack(JSON.parse(bytes)), pack_sha256: sha256(bytes) };
}
function verifyArtifacts(pack, webRoot = path.resolve(__dirname, "../..")) {
  for (const file of [
    "shared-code/sdk-utils/superposition/superposition.js",
    "shared-code/sdk-utils/hooks/ConfigurationService.res",
    "shared-code/sdk-utils/utils/SdkConfigParser.res",
    "shared-code/sdk-utils/utils/SuperpositionHelper.res",
    "src/Utilities/DynamicFieldsUtils.res",
    "src/Country.res",
    "src/States.json",
    "package-lock.json",
    "playwright-tests/package-lock.json",
  ]) {
    assert(
      Object.hasOwn(pack.provenance.files, file),
      `missing required artifact: ${file}`,
    );
  }
  for (const [relative, expected] of Object.entries(pack.provenance.files)) {
    assert.equal(
      sha256(fs.readFileSync(path.join(webRoot, relative))),
      expected,
      `artifact drift: ${relative}`,
    );
  }
}
function inspectConfig(config) {
  for (const row of config.contexts) {
    if (!Object.hasOwn(config.overrides, row.override_with_keys[0]))
      return "missing-override";
  }
  for (const values of [
    config.default_configs,
    ...Object.values(config.overrides),
  ]) {
    for (const [key, value] of Object.entries(values)) {
      if (
        key.endsWith("._dropdown_options") &&
        (!Array.isArray(value) || !value.every((v) => typeof v === "string"))
      )
        return "invalid-options";
    }
  }
  return null;
}
function stageIds(pack, stage) {
  if (stage === "js-resolver" || stage === "rust-resolver")
    return pack.resolver_cases.map((c) => c.id);
  if (stage === "browser-components")
    return pack.browser_case_ids.filter((id) => id.startsWith("B-"));
  if (stage === "checkout")
    return pack.browser_case_ids.filter((id) => id.startsWith("E-"));
  throw new Error("unknown evidence stage");
}
function validateReport(report, loaded) {
  assert(
    Buffer.byteLength(JSON.stringify(report)) <= MAX_REPORT_BYTES,
    "report byte limit",
  );
  bounded(report);
  keys(report, [
    "schema_version",
    "contract_id",
    "pack_sha256",
    "provenance",
    "stage",
    "execution",
    "results",
    "status",
  ]);
  assert.equal(report.schema_version, 1);
  assert.equal(report.contract_id, loaded.pack.contract_id);
  assert.equal(report.pack_sha256, loaded.pack_sha256, "case-pack drift");
  assert.deepEqual(
    report.provenance,
    loaded.pack.provenance,
    "artifact identity mismatch",
  );
  keys(report.execution, ["engine", "artifact_sha256", "runtime"]);
  assert.equal(report.execution.engine, report.stage);
  assert(
    typeof report.execution.runtime === "string" &&
      report.execution.runtime.length <= 128,
  );
  assert(
    Array.isArray(report.results) && report.results.length > 0,
    "empty result set",
  );
  uniqueIds(report.results.map((r) => r.id));
  assert.deepEqual(
    report.results.map((r) => r.id).sort(),
    stageIds(loaded.pack, report.stage).sort(),
    "incomplete or extra case results",
  );
  for (const result of report.results) {
    keys(result, ["id", "status", "detail"]);
    assert(["passed", "failed", "not_run"].includes(result.status));
    assert(typeof result.detail === "string" && result.detail.length <= 512);
  }
  const expected = report.results.some((r) => r.status === "failed")
    ? "failed"
    : report.results.some((r) => r.status === "not_run")
      ? "incomplete"
      : "passed";
  assert.equal(report.status, expected, "incorrect aggregate status");
  assert(
    report.execution.artifact_sha256 === null ||
      /^[a-f0-9]{64}$/.test(report.execution.artifact_sha256),
  );
  if (expected === "passed")
    assert(
      report.execution.artifact_sha256 !== null,
      "passed report needs executed artifact digest",
    );
  if (report.stage === "js-resolver")
    assert.equal(
      report.execution.artifact_sha256,
      loaded.pack.provenance.files[
        "shared-code/sdk-utils/superposition/superposition.js"
      ],
    );
  return report;
}
function makeReport(
  loaded,
  stage,
  results,
  execution = {
    engine: stage,
    artifact_sha256:
      stage === "js-resolver"
        ? loaded.pack.provenance.files[
            "shared-code/sdk-utils/superposition/superposition.js"
          ]
        : null,
    runtime: stage === "js-resolver" ? process.version : "not executed",
  },
) {
  const status = results.some((r) => r.status === "failed")
    ? "failed"
    : results.some((r) => r.status === "not_run")
      ? "incomplete"
      : "passed";
  return validateReport(
    {
      schema_version: 1,
      contract_id: loaded.pack.contract_id,
      pack_sha256: loaded.pack_sha256,
      provenance: loaded.pack.provenance,
      stage,
      execution,
      results,
      status,
    },
    loaded,
  );
}
module.exports = {
  MAX_PACK_BYTES,
  MAX_REPORT_BYTES,
  sha256,
  bounded,
  validatePack,
  loadPack,
  verifyArtifacts,
  inspectConfig,
  validateReport,
  makeReport,
  stageIds,
};
