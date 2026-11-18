// Build/test child environment is a whitelist. In particular HOME, NODE_OPTIONS, proxy,
// cloud, payment and writer credentials are not inherited. Filesystem isolation is a separate gate.
function environment(extra = {}) {
  const allowed = [
    "RF_VERIFIER_INPUT",
    "RF_FIXTURE_ORIGIN",
    "SDK_VERSION",
    "ENV_SDK_URL",
    "ENV_BACKEND_URL",
    "HYPERSWITCH_CLIENT_URL",
    "SELF_SERVER_URL",
    "TEST_ENV",
    "LOCAL_API_URL",
    "SDK_URL",
    "CLIENT_BASE_URL",
    "DEMO_SERVER_URL",
    "REQUIRED_FIELDS_CASE_PACK",
    "PLAYWRIGHT_BROWSERS_PATH",
  ];
  for (const k of Object.keys(extra))
    if (!allowed.includes(k)) throw Error("unregistered child input");
  return {
    PATH: process.env.PATH,
    TMPDIR: process.env.TMPDIR,
    LANG: "en_US.UTF-8",
    NODE_ENV: "development",
    ...extra,
  };
}
function child(args, cwd, env) {
  const { spawn } = require("node:child_process");
  return new Promise((resolve, reject) => {
    const p = spawn(process.execPath, args, {
      cwd,
      env,
      stdio: "inherit",
      detached: true,
    });
    let timedOut = false,
      hard;
    const stop = () => {
      timedOut = true;
      try {
        process.kill(-p.pid, "SIGTERM");
      } catch {}
      hard = setTimeout(() => {
        try {
          process.kill(-p.pid, "SIGKILL");
        } catch {}
      }, 5000);
    };
    const timer = setTimeout(stop, 240000);
    process.once("SIGTERM", stop);
    process.once("SIGINT", stop);
    const clean = () => {
      clearTimeout(timer);
      clearTimeout(hard);
      process.removeListener("SIGTERM", stop);
      process.removeListener("SIGINT", stop);
    };
    p.once("error", (e) => {
      clean();
      reject(e);
    });
    p.once("exit", (code) => {
      clean();
      resolve(timedOut ? 124 : (code ?? 1));
    });
  });
}
module.exports = { environment, child };
