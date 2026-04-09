/**
 * @fileoverview Rule Engine
 * Detects suspicious bundle patterns and potential issues
 */

const fs = require('fs');
const path = require('path');
const { isNodeModule, extractPackageName, formatBytes } = require('./stats-parser');

/**
 * @typedef {Object} RuleResult
 * @property {string} id - Rule identifier
 * @property {string} severity - 'critical' | 'warning' | 'info'
 * @property {string} message - Human readable description
 * @property {Object} details - Additional context
 * @property {string} category - Category of the issue
 */

/**
 * @typedef {Object} DetectionResults
 * @property {RuleResult[]} violations - All detected issues
 * @property {RuleResult[]} critical - Critical issues
 * @property {RuleResult[]} warnings - Warning-level issues
 * @property {RuleResult[]} info - Info-level findings
 * @property {boolean} hasCriticalIssues - Whether there are blocking issues
 */

// Detection thresholds
const THRESHOLDS = {
  LARGE_DEPENDENCY_KB: 30,
  TOTAL_SIZE_MB: 5,
  SIZE_INCREASE_PERCENT: 20,
  SIZE_INCREASE_ABSOLUTE_KB: 100,
  SINGLE_MODULE_INCREASE_KB: 50,
};

// Known problematic imports that indicate full library usage
// Only checking packages from package.json dependencies
const FULL_IMPORT_PATTERNS = [
  // React ecosystem packages (from dependencies)
  { pattern: /react-datepicker(?![/\\.])/i, name: 'react-datepicker', suggestion: 'Ensure react-datepicker is properly tree-shaken' },
  
  // State management
  { pattern: /recoil(?![/\\.])/i, name: 'recoil', suggestion: 'Ensure recoil is properly tree-shaken' },
  
  // Analytics
  { pattern: /@sentry\/(?:react|browser)(?![/\\.])/i, name: 'Sentry', suggestion: 'Sentry should be tree-shaken properly' },
];

// Known heavy packages - Only packages in dependencies (not devDependencies)
// Payment SDKs (Stripe, PayPal, etc.) are loaded dynamically via CDN, not bundled
const HEAVY_PACKAGES = [
  // From package.json dependencies
  'react-datepicker',
  '@sentry/react',
  'recoil',
];

// Allowed production dependencies from package.json
// Any node_modules package NOT in this list (or a sub-dependency of these)
// appearing newly in the bundle is flagged as suspicious
const ALLOWED_DEPENDENCIES = [
  '@glennsl/rescript-fetch',
  '@rescript/core',
  '@rescript/react',
  '@sentry/react',
  '@sentry/webpack-plugin',
  'react',
  'react-datepicker',
  'react-dom',
  'recoil',
  'webpack-merge',
];

/**
 * Run all detection rules on the bundle diff
 * @param {import('./diff-engine').BundleDiff} diff
 * @param {Object} options
 * @returns {DetectionResults}
 */
function runDetection(diff, options = {}) {
  const violations = [];

  // Run all detection rules
  violations.push(...detectLargeDependencyAdditions(diff));
  violations.push(...detectNodeModulesIncrease(diff));
  violations.push(...detectFullLibraryImports(diff));
  violations.push(...detectTreeShakingFailures(diff, options.baseStats));
  violations.push(...detectSuddenSizeSpike(diff, options.linesChanged));
  violations.push(...detectHeavyPackages(diff));
  violations.push(...detectDuplicateDependencies(diff));
  violations.push(...detectSuspiciousModules(diff));
  violations.push(...detectUnexpectedDependencies(diff));

  // Categorize by severity
  const critical = violations.filter(v => v.severity === 'critical');
  const warnings = violations.filter(v => v.severity === 'warning');
  const info = violations.filter(v => v.severity === 'info');

  return {
    violations,
    critical,
    warnings,
    info,
    hasCriticalIssues: critical.length > 0,
  };
}

/**
 * Detect large dependency additions (>30KB)
 * @param {import('./diff-engine').BundleDiff} diff
 * @returns {RuleResult[]}
 */
