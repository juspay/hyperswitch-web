// Local source copy only. Does not install packages, fetch, start services or
// update submodules. The returned marker owns exactly the new temporary root.
const fs = require("node:fs");
const path = require("node:path");
const os = require("node:os");
const crypto = require("node:crypto");
const { execFileSync } = require("node:child_process");
const { loadPack, verifyArtifacts } = require("./contract.cjs");
const assert = require("node:assert/strict");
const web = path.resolve(__dirname, "../..");
const loaded = loadPack();
verifyArtifacts(loaded.pack, web);
assert.equal(
  execFileSync("git", ["rev-parse", "HEAD"], {
    cwd: web,
    encoding: "utf8",
  }).trim(),
  loaded.pack.provenance.web_revision,
);
assert.equal(
  execFileSync("git", ["rev-parse", "HEAD"], {
    cwd: path.join(web, "shared-code"),
    encoding: "utf8",
  }).trim(),
  loaded.pack.provenance.utils_revision,
);
const root = fs.mkdtempSync(path.join(os.tmpdir(), "required-fields-step1-"));
const destination = path.join(root, "web");
fs.mkdirSync(destination);
for (const name of ["npm-user.npmrc", "npm-global.npmrc"]) {
  fs.writeFileSync(path.join(root, name), "", { flag: "wx" });
}
for (const [source, target] of [
  [web, destination],
  [path.join(web, "shared-code"), path.join(destination, "shared-code")],
]) {
  fs.mkdirSync(target, { recursive: true });
  const archive = execFileSync("git", ["archive", "HEAD"], {
    cwd: source,
    maxBuffer: 128 * 1024 * 1024,
  });
  execFileSync("tar", ["-xf", "-", "-C", target], { input: archive });
}
// The tracked archives include dotenv files. Build with explicit synthetic
// inputs only; never read their values or copy ambient checkout credentials.
for (const relative of [".env", "Hyperswitch-React-Demo-App/.env"]) {
  fs.rmSync(path.join(destination, relative), { force: true });
}
const fixtureSources = path.join(
  destination,
  "playwright-tests/required-fields-sync",
);
fs.mkdirSync(fixtureSources, { recursive: true });
for (const name of fs.readdirSync(__dirname)) {
  if (
    /\.(cjs|js|ts|md|json)$/.test(name) &&
    fs.statSync(path.join(__dirname, name)).isFile()
  )
    fs.copyFileSync(
      path.join(__dirname, name),
      path.join(fixtureSources, name),
    );
}
fs.copyFileSync(
  path.join(web, "playwright-tests/e2e/required-fields-sync.spec.ts"),
  path.join(destination, "playwright-tests/e2e/required-fields-sync.spec.ts"),
);
verifyArtifacts(loaded.pack, destination);
const marker = {
  owner: "required-fields-step1-" + crypto.randomUUID(),
  kind: "disposable-filesystem-build",
  root,
  web: destination,
  hosted_target: null,
  server_mutations: false,
  cleanup_scope: root,
};
fs.writeFileSync(
  path.join(root, "fixture-target.json"),
  JSON.stringify(marker, null, 2) + "\n",
  { flag: "wx" },
);
process.stdout.write(JSON.stringify(marker, null, 2) + "\n");
