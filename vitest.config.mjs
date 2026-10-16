import { fileURLToPath } from "node:url";
import { defineConfig } from "vitest/config";

export default defineConfig({
  resolve: {
    alias: [
      { find: "/package.json", replacement: fileURLToPath(new URL("./package.json", import.meta.url)) },
    ],
  },
  test: {
    forbidOnly: Boolean(process.env.CI),
    retry: 0,
    passWithNoTests: false,
    coverage: {
      provider: "v8",
      reporter: ["text", "html", "lcov"],
      reportsDirectory: "coverage/unit",
      include: [
        "src/**/*.bs.js",
        "src/**/*.{js,jsx,mjs}",
        "shared-code/sdk-utils/**/*.bs.js",
        "shared-code/sdk-utils/**/*.{js,jsx,mjs}",
      ],
      exclude: [
        "**/node_modules/**", "**/*.test.*", "**/*.spec.*",
        // Vendored libraries and their prebuilt bundle are dependency code.
        "src/libraries/ua-parser-js/ua-parser.js",
        "shared-code/sdk-utils/superposition/superposition.js",
      ],
    },
    projects: [
      {
        extends: true,
        test: {
          name: "unit",
          environment: "node",
          include: ["tests/unit/**/*.test.ts"],
          setupFiles: ["tests/setup/sdk-config.ts"],
        },
      },
      {
        extends: true,
        test: {
          name: "dom",
          environment: "jsdom",
          environmentOptions: { jsdom: { url: "https://sdk.test/checkout" } },
          include: ["tests/{dom,components,hooks}/**/*.test.{ts,tsx}"],
          setupFiles: ["tests/setup/sdk-config.ts", "tests/setup/dom.ts"],
        },
      },
    ],
  },
});
