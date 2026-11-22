import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import webpack from "webpack";
import ts from "typescript";
import { test as base } from "./index";
import type { Page } from "@playwright/test";
import {
  CLIENT_BASE_URL,
  HYPERSWITCH_API_URL,
  REPO_ROOT,
  SDK_URL,
} from "./env";

declare global {
  interface Window {
    sdkTest: typeof import("./sdk-runtime-entry");
  }
}

export const test = base.extend<
  { runtimePage: Page },
  { runtimeBundle: string }
>({
  runtimeBundle: [
    async ({}, use) => {
      const output = await fs.mkdtemp(path.join(os.tmpdir(), "sdk-runtime-"));
      try {
        const entry = path.join(output, "entry.js");
        const source = await fs.readFile(
          path.join(__dirname, "sdk-runtime-entry.ts"),
          "utf8",
        );
        await fs.writeFile(
          entry,
          ts.transpileModule(source, {
            compilerOptions: {
              target: ts.ScriptTarget.ES2022,
              module: ts.ModuleKind.ESNext,
            },
          }).outputText,
        );
        await new Promise<void>((resolve, reject) => {
          webpack(
            {
              mode: "development",
              devtool: false,
              context: REPO_ROOT,
              entry,
              resolve: {
                modules: [path.join(REPO_ROOT, "node_modules"), "node_modules"],
                alias: {
                  "../../src": path.join(REPO_ROOT, "src"),
                  "../recordings": path.join(__dirname, "../recordings"),
                },
              },
              output: {
                path: output,
                filename: "runtime.js",
                publicPath: "",
                library: { name: "sdkTest", type: "window" },
              },
              plugins: [
                new webpack.optimize.LimitChunkCountPlugin({ maxChunks: 1 }),
                new webpack.DefinePlugin({
                  __SDK_CONFIG__: JSON.stringify({
                    sdkUrl: SDK_URL,
                    publicPath: "",
                    backendEndPoint: HYPERSWITCH_API_URL,
                    confirmEndPoint: HYPERSWITCH_API_URL,
                    isLocal: true,
                    isPciCompliant: true,
                  }),
                }),
              ],
            },
            (error, stats) => {
              if (error) reject(error);
              else if (stats?.hasErrors()) reject(new Error(stats.toString()));
              else resolve();
            },
          );
        });
        await use(await fs.readFile(path.join(output, "runtime.js"), "utf8"));
      } finally {
        await fs.rm(output, { recursive: true, force: true });
      }
    },
    { scope: "worker" },
  ],
  runtimePage: async ({ page, runtimeBundle }, use) => {
    await page.route(`${SDK_URL}/**`, (route) =>
      route.fulfill({ contentType: "text/html", body: "<html></html>" }),
    );
    await page.route(`${CLIENT_BASE_URL}/sdk-runtime`, (route) =>
      route.fulfill({
        contentType: "text/html",
        body: '<div id="root"></div><div id="first"></div><div id="second"></div>',
      }),
    );
    await page.goto(`${CLIENT_BASE_URL}/sdk-runtime`);
    await page.addScriptTag({ content: runtimeBundle });
    await use(page);
  },
});

export { expect } from "@playwright/test";
