/**
 * @fileoverview Bundle Diff Engine
 * Computes differences between base and PR bundle stats
 */

const { isNodeModule, extractPackageName, formatBytes } = require('./stats-parser');

/**
 * @typedef {Object} ModuleChange
 * @property {string} name - Module name
 * @property {number} oldSize - Previous size in bytes
 * @property {number} newSize - New size in bytes
 * @property {number} change - Size difference
 * @property {string} changeFormatted - Human readable change
 * @property {string[]} importChain - Chain of imports leading to this module
 * @property {string} type - 'added' | 'removed' | 'changed'
 * @property {boolean} isNodeModule - Whether from node_modules
 * @property {string|null} packageName - Package name if from node_modules
 */

/**
 * @typedef {Object} BundleDiff
 * @property {number} totalDiff - Total size change in bytes
 * @property {string} totalDiffFormatted - Human readable total change
 * @property {number} nodeModulesDiff - node_modules size change
 * @property {ModuleChange[]} allChanges - All module changes
 * @property {ModuleChange[]} topChanges - Top contributors to size change
 * @property {ModuleChange[]} added - New modules
 * @property {ModuleChange[]} removed - Removed modules
 * @property {Object.<string, number>} packageDiffs - Changes by package
 */

/**
 * Compute bundle diff between base and PR stats
 * @param {import('./stats-parser').BundleStats} baseStats - Base branch stats
 * @param {import('./stats-parser').BundleStats} prStats - PR branch stats
 * @returns {BundleDiff}
 */
function computeDiff(baseStats, prStats) {
  // Build lookup maps for fast comparison
  const baseModules = new Map(baseStats.modules.map(m => [m.name, m]));
  const prModules = new Map(prStats.modules.map(m => [m.name, m]));

  const allChanges = [];
  const added = [];
  const removed = [];
  const changed = [];

  // Find added and changed modules
  for (const [name, prModule] of prModules) {
    const baseModule = baseModules.get(name);

    if (!baseModule) {
      // Module was added
      const change = createModuleChange(prModule, null, 'added');
      added.push(change);
      allChanges.push(change);
    } else if (baseModule.size !== prModule.size) {
      // Module changed size
      const change = createModuleChange(prModule, baseModule, 'changed');
      changed.push(change);
      allChanges.push(change);
    }
  }

  // Find removed modules
  for (const [name, baseModule] of baseModules) {
    if (!prModules.has(name)) {
      const change = createModuleChange(null, baseModule, 'removed');
      removed.push(change);
      allChanges.push(change);
    }
  }

  // Sort by absolute change magnitude
  const sortedChanges = [...allChanges].sort(
    (a, b) => Math.abs(b.change) - Math.abs(a.change)
  );

  // Get top contributors (top 20 or all significant changes)
  const topChanges = sortedChanges
    .filter(c => Math.abs(c.change) > 100) // Ignore changes < 100 bytes
    .slice(0, 20);

  return {
    totalDiff: prStats.totalSize - baseStats.totalSize,
    totalDiffFormatted: formatSignedBytes(prStats.totalSize - baseStats.totalSize),
    nodeModulesDiff: prStats.nodeModulesSize - baseStats.nodeModulesSize,
    allChanges: sortedChanges,
    topChanges,
    added,
    removed,
    packageDiffs: computePackageDiffs(allChanges),
    baseSize: baseStats.totalSize,
    prSize: prStats.totalSize,
    baseSizeFormatted: formatBytes(baseStats.totalSize),
    prSizeFormatted: formatBytes(prStats.totalSize),
  };
}

/**
 * Create a module change record
 * @param {import('./stats-parser').ParsedModule|null} newModule
 * @param {import('./stats-parser').ParsedModule|null} oldModule
 * @param {string} type - 'added' | 'removed' | 'changed'
 * @returns {ModuleChange}
 */
function createModuleChange(newModule, oldModule, type) {
  const name = newModule?.name || oldModule?.name || 'unknown';
  const newSize = newModule?.size || 0;
  const oldSize = oldModule?.size || 0;
  const change = newSize - oldSize;

  return {
    name,
    oldSize,
    newSize,
    change,
    changeFormatted: formatSignedBytes(change),
    importChain: buildImportChain(newModule || oldModule),
    type,
    isNodeModule: isNodeModule(name),
    packageName: extractPackageName(name),
  };
}

