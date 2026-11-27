import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import webpack from "webpack";
import ts from "typescript";
import { test as base } from "./index";
import { CLIENT_BASE_URL, REPO_ROOT, SDK_URL } from "./env";

export const test = base.extend<
  { openReactWidgets: (clientSecret: string, options?: { deferHyper?: boolean }) => Promise<void> },
  { reactWidgetsBundle: string }
>({
  reactWidgetsBundle: [
    async ({}, use) => {
      if (!process.env.REACT_HYPER_JS_PATH) {
        await use("");
        return;
      }
      const output = await fs.mkdtemp(path.join(os.tmpdir(), "react-widgets-"));
      try {
        const entry = path.join(output, "entry.js");
        const source = await fs.readFile(
          path.join(__dirname, "react-widgets-entry.tsx"),
          "utf8",
        );
        await fs.writeFile(
          entry,
          ts.transpileModule(source, {
            compilerOptions: {
              target: ts.ScriptTarget.ES2022,
              module: ts.ModuleKind.ESNext,
              jsx: ts.JsxEmit.React,
            },
          }).outputText,
        );
        await new Promise<void>((resolve, reject) =>
          webpack(
            {
              mode: "development",
              devtool: false,
              context: REPO_ROOT,
              entry,
              resolve: {
                modules: [path.join(REPO_ROOT, "node_modules"), "node_modules"],
                alias: {
                  "@juspay-tech/react-hyper-js": path.resolve(
                    process.env.REACT_HYPER_JS_PATH!,
                  ),
                  react: path.join(REPO_ROOT, "node_modules/react"),
                  "react-dom": path.join(REPO_ROOT, "node_modules/react-dom"),
                },
              },
              output: {
                path: output,
                filename: "app.js",
                library: { name: "reactWidgetTest", type: "window" },
              },
            },
            (error, stats) => {
              if (error) reject(error);
              else if (stats?.hasErrors()) reject(new Error(stats.toString()));
              else resolve();
            },
          ),
        );
        await use(await fs.readFile(path.join(output, "app.js"), "utf8"));
      } finally {
        await fs.rm(output, { recursive: true, force: true });
      }
    },
    { scope: "worker" },
  ],
  openReactWidgets: async ({ page, credentials, reactWidgetsBundle }, use) => {
    await use(async (clientSecret, { deferHyper = false } = {}) => {
      await page.route(`${CLIENT_BASE_URL}/react-widgets-test`, (route) =>
        route.fulfill({
          contentType: "text/html",
          body: '<html><body><div id="root" style="max-width:500px"></div></body></html>',
        }),
      );
      // Keep real SDK assets while serving the merchant fixture synthetically.
      // Chromium treats a fulfilled document as public address space, so proxy
      // its loopback asset requests through Playwright's request context.
      await page.route("https://fonts.googleapis.com/**", (route) =>
        route.fulfill({ contentType: "text/css", body: "" }),
      );
      await page.route(`${SDK_URL}/**`, async (route) => {
        const { pathname } = new URL(route.request().url());
        // Let the context's mocks handle data and telemetry on the SDK origin.
        if (pathname.startsWith("/assets/v1/jsons/location/") || pathname === "/test-analytics") {
          await route.fallback();
        } else {
          await route.fulfill({ response: await route.fetch() });
        }
      });
      await page.goto(`${CLIENT_BASE_URL}/react-widgets-test`);
      await page.addScriptTag({ url: `${SDK_URL}/HyperLoader.js` });
      await page.addScriptTag({ content: reactWidgetsBundle });
      return page.evaluate(
        ({ publishableKey, clientSecret, deferHyper }) => {
          const testWindow = window as any;
          const hyper = deferHyper
            ? new Promise((resolve) => {
                testWindow.resolveReactWidgetHyper = () => resolve(testWindow.Hyper(publishableKey));
              })
            : Promise.resolve(testWindow.Hyper(publishableKey));
          return testWindow.reactWidgetTest.mount(
            hyper,
            clientSecret,
            deferHyper,
          );
        },
        { publishableKey: credentials.publishableKey, clientSecret, deferHyper },
      );
    });
    // Finish pending asset proxies before Playwright closes the request context.
    await page.unrouteAll({ behavior: "wait" });
  },
});
export { expect } from "@playwright/test";
