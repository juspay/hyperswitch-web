const promisePlugin = require("eslint-plugin-promise");

module.exports = [
  {
    plugins: {
      promise: promisePlugin,
    },
    rules: {
      "promise/catch-or-return": "error",
    },
  },
];