function detectLargeDependencyAdditions(diff) {
  const results = [];
  const threshold = THRESHOLDS.LARGE_DEPENDENCY_KB * 1024;

  for (const change of diff.added) {
    if (!change.isNodeModule) continue;
    if (change.newSize < threshold) continue;

    results.push({
      id: 'LARGE_DEP_ADDITION',
      severity: 'warning',
      category: 'Dependency Size',
      message: `Large dependency added: ${change.packageName || change.name} (${formatBytes(change.newSize)})`,
      details: {
        module: change.name,
        packageName: change.packageName,
        size: change.newSize,
        sizeFormatted: formatBytes(change.newSize),
        importChain: change.importChain,
        rootCause: getRootCause(change),
      },
    });
  }

  return results;
}

/**
 * Detect significant node_modules size increase
 * @param {import('./diff-engine').BundleDiff} diff
 * @returns {RuleResult[]}
 */
function detectNodeModulesIncrease(diff) {
  const results = [];
  const threshold = THRESHOLDS.SIZE_INCREASE_ABSOLUTE_KB * 1024;

  if (diff.nodeModulesDiff > threshold) {
    const percentage = ((diff.nodeModulesDiff / (diff.baseSize || 1)) * 100).toFixed(1);

    results.push({
      id: 'NODE_MODULES_INCREASE',
      severity: 'warning',
      category: 'Bundle Growth',
      message: `node_modules increased by ${formatBytes(diff.nodeModulesDiff)} (${percentage}%)`,
      details: {
        change: diff.nodeModulesDiff,
        changeFormatted: formatBytes(diff.nodeModulesDiff),
        percentage: parseFloat(percentage),
        packages: Object.entries(diff.packageDiffs)
          .filter(([, change]) => change > 0)
          .map(([name, change]) => ({ name, size: change, formatted: formatBytes(change) })),
      },
    });
  }

  return results;
}

/**
 * Detect full library imports (not tree-shaking friendly)
 * @param {import('./diff-engine').BundleDiff} diff
 * @returns {RuleResult[]}
 */
function detectFullLibraryImports(diff) {
  const results = [];

  for (const change of [...diff.added, ...diff.topChanges.filter(c => c.change > 0)]) {
    if (!change.isNodeModule) continue;

    for (const pattern of FULL_IMPORT_PATTERNS) {
      if (pattern.pattern.test(change.name)) {
        results.push({
          id: 'FULL_LIBRARY_IMPORT',
          severity: 'warning',
          category: 'Tree Shaking',
          message: `Potential full library import: ${pattern.name}`,
          details: {
            module: change.name,
            library: pattern.name,
            suggestion: pattern.suggestion,
            size: change.newSize || change.change,
            importChain: change.importChain,
          },
        });
        break;
      }
    }
  }

  return results;
}

/**
 * Detect tree-shaking failures (unused exports)
 * @param {import('./diff-engine').BundleDiff} diff
 * @param {import('./stats-parser').BundleStats} [baseStats]
 * @returns {RuleResult[]}
 */
function detectTreeShakingFailures(diff, baseStats) {
  // This requires detailed module info from webpack stats
  // We look for modules with usedExports: false or missing tree-shaking indicators
  const results = [];

  // Check added/changed modules for potential tree-shaking issues
  for (const change of diff.added) {
    // Look for large additions that might indicate full imports
    if (change.isNodeModule && change.newSize > 50 * 1024) {
      // Check if it looks like a full import pattern
      const isKnownHeavy = FULL_IMPORT_PATTERNS.some(p => p.pattern.test(change.name));

      if (isKnownHeavy) {
        results.push({
          id: 'TREE_SHAKING_FAILURE',
          severity: 'warning',
          category: 'Tree Shaking',
          message: `Possible tree-shaking failure: ${change.packageName || change.name}`,
          details: {
            module: change.name,
            size: change.newSize,
            reason: 'Large addition of known tree-shaking-sensitive library',
            suggestion: 'Ensure proper ES module imports and sideEffects config',
          },
        });
      }
    }
  }

  return results;
}

/**
 * Detect sudden size spike vs lines changed
 * @param {import('./diff-engine').BundleDiff} diff
 * @param {number} [linesChanged] - Lines changed in PR
 * @returns {RuleResult[]}
 */
