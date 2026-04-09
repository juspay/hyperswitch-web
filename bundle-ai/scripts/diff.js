#!/usr/bin/env node
/**
 * @fileoverview Diff Script
 * Compares two webpack stats files and generates diff report
 */

const { computeDiff, generateSummary } = require('../lib/diff-engine');
const { loadStatsFromFile } = require('../lib/stats-parser');

/**
 * Run diff between two stats files
 * @param {string} baseStatsPath - Path to base stats JSON
 * @param {string} prStatsPath - Path to PR stats JSON
 * @param {Object} options
 * @returns {Object} Diff result with report
 */
function runDiff(baseStatsPath, prStatsPath, options = {}) {
  const log = options.silent ? () => {} : console.log;

  log(`Loading base stats: ${baseStatsPath}`);
  const baseStats = loadStatsFromFile(baseStatsPath);

  log(`Loading PR stats: ${prStatsPath}`);
  const prStats = loadStatsFromFile(prStatsPath);

  log('\nComputing diff...');
  const diff = computeDiff(baseStats, prStats);

  const summary = generateSummary(diff);

  // Generate report
  const report = generateReport(diff, summary, options);

  return {
    diff,
    summary,
    report,
    baseStats,
    prStats,
  };
}

/**
 * Generate human-readable report
 * @param {import('../lib/diff-engine').BundleDiff} diff
 * @param {Object} summary
 * @param {Object} options
 * @returns {string}
 */
function generateReport(diff, summary, options = {}) {
  const lines = [];

  lines.push('='.repeat(60));
  lines.push('BUNDLE DIFF REPORT');
  lines.push('='.repeat(60));
  lines.push('');

  // Summary section
  lines.push('## Summary');
  lines.push(`Base Size:  ${diff.baseSizeFormatted}`);
  lines.push(`PR Size:    ${diff.prSizeFormatted}`);
  lines.push(`Change:     ${diff.totalDiffFormatted}`);
  lines.push(`node_modules: ${diff.nodeModulesDiff >= 0 ? '+' : ''}${formatBytes(diff.nodeModulesDiff)}`);
  lines.push('');

  // Top changes
  if (diff.topChanges.length > 0) {
    lines.push('## Top Changes');
    lines.push('');

    for (const change of diff.topChanges.slice(0, options.topCount || 20)) {
      const symbol = change.type === 'added' ? '+' : change.type === 'removed' ? '-' : '~';
      lines.push(`${symbol} ${change.name}`);
      lines.push(`  Size: ${change.changeFormatted}`);

      if (change.importChain.length > 0) {
        const chain = change.importChain.slice(0, 3).join(' ← ');
        lines.push(`  Via: ${chain}`);
      }

      if (change.packageName) {
        lines.push(`  Package: ${change.packageName}`);
      }

      lines.push('');
    }
  }

  // Added modules
  const significantAdded = diff.added
    .filter(m => m.newSize > (options.minSize || 1024))
    .sort((a, b) => b.newSize - a.newSize);

  if (significantAdded.length > 0) {
    lines.push('## New Modules');
    lines.push('');

    for (const change of significantAdded.slice(0, 10)) {
      lines.push(`+ ${change.name} (${formatBytes(change.newSize)})`);
    }
    lines.push('');
  }

  // Removed modules
  const significantRemoved = diff.removed
    .filter(m => m.oldSize > (options.minSize || 1024))
    .sort((a, b) => b.oldSize - a.oldSize);

  if (significantRemoved.length > 0) {
    lines.push('## Removed Modules');
    lines.push('');

    for (const change of significantRemoved.slice(0, 10)) {
      lines.push(`- ${change.name} (${formatBytes(change.oldSize)})`);
    }
    lines.push('');
  }

  // Package changes
  const pkgChanges = Object.entries(diff.packageDiffs)
    .filter(([, change]) => Math.abs(change) >= (options.minSize || 1024))
    .slice(0, 15);

  if (pkgChanges.length > 0) {
    lines.push('## Package Changes');
    lines.push('');

    for (const [pkg, change] of pkgChanges) {
      const sign = change > 0 ? '+' : '';
      lines.push(`${sign}${formatBytes(change)} ${pkg}`);
    }
    lines.push('');
  }

  // Summary insights
  lines.push('## Insights');
  lines.push(`- Total modules changed: ${diff.allChanges.length}`);
  lines.push(`- New modules: ${diff.added.length}`);
  lines.push(`- Removed modules: ${diff.removed.length}`);
  lines.push(`- Changed modules: ${diff.allChanges.filter(c => c.type === 'changed').length}`);

  if (summary.isSignificant) {
    lines.push(`- ⚠️ Significant size change detected`);
  }

  lines.push('');
  lines.push('='.repeat(60));

  return lines.join('\n');
}

