// consoleSuppress.js
export function setupConsoleSuppress(suppressPatterns, shouldSuppress) {
  const originalConsole = {
    log: console.log,
    warn: console.warn,
    info: console.info,
    debug: console.debug,
  };

  console.log = function (...args) {
    if (!shouldSuppress(args)) {
      originalConsole.log.apply(console, args);
    }
  };

  console.warn = function (...args) {
    if (!shouldSuppress(args)) {
      originalConsole.warn.apply(console, args);
    }
  };

  console.info = function (...args) {
    if (!shouldSuppress(args)) {
      originalConsole.info.apply(console, args);
    }
  };

  console.debug = function (...args) {
    if (!shouldSuppress(args)) {
      originalConsole.debug.apply(console, args);
    }
  };

  return function restoreConsole() {
    console.log = originalConsole.log;
    console.warn = originalConsole.warn;
    console.info = originalConsole.info;
    console.debug = originalConsole.debug;
  };
}