function detectSuddenSizeSpike(diff, linesChanged) {
  const results = [];

  if (!linesChanged || linesChanged === 0) return results;

  const sizeIncreasePerLine = Math.abs(diff.totalDiff) / linesChanged;
  const threshold = 500; // bytes per line (rough heuristic)

  if (sizeIncreasePerLine > threshold && diff.totalDiff > 10 * 1024) {
    results.push({
      id: 'SIZE_SPIKE',
      severity: 'info',
      category: 'Anomaly Detection',
      message: `Unusual size increase: ${formatBytes(diff.totalDiff)} for ${linesChanged} lines changed`,
      details: {
        totalDiff: diff.totalDiff,
        linesChanged,
        ratio: sizeIncreasePerLine.toFixed(2),
        explanation: 'Size increase seems disproportionate to code changes',
      },
    });
  }

  // Check for overall significant increase
  if (diff.baseSize > 0) {
    const increasePercent = (diff.totalDiff / diff.baseSize) * 100;
    if (increasePercent > THRESHOLDS.SIZE_INCREASE_PERCENT) {
      results.push({
        id: 'SIGNIFICANT_BUNDLE_GROWTH',
        severity: increasePercent > 50 ? 'critical' : 'warning',
        category: 'Bundle Growth',
        message: `Bundle grew by ${increasePercent.toFixed(1)}% (${formatBytes(diff.totalDiff)})`,
        details: {
          baseSize: diff.baseSize,
          prSize: diff.prSize,
          change: diff.totalDiff,
          percentage: increasePercent,
        },
      });
    }
  }

  return results;
}

/**
 * Detect heavy packages being added
 * @param {import('./diff-engine').BundleDiff} diff
 * @returns {RuleResult[]}
 */
function detectHeavyPackages(diff) {
  const results = [];

  for (const change of diff.added) {
    if (!change.packageName) continue;

    const isHeavy = HEAVY_PACKAGES.some(pkg =>
      change.packageName.toLowerCase().includes(pkg.toLowerCase())
    );

    if (isHeavy) {
      results.push({
        id: 'HEAVY_PACKAGE_ADDED',
        severity: 'info',
        category: 'Dependency Addition',
        message: `Heavy package added: ${change.packageName}`,
        details: {
          module: change.name,
          packageName: change.packageName,
          size: change.newSize,
          note: 'This is a known heavy package - consider lazy loading',
        },
      });
    }
  }

  return results;
}

/**
 * Detect potential duplicate dependencies
 * @param {import('./diff-engine').BundleDiff} diff
 * @returns {RuleResult[]}
 */
function detectDuplicateDependencies(diff) {
  const results = [];
  const packageVersions = new Map();

  // Collect all packages by base name
  for (const change of [...diff.added, ...diff.allChanges]) {
    if (!change.packageName) continue;

    // Extract base package name (handle scoped packages)
    const baseName = change.packageName.replace(/@[\d.]+$/, '').replace(/@[\d.]+-/, '@');

    if (!packageVersions.has(baseName)) {
      packageVersions.set(baseName, []);
    }
    packageVersions.get(baseName).push(change.packageName);
  }

  // Look for multiple versions
  for (const [baseName, versions] of packageVersions) {
    const uniqueVersions = [...new Set(versions)];
    if (uniqueVersions.length > 1) {
      results.push({
        id: 'POTENTIAL_DUPLICATES',
        severity: 'info',
        category: 'Dependency Management',
        message: `Multiple versions of ${baseName} detected`,
        details: {
          package: baseName,
          versions: uniqueVersions,
          suggestion: 'Consider deduplicating with npm dedupe or yarn resolutions',
        },
      });
    }
  }

  return results;
}

/**
 * Detect suspicious module patterns
 * @param {import('./diff-engine').BundleDiff} diff
 * @returns {RuleResult[]}
 */