/**
 * Build import chain for a module
 * @param {import('./stats-parser').ParsedModule} module
 * @returns {string[]}
 */
function buildImportChain(module) {
  if (!module) return [];

  const chain = [];

  // Start with direct importers
  if (module.reasons && module.reasons.length > 0) {
    chain.push(...module.reasons.slice(0, 3)); // Limit to first 3 importers
  }

  // Add the module itself
  if (!chain.includes(module.name)) {
    chain.push(module.name);
  }

  return chain;
}

/**
 * Compute size changes grouped by package
 * @param {ModuleChange[]} changes - All module changes
 * @returns {Object.<string, number>}
 */
function computePackageDiffs(changes) {
  const diffs = {};

  for (const change of changes) {
    if (!change.packageName) continue;

    diffs[change.packageName] = (diffs[change.packageName] || 0) + change.change;
  }

  // Sort by absolute change
  return Object.fromEntries(
    Object.entries(diffs).sort(([, a], [, b]) => Math.abs(b) - Math.abs(a))
  );
}

/**
 * Format bytes with sign (+/-)
 * @param {number} bytes
 * @returns {string}
 */
function formatSignedBytes(bytes) {
  const formatted = formatBytes(Math.abs(bytes));
  return bytes >= 0 ? `+${formatted}` : `-${formatted}`;
}

/**
 * Extract top-level import chain (what file caused the dependency)
 * @param {ModuleChange} change
 * @returns {string}
 */
function getRootCause(change) {
  if (change.importChain.length === 0) return 'Unknown';

  // First non-node_modules entry in chain is likely the source
  for (const item of change.importChain) {
    if (!isNodeModule(item)) {
      return item;
    }
  }

  return change.importChain[0];
}

/**
 * Filter changes by various criteria
 * @param {BundleDiff} diff
 * @param {Object} filters
 * @returns {ModuleChange[]}
 */
function filterChanges(diff, filters = {}) {
  let filtered = diff.allChanges;

  if (filters.onlyNodeModules) {
    filtered = filtered.filter(c => c.isNodeModule);
  }

  if (filters.minSize) {
    filtered = filtered.filter(c => Math.abs(c.change) >= filters.minSize);
  }

  if (filters.packageName) {
    filtered = filtered.filter(c => c.packageName === filters.packageName);
  }

  if (filters.type) {
    filtered = filtered.filter(c => c.type === filters.type);
  }

  return filtered;
}

/**
 * Generate a summary of the diff
 * @param {BundleDiff} diff
 * @returns {Object}
 */
function generateSummary(diff) {
  const significantIncrease = diff.totalDiff > 50 * 1024; // > 50KB
  const significantDecrease = diff.totalDiff < -50 * 1024; // < -50KB

  return {
    hasChanges: diff.allChanges.length > 0,
    isSignificant: significantIncrease || significantDecrease,
    direction: diff.totalDiff > 0 ? 'increase' : diff.totalDiff < 0 ? 'decrease' : 'unchanged',
    nodeModulesImpact: diff.nodeModulesDiff,
    topAdded: diff.added
      .sort((a, b) => b.newSize - a.newSize)
      .slice(0, 5)
      .map(m => ({
        name: m.name,
        size: m.newSize,
        sizeFormatted: formatBytes(m.newSize),
      })),
    topIncreased: diff.allChanges
      .filter(c => c.type === 'changed' && c.change > 0)
      .sort((a, b) => b.change - a.change)
      .slice(0, 5)
      .map(m => ({
        name: m.name,
        change: m.change,
        changeFormatted: m.changeFormatted,
      })),
    packagesAdded: Object.entries(diff.packageDiffs)
      .filter(([, change]) => change > 0)
      .slice(0, 5),
  };
}

module.exports = {
  computeDiff,
  createModuleChange,
  buildImportChain,
  computePackageDiffs,
  formatSignedBytes,
  getRootCause,
  filterChanges,
  generateSummary,
  formatBytes,
};
