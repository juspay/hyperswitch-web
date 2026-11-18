const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");
const { verifyArtifacts } = require("./contract.cjs");

function evaluator(pack, webRoot = path.resolve(__dirname, "../..")) {
  verifyArtifacts(pack, webRoot);
  const source = fs.readFileSync(
    path.join(webRoot, "shared-code/sdk-utils/superposition/superposition.js"),
    "utf8",
  );
  return (input) => {
    // Fresh realm per case; timeout covers both construction and evaluation.
    const scope = vm.createContext({
      module: { exports: {} },
      exports: {},
      self: {},
      input: JSON.stringify(input),
      errors: [],
    });
    vm.runInContext(
      "console = {log() {}, warn() {}, error(...args) {errors.push(String(args[0]).slice(0,256))}}",
      scope,
    );
    vm.runInContext(source, scope, { timeout: 1000 });
    const json = vm.runInContext(
      "(() => { const c = JSON.parse(input); return JSON.stringify(new module.exports.CacReader(c.config).evaluateConfig(c.context)); })()",
      scope,
      { timeout: 1000 },
    );
    return { value: JSON.parse(json), errors: Array.from(scope.errors) };
  };
}
module.exports = { evaluator };