function detectSuspiciousModules(diff) {
  const results = [];

  // Look for massive single module increases
  for (const change of diff.allChanges) {
    if (change.type !== 'changed') continue;

    const threshold = THRESHOLDS.SINGLE_MODULE_INCREASE_KB * 1024;
    if (change.change > threshold) {
      results.push({
        id: 'MASSIVE_MODULE_INCREASE',
        severity: 'critical',
        category: 'Size Anomaly',
        message: `Module grew by ${formatBytes(change.change)}: ${change.name}`,
        details: {
          module: change.name,
          oldSize: change.oldSize,
          newSize: change.newSize,
          change: change.change,
          isNodeModule: change.isNodeModule,
        },
      });
    }
  }

  return results;
}

/**
 * Detect new dependencies appearing in the bundle that are NOT in package.json
 * This is the primary guard against accidental bundle bloat.
 * Sub-dependencies of allowed packages are permitted (e.g., date-fns via react-datepicker).
 * @param {import('./diff-engine').BundleDiff} diff
 * @returns {RuleResult[]}
 */
function detectUnexpectedDependencies(diff) {
  const results = [];

  // Collect all newly-added packages from the bundle
  const newPackages = new Set();
  for (const change of diff.added) {
    if (change.packageName) {
      newPackages.add(change.packageName);
    }
  }

  // Load the actual package.json to get the real dependency list at runtime
  // This allows the tool to stay correct even if ALLOWED_DEPENDENCIES is stale
  let liveDeps = ALLOWED_DEPENDENCIES;
  try {
    const pkgPath = path.resolve(process.cwd(), 'package.json');
    if (fs.existsSync(pkgPath)) {
      const pkg = JSON.parse(fs.readFileSync(pkgPath, 'utf-8'));
      liveDeps = Object.keys(pkg.dependencies || {});
    }
  } catch {
    // Fall back to hardcoded list
  }

  // Also allow known transitive dependencies that are expected
  // (sub-deps of allowed packages that webpack naturally pulls in)
  const allowedPrefixes = liveDeps.map(dep => {
    // For scoped packages like @sentry/react, also allow @sentry/browser, @sentry/core, etc.
    const scopeMatch = dep.match(/^(@[^/]+)\//);
    return scopeMatch ? scopeMatch[1] : null;
  }).filter(Boolean);

  for (const pkg of newPackages) {
    const isDirectDep = liveDeps.some(dep => pkg === dep || pkg.startsWith(dep + '/'));
    const isFromAllowedScope = allowedPrefixes.some(prefix => pkg.startsWith(prefix + '/'));

    if (!isDirectDep && !isFromAllowedScope) {
      // Calculate total size of this unexpected package in the bundle
      const totalSize = diff.added
        .filter(c => c.packageName === pkg)
        .reduce((sum, c) => sum + (c.newSize || 0), 0);

      results.push({
        id: 'UNEXPECTED_DEPENDENCY',
        severity: totalSize > 50 * 1024 ? 'critical' : 'warning',
        category: 'Dependency Guard',
        message: `Unexpected dependency in bundle: ${pkg} (${formatBytes(totalSize)})`,
        details: {
          packageName: pkg,
          size: totalSize,
          sizeFormatted: formatBytes(totalSize),
          suggestion: `"${pkg}" is not listed in package.json dependencies. If intentional, add it explicitly. If not, this may be an accidental import pulling in unwanted code.`,
          importChain: diff.added
            .filter(c => c.packageName === pkg)
            .flatMap(c => c.importChain)
            .filter(Boolean)
            .slice(0, 5),
        },
      });
    }
  }

  return results;
}

/**
 * Get root cause of an import
 * @param {import('./diff-engine').ModuleChange} change
 * @returns {string}
 */
function getRootCause(change) {
  if (change.importChain.length === 0) return 'Unknown';

  for (const item of change.importChain) {
    if (!isNodeModule(item)) {
      return item.split('!').pop(); // Remove loader prefixes
    }
  }

  return change.importChain[0];
}

module.exports = {
  runDetection,
  detectLargeDependencyAdditions,
  detectNodeModulesIncrease,
  detectFullLibraryImports,
  detectTreeShakingFailures,
  detectSuddenSizeSpike,
  detectHeavyPackages,
  detectDuplicateDependencies,
  detectUnexpectedDependencies,
  THRESHOLDS,
  FULL_IMPORT_PATTERNS,
  HEAVY_PACKAGES,
  ALLOWED_DEPENDENCIES,
};
