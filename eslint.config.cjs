const promise = require("eslint-plugin-promise");
const reactHooks = require("eslint-plugin-react-hooks");
const tsParser = require("@typescript-eslint/parser");
const tsPlugin = require("@typescript-eslint/eslint-plugin");

module.exports = [
  {
    files: ["**/*.{js,jsx}"],
    languageOptions: {
      ecmaVersion: "latest",
      sourceType: "module",
      parserOptions: {
        ecmaFeatures: {
          jsx: true,
        },
      },
    },
    plugins: {
      promise,
      "react-hooks": reactHooks,
    },
    rules: {
      "react-hooks/rules-of-hooks": "error",
      "promise/catch-or-return": "error",
      "no-console": [
        "error",
        { allow: ["warn", "error", "info", "log", "debug"] },
      ],
      "no-useless-escape": "off",
    },
  },
  {
    files: ["src/**/*.{ts,tsx}"],
    languageOptions: {
      ecmaVersion: "latest",
      sourceType: "module",
      parser: tsParser,
      parserOptions: {
        ecmaFeatures: {
          jsx: true,
        },
      },
    },
    plugins: {
      promise,
      "react-hooks": reactHooks,
      "@typescript-eslint": tsPlugin,
    },
    rules: {
      "react-hooks/rules-of-hooks": "error",
      "promise/catch-or-return": "error",
      "no-console": [
        "error",
        { allow: ["warn", "error", "info", "log", "debug"] },
      ],
      "no-useless-escape": "off",
    },
  },
  {
    files: ["cypress-tests/**/*.{ts,tsx}"],
    languageOptions: {
      ecmaVersion: "latest",
      sourceType: "module",
      parser: tsParser,
      parserOptions: {
        ecmaFeatures: {
          jsx: true,
        },
      },
    },
    plugins: {
      "@typescript-eslint": tsPlugin,
    },
    rules: {
      "no-console": [
        "error",
        { allow: ["warn", "error", "info", "log", "debug"] },
      ],
      "no-useless-escape": "off",
    },
  },
];