/**
 * Generate JSON report
 * @param {import('../lib/diff-engine').BundleDiff} diff
 * @param {Object} summary
 * @returns {Object}
 */
function generateJSONReport(diff, summary) {
  return {
    summary: {
      baseSize: diff.baseSize,
      prSize: diff.prSize,
      totalDiff: diff.totalDiff,
      totalDiffFormatted: diff.totalDiffFormatted,
      nodeModulesDiff: diff.nodeModulesDiff,
      hasSignificantChanges: summary.isSignificant,
    },
    topChanges: diff.topChanges.map(c => ({
      name: c.name,
      type: c.type,
      change: c.change,
      changeFormatted: c.changeFormatted,
      importChain: c.importChain,
      isNodeModule: c.isNodeModule,
      packageName: c.packageName,
    })),
    packages: Object.entries(diff.packageDiffs).map(([name, change]) => ({
      name,
      change,
      changeFormatted: formatBytes(change),
    })),
    counts: {
      added: diff.added.length,
      removed: diff.removed.length,
      changed: diff.allChanges.filter(c => c.type === 'changed').length,
      total: diff.allChanges.length,
    },
  };
}

/**
 * Format bytes helper
 * @param {number} bytes
 * @returns {string}
 */
function formatBytes(bytes) {
  if (bytes === 0) return '0 B';
  const k = 1024;
  const sizes = ['B', 'KB', 'MB', 'GB'];
  const i = Math.floor(Math.log(Math.abs(bytes)) / Math.log(k));
  return (bytes >= 0 ? '+' : '-') + parseFloat((Math.abs(bytes) / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
}

/**
 * CLI entry point
 */
if (require.main === module) {
  const args = process.argv.slice(2);
  const options = parseArgs(args);

  if (!options.base || !options.pr) {
    console.error('Error: Both --base and --pr stats files are required');
    console.log(`
Usage: node diff.js --base <base-stats.json> --pr <pr-stats.json> [options]

Options:
  --base <path>       Path to base stats file (required)
  --pr <path>         Path to PR stats file (required)
  --output <path>     Save report to file
  --json              Output as JSON
  --top <n>           Show top N changes (default: 20)
  --min-size <bytes>  Minimum size to include (default: 1024)
`);
    process.exit(1);
  }

  try {
    const result = runDiff(options.base, options.pr, options);

    if (options.json) {
      const jsonReport = generateJSONReport(result.diff, result.summary);
      console.log(JSON.stringify(jsonReport, null, 2));
    } else {
      console.log(result.report);
    }

    // Save to file if requested
    if (options.output) {
      const fs = require('fs');
      if (options.json) {
        fs.writeFileSync(options.output, JSON.stringify(generateJSONReport(result.diff, result.summary), null, 2));
      } else {
        fs.writeFileSync(options.output, result.report);
      }
      console.log(`\nReport saved to: ${options.output}`);
    }

    process.exit(0);
  } catch (error) {
    console.error('Error:', error.message);
    process.exit(1);
  }
}

/**
 * Parse CLI arguments
 * @param {string[]} args
 * @returns {Object}
 */
function parseArgs(args) {
  const options = {};

  for (let i = 0; i < args.length; i++) {
    const arg = args[i];

    switch (arg) {
      case '--base':
      case '-b':
        options.base = args[++i];
        break;
      case '--pr':
      case '-p':
        options.pr = args[++i];
        break;
      case '--output':
      case '-o':
        options.output = args[++i];
        break;
      case '--json':
      case '-j':
        options.json = true;
        break;
      case '--top':
      case '-t':
        options.topCount = parseInt(args[++i], 10);
        break;
      case '--min-size':
        options.minSize = parseInt(args[++i], 10);
        break;
      case '--help':
      case '-h':
        console.log(`
Usage: node diff.js --base <base-stats.json> --pr <pr-stats.json> [options]

Compare two webpack stats files and show the differences.

Options:
  -b, --base <path>     Path to base stats file (required)
  -p, --pr <path>       Path to PR stats file (required)
  -o, --output <path>   Save report to file
  -j, --json            Output as JSON
  -t, --top <n>         Show top N changes (default: 20)
  --min-size <bytes>    Minimum size to include (default: 1024)
  -h, --help            Show this help
`);
        process.exit(0);
    }
  }

  return options;
}

module.exports = {
  runDiff,
  generateReport,
  generateJSONReport,
};
