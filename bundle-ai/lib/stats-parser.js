/**
 * @fileoverview Webpack Stats Parser
 * Parses webpack --json --profile output into structured module data
 */

/**
 * @typedef {Object} ParsedModule
 * @property {string} id - Module identifier
 * @property {string} name - Module name (path)
 * @property {number} size - Module size in bytes
 * @property {string[]} reasons - Import reasons
 * @property {string[]} usedExports - Exported symbols that are actually used
 * @property {string} issuer - The module that imported this module
 * @property {boolean} isNodeModule - Whether this is from node_modules
 */

/**
 * @typedef {Object} BundleStats
 * @property {ParsedModule[]} modules - All parsed modules
 * @property {number} totalSize - Total bundle size in bytes
 * @property {number} nodeModulesSize - Size of all node_modules
 * @property {Object.<string, number>} byPackage - Size grouped by package name
 * @property {string[]} entryPoints - Entry point names
 */

/**
 * Parse webpack stats JSON into structured data
 * @param {Object} stats - Raw webpack stats from --json output
 * @returns {BundleStats} Parsed bundle statistics
 */
function parseStats(stats) {
  if (!stats || !stats.modules) {
    throw new Error('Invalid webpack stats: missing modules array');
  }

  const modules = stats.modules.map(parseModule);
  const nodeModules = modules.filter(m => m.isNodeModule);

  return {
    modules,
    totalSize: calculateTotalSize(modules),
    nodeModulesSize: calculateTotalSize(nodeModules),
    byPackage: groupByPackage(modules),
    entryPoints: extractEntryPoints(stats),
  };
}

/**
 * Parse a single module from webpack stats
 * @param {Object} module - Raw module data from webpack
 * @returns {ParsedModule}
 */
function parseModule(module) {
  const name = cleanModuleName(module.name || module.identifier || 'unknown');
  const size = module.size || 0;
  const reasons = parseReasons(module.reasons || []);
  const usedExports = parseUsedExports(module.usedExports);

  return {
    id: module.id?.toString() || name,
    name,
    size,
    reasons,
    usedExports,
    issuer: extractIssuer(module.reasons),
    isNodeModule: isNodeModule(name),
  };
}

/**
 * Clean module name/path for display
 * @param {string} name - Raw module name
 * @returns {string}
 */
function cleanModuleName(name) {
  // Remove webpack internal prefixes
  return name
    .replace(/\.\/\.\//g, './')
    .replace(/^multi\s+/, '')
    .replace(/^\.+\//, '')
    .trim();
}

/**
 * Parse module reasons into simplified import chain
 * @param {Array} reasons - Raw reasons from webpack
 * @returns {string[]}
 */
function parseReasons(reasons) {
  if (!Array.isArray(reasons)) return [];

  return reasons
    .map(r => {
      const moduleName = r.moduleName || r.module || r.resolvedModule || '';
      return cleanModuleName(moduleName);
    })
    .filter(Boolean);
}

/**
 * Extract the immediate issuer (direct importer) from reasons
 * @param {Array} reasons - Raw reasons from webpack
 * @returns {string|null}
 */
function extractIssuer(reasons) {
  if (!Array.isArray(reasons) || reasons.length === 0) return null;
  const firstReason = reasons[0];
  return cleanModuleName(firstReason.moduleName || firstReason.module || '');
}

/**
 * Parse used exports information
 * @param {*} usedExports - Webpack's usedExports value
 * @returns {string[]}
 */
function parseUsedExports(usedExports) {
  if (usedExports === null || usedExports === undefined) return [];
  if (usedExports === false) return []; // Tree-shaking disabled
  if (usedExports === true) return ['*']; // All exports used
  if (Array.isArray(usedExports)) return usedExports;
  return [String(usedExports)];
}

/**
 * Check if module is from node_modules
 * @param {string} name - Module name
 * @returns {boolean}
 */
function isNodeModule(name) {
  return name.includes('node_modules');
}

/**
 * Extract package name from module path
 * @param {string} name - Module name/path
 * @returns {string|null}
 */
function extractPackageName(name) {
  if (!isNodeModule(name)) return null;

  const match = name.match(/node_modules[/\\](?:@[^/\\]+[/\\][^/\\]+|[^/\\]+)/);
  if (!match) return null;

  // Remove 'node_modules/' prefix
  return match[0].replace(/^node_modules[/\\]/, '');
}

/**
 * Group modules by their package name
 * @param {ParsedModule[]} modules - Parsed modules
 * @returns {Object.<string, number>}
 */
function groupByPackage(modules) {
  const groups = {};

  for (const module of modules) {
    if (!module.isNodeModule) continue;

    const pkgName = extractPackageName(module.name);
    if (!pkgName) continue;

    groups[pkgName] = (groups[pkgName] || 0) + module.size;
  }

  return groups;
}

/**
 * Calculate total size from modules
 * @param {ParsedModule[]} modules - Modules to sum
 * @returns {number}
 */
function calculateTotalSize(modules) {
  return modules.reduce((sum, m) => sum + m.size, 0);
}

/**
 * Extract entry points from webpack stats
 * @param {Object} stats - Raw webpack stats
 * @returns {string[]}
 */
function extractEntryPoints(stats) {
  if (!stats.entrypoints) return [];
  return Object.keys(stats.entrypoints);
}

/**
 * Load and parse webpack stats from file
 * @param {string} filePath - Path to stats JSON file
 * @returns {BundleStats}
 */
function loadStatsFromFile(filePath) {
  const fs = require('fs');
  const content = fs.readFileSync(filePath, 'utf-8');
  const stats = JSON.parse(content);
  return parseStats(stats);
}

/**
 * Find the main chunk from webpack stats
 * @param {Object} stats - Raw webpack stats
 * @returns {Object|null}
 */
function findMainChunk(stats) {
  if (!stats.chunks || stats.chunks.length === 0) return null;

  // Look for the main/app chunk
  return (
    stats.chunks.find(c => c.names?.includes('main')) ||
    stats.chunks.find(c => c.names?.includes('app')) ||
    stats.chunks.find(c => c.entry) ||
    stats.chunks[0]
  );
}

/**
 * Format bytes to human readable string
 * @param {number} bytes - Size in bytes
 * @param {number} decimals - Decimal places
 * @returns {string}
 */
function formatBytes(bytes, decimals = 2) {
  if (bytes === 0) return '0 Bytes';

  const sign = bytes < 0 ? '-' : '';
  const absBytes = Math.abs(bytes);
  const k = 1024;
  const dm = decimals < 0 ? 0 : decimals;
  const sizes = ['Bytes', 'KB', 'MB', 'GB'];

  const i = Math.floor(Math.log(absBytes) / Math.log(k));

  return sign + parseFloat((absBytes / Math.pow(k, i)).toFixed(dm)) + ' ' + sizes[i];
}

module.exports = {
  parseStats,
  parseModule,
  loadStatsFromFile,
  extractPackageName,
  isNodeModule,
  formatBytes,
  findMainChunk,
};
