const promise = require("eslint-plugin-promise");
const reactHooks = require("eslint-plugin-react-hooks");

module.exports = [
  {
    files: ["src/**/*.{js,jsx,ts,tsx}"],
    languageOptions: {
      ecmaVersion: "latest",
      sourceType: "module",
    },
    plugins: {
      promise,
      "react-hooks": reactHooks,
    },
    rules: {
      "react-hooks/rules-of-hooks": "error",
      "promise/catch-or-return": "error",
      "no-console": ["error", { allow: ["warn", "error", "info", "log", "debug"] }],
      "no-useless-escape": "off",
    },
  },
];
