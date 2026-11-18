// Owned local fixture utilities. No credentials, proxies or external I/O.
const fs = require("node:fs");
const path = require("node:path");
const http = require("node:http");
const assert = require("node:assert/strict");
const { spawn } = require("node:child_process");
const { sha256 } = require("./contract.cjs");

function target() {
  const web = fs.realpathSync(path.resolve(__dirname, "../.."));
  const root = path.dirname(web);
  const marker = JSON.parse(
    fs.readFileSync(path.join(root, "fixture-target.json")),
  );
  assert.equal(marker.kind, "disposable-filesystem-build");
  assert(/^required-fields-step1-[a-f0-9-]+$/.test(marker.owner));
  assert.equal(fs.realpathSync(marker.root), root);
  assert.equal(fs.realpathSync(marker.cleanup_scope), root);
  assert.equal(fs.realpathSync(marker.web), web);
  assert(marker.hosted_target === null && marker.server_mutations === false);
  assert(!fs.existsSync(path.join(web, ".git")), "refuse source checkout");
  return { ...marker, web, root };
}
function manifest(directory) {
  const entries = {};
  function walk(current) {
    for (const name of fs.readdirSync(current).sort()) {
      const file = path.join(current, name);
      assert(
        !fs.lstatSync(file).isSymbolicLink(),
        "fixture assets cannot be symlinks",
      );
      if (fs.statSync(file).isDirectory()) walk(file);
      else
        entries[path.relative(directory, file).split(path.sep).join("/")] =
          sha256(fs.readFileSync(file));
    }
  }
  walk(directory);
  assert(Object.keys(entries).length > 0, "missing emitted assets");
  return entries;
}
function child(args, cwd, env) {
  return new Promise((resolve, reject) => {
    const proc = spawn(process.execPath, args, { cwd, env, stdio: "inherit" });
    const onInt = () => proc.kill("SIGINT"),
      onTerm = () => proc.kill("SIGTERM");
    process.once("SIGINT", onInt);
    process.once("SIGTERM", onTerm);
    const clean = () => {
      process.off("SIGINT", onInt);
      process.off("SIGTERM", onTerm);
    };
    proc.once("error", (error) => {
      clean();
      reject(error);
    });
    proc.once("exit", (code) => {
      clean();
      resolve(code ?? 1);
    });
  });
}
async function staticServer(directory, rootHtml) {
  let assets,
    violations = 0;
  const server = http.createServer((req, res) => {
    if (!["GET", "HEAD"].includes(req.method)) {
      violations++;
      res.writeHead(405);
      res.end();
      return;
    }
    let file;
    try {
      file =
        decodeURIComponent(new URL(req.url, "http://127.0.0.1").pathname).slice(
          1,
        ) || "index.html";
    } catch (_) {
      res.writeHead(400);
      res.end();
      return;
    }
    if (file === "index.html" && rootHtml) {
      res.setHeader("content-type", "text/html");
      res.end(rootHtml);
      return;
    }
    if (!assets || !Object.hasOwn(assets, file)) {
      res.writeHead(404);
      res.end();
      return;
    }
    const bytes = fs.readFileSync(path.join(directory, file));
    if (sha256(bytes) !== assets[file]) {
      violations++;
      res.writeHead(409);
      res.end();
      return;
    }
    const mime = {
      ".js": "text/javascript",
      ".css": "text/css",
      ".html": "text/html",
      ".json": "application/json",
      ".svg": "image/svg+xml",
      ".png": "image/png",
    }[path.extname(file)];
    if (mime) res.setHeader("content-type", mime);
    res.setHeader("access-control-allow-origin", "*");
    res.end(req.method === "HEAD" ? undefined : bytes);
  });
  await new Promise((resolve, reject) => {
    server.once("error", reject);
    server.listen(0, "127.0.0.1", resolve);
  });
  return {
    origin: `http://127.0.0.1:${server.address().port}`,
    seal() {
      assets = manifest(directory);
      return assets;
    },
    verify() {
      assert.equal(violations, 0, "unexpected write or changed served asset");
      assert.deepEqual(manifest(directory), assets, "emitted artifact drift");
    },
    close: () =>
      new Promise((resolve) => {
        server.closeAllConnections();
        server.close(resolve);
      }),
  };
}
// Child builds/tests receive only these inputs, never ambient secrets.
function environment(extra = {}) {
  return {
    PATH: process.env.PATH,
    HOME: process.env.HOME,
    TMPDIR: process.env.TMPDIR,
    LANG: "en_US.UTF-8",
    NODE_ENV: "development",
    ...extra,
  };
}
module.exports = { target, manifest, child, staticServer, environment };
