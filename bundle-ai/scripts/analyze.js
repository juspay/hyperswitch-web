#!/usr/bin/env node
/**
 * @fileoverview Analyze Script
 * Runs rule detection and AI analysis on bundle diff
 */

const fs = require('fs');
const path = require('path');

// Load .env file from bundle-ai directory (no external dependency needed)
const envPath = path.join(__dirname, '..', '.env');
if (fs.existsSync(envPath)) {
  const envContent = fs.readFileSync(envPath, 'utf-8');
  for (const line of envContent.split('\n')) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) continue;
    const eqIdx = trimmed.indexOf('=');
    if (eqIdx === -1) continue;
    const key = trimmed.slice(0, eqIdx).trim();
    const value = trimmed.slice(eqIdx + 1).trim();
    if (!process.env[key]) {
      process.env[key] = value;
    }
  }
}

const { runDetection } = require('../lib/rule-engine');
const { createClient, analyzeBundle, analyzeOffline, isAIAvailable } = require('../lib/ai-client');
const { runDiff } = require('./diff');

/**
 * Run full analysis on bundle stats
 * @param {string} baseStatsPath - Path to base stats
 * @param {string} prStatsPath - Path to PR stats
 * @param {Object} context - Additional context for analysis
 * @param {Object} options - Analysis options
 * @returns {Promise<Object>} Analysis results
 */
async function runAnalysis(baseStatsPath, prStatsPath, context = {}, options = {}) {
  const log = options.silent ? () => {} : console.log;

  log('Running bundle analysis...\n');

  // Step 1: Compute diff
  log('Step 1: Computing bundle diff...');
  const { diff, summary, baseStats, prStats } = runDiff(baseStatsPath, prStatsPath, { ...options, silent: true });
  log(`  ✓ Found ${diff.allChanges.length} changes`);
  log(`  ✓ Total diff: ${diff.totalDiffFormatted}\n`);

  // Step 2: Run rule detection
  log('Step 2: Running detection rules...');
  const detections = runDetection(diff, { baseStats: diff.baseStats });
  log(`  ✓ ${detections.violations.length} issues detected`);
  log(`    - Critical: ${detections.critical.length}`);
  log(`    - Warnings: ${detections.warnings.length}`);
  log(`    - Info: ${detections.info.length}\n`);

  // Step 3: Run AI analysis if available
  log('Step 3: AI Analysis...');
  let aiResult;

  // Attach raw parsed stats to context so AI prompt can extract deep data
  const enrichedContext = { ...context, rawStats: { baseStats, prStats } };

  if (!options.skipAI && isAIAvailable()) {
    try {
      const client = createClient(options.aiOptions);
      aiResult = await analyzeBundle(client, diff, detections, enrichedContext);
      log(`  ✓ AI analysis complete`);
      log(`    Verdict: ${aiResult.verdict}`);
      log(`    Confidence: ${(aiResult.confidence * 100).toFixed(0)}%\n`);
    } catch (error) {
      if (!options.silent) console.warn(`  ⚠ AI analysis failed: ${error.message}`);
      aiResult = analyzeOffline(diff, detections);
    }
  } else {
    log('  ℹ Running offline analysis (no AI available)');
    aiResult = analyzeOffline(diff, detections);
  }

  // Step 4: Generate report
  log('Step 4: Generating report...\n');
  const report = generateAnalysisReport(diff, detections, aiResult, context);

  return {
    diff,
    summary,
    detections,
    ai: aiResult,
    report,
  };
}

/**
 * Generate comprehensive analysis report
 * @param {import('../lib/diff-engine').BundleDiff} diff
 * @param {import('../lib/rule-engine').DetectionResults} detections
 * @param {import('../lib/ai-client').AIAnalysisResult} aiResult
 * @param {Object} context
 * @returns {string}
 */
function generateAnalysisReport(diff, detections, aiResult, context) {
  const lines = [];

  // Header
  lines.push('╔══════════════════════════════════════════════════════════════╗');
  lines.push('║                  BUNDLE ANALYSIS REPORT                      ║');
  lines.push('╚══════════════════════════════════════════════════════════════╝');
  lines.push('');

  // Summary Section
  lines.push('📊 SUMMARY');
  lines.push('─'.repeat(60));
  lines.push(`Base Branch Size:  ${diff.baseSizeFormatted}`);
  lines.push(`PR Branch Size:    ${diff.prSizeFormatted}`);
  lines.push(`Total Change:      ${diff.totalDiffFormatted}`);

  if (diff.baseSize > 0) {
    const percent = ((diff.totalDiff / diff.baseSize) * 100).toFixed(1);
    const sign = diff.totalDiff >= 0 ? '+' : '';
    lines.push(`Percentage:        ${sign}${percent}%`);
  }

  lines.push(`node_modules:      ${diff.nodeModulesDiff >= 0 ? '+' : ''}${formatBytes(diff.nodeModulesDiff)}`);

  if (context.linesChanged) {
    lines.push(`Lines Changed:     ${context.linesChanged}`);
  }
  lines.push('');

  // AI Verdict Section
  lines.push('🤖 AI VERDICT');
  lines.push('─'.repeat(60));

  const verdictEmoji = {
    expected: '✅',
    unexpected: '⚠️',
    needs_review: '🔍',
  };

  lines.push(`${verdictEmoji[aiResult.verdict] || '❓'} ${aiResult.verdict.toUpperCase()}`);
  lines.push(`Confidence: ${(aiResult.confidence * 100).toFixed(0)}%`);
  lines.push('');
  lines.push('Explanation:');
  lines.push(`  ${aiResult.explanation}`);
  lines.push('');
  lines.push('Root Cause:');
  lines.push(`  ${aiResult.rootCause}`);
  lines.push('');

  // Suggested Fixes
  if (aiResult.suggestedFixes.length > 0) {
    lines.push('Suggested Fixes:');
    aiResult.suggestedFixes.forEach((fix, i) => {
      lines.push(`  ${i + 1}. ${fix}`);
    });
    lines.push('');
  }

  // Detection Results
  if (detections.violations.length > 0) {
    lines.push('🚨 DETECTED ISSUES');
    lines.push('─'.repeat(60));

    // Critical
    if (detections.critical.length > 0) {
      lines.push('\n🔴 CRITICAL:');
      for (const v of detections.critical) {
        lines.push(`   • ${v.message}`);
        if (v.details?.module) {
          lines.push(`     Module: ${v.details.module}`);
        }
      }
    }

    // Warnings
    if (detections.warnings.length > 0) {
      lines.push('\n🟡 WARNINGS:');
      for (const v of detections.warnings.slice(0, 10)) {
        lines.push(`   • ${v.message}`);
        if (v.details?.suggestion) {
          lines.push(`     💡 ${v.details.suggestion}`);
        }
      }
    }

    lines.push('');
  }

  // Top Changes
  if (diff.topChanges.length > 0) {
    lines.push('📈 TOP CHANGES');
    lines.push('─'.repeat(60));

    for (const change of diff.topChanges.slice(0, 15)) {
      const symbol = change.type === 'added' ? '+' : change.type === 'removed' ? '-' : '~';
      lines.push(`${symbol} ${change.name}`);
      lines.push(`  ${change.changeFormatted}`);

      if (change.importChain.length > 0) {
        const chain = formatImportChain(change.importChain);
        lines.push(`  via: ${chain}`);
      }
      lines.push('');
    }
  }

  // Package Changes
  const pkgChanges = Object.entries(diff.packageDiffs)
    .filter(([, change]) => Math.abs(change) > 1024)
    .slice(0, 10);

  if (pkgChanges.length > 0) {
    lines.push('📦 PACKAGE CHANGES');
    lines.push('─'.repeat(60));

    for (const [pkg, change] of pkgChanges) {
      const sign = change > 0 ? '+' : '';
      lines.push(`  ${sign}${formatBytes(change).padStart(10)}  ${pkg}`);
    }
    lines.push('');
  }

  // Footer
  lines.push('═'.repeat(64));
  lines.push(`Generated: ${new Date().toISOString()}`);
  lines.push('═'.repeat(64));

  return lines.join('\n');
}

/**
 * Generate JSON analysis output
 * @param {Object} analysis
 * @returns {Object}
 */
function generateJSONOutput(analysis) {
  const { diff, detections, ai } = analysis;

  return {
    summary: {
      baseSize: diff.baseSize,
      prSize: diff.prSize,
      totalDiff: diff.totalDiff,
      totalDiffFormatted: diff.totalDiffFormatted,
      nodeModulesDiff: diff.nodeModulesDiff,
    },
    aiAnalysis: {
      verdict: ai.verdict,
      confidence: ai.confidence,
      explanation: ai.explanation,
      rootCause: ai.rootCause,
      suggestedFixes: ai.suggestedFixes,
    },
    issues: {
      critical: detections.critical.length,
      warnings: detections.warnings.length,
      info: detections.info.length,
      details: detections.violations.map(v => ({
        id: v.id,
        severity: v.severity,
        category: v.category,
        message: v.message,
        details: v.details,
      })),
    },
    changes: {
      top: diff.topChanges.slice(0, 20).map(c => ({
        name: c.name,
        type: c.type,
        change: c.change,
        changeFormatted: c.changeFormatted,
        isNodeModule: c.isNodeModule,
        packageName: c.packageName,
        importChain: c.importChain,
      })),
      packages: Object.entries(diff.packageDiffs).map(([name, change]) => ({
        name,
        change,
        changeFormatted: formatBytes(change),
      })),
    },
  };
}

/**
 * Format import chain for display
 * @param {string[]} chain
 * @returns {string}
 */
function formatImportChain(chain) {
  if (chain.length === 0) return 'unknown';

  // Take last 3 entries for brevity
  const relevant = chain.slice(-3);
  return relevant.join(' ← ');
}

/**
 * Format bytes as a diff value (with +/- sign for diffs)
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
Usage: node analyze.js --base <base-stats.json> --pr <pr-stats.json> [options]

Options:
  --base <path>       Path to base stats file (required)
  --pr <path>         Path to PR stats file (required)
  --lines <n>         Lines changed in PR (for context)
  --skip-ai           Skip AI analysis
  --json              Output as JSON
  --output <path>     Save report to file
  --api-key <key>     OpenAI API key (or set OPENAI_API_KEY)
  --model <model>     OpenAI model (default: kimi-latest)
`);
    process.exit(1);
  }

  const context = {};
  if (options.lines) {
    context.linesChanged = parseInt(options.lines, 10);
  }

  const aiOptions = {};
  if (options.apiKey) aiOptions.apiKey = options.apiKey;
  if (options.model) aiOptions.model = options.model;

  runAnalysis(options.base, options.pr, context, {
    ...options,
    silent: !!options.json,
    aiOptions,
  })
    .then(analysis => {
      if (options.json) {
        const jsonOutput = generateJSONOutput(analysis);
        process.stdout.write(JSON.stringify(jsonOutput, null, 2) + '\n');
      } else {
        console.log(analysis.report);
      }

      // Save to file if requested
      if (options.output) {
        const fs = require('fs');
        if (options.json) {
          fs.writeFileSync(options.output, JSON.stringify(generateJSONOutput(analysis), null, 2));
        } else {
          fs.writeFileSync(options.output, analysis.report);
        }
        if (!options.json) {
          console.log(`\nReport saved to: ${options.output}`);
        }
      }

      // Exit with error code if critical issues
      process.exit(analysis.detections.hasCriticalIssues ? 1 : 0);
    })
    .catch(error => {
      console.error('Error:', error.message);
      process.exit(1);
    });
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
      case '--lines':
      case '-l':
        options.lines = args[++i];
        break;
      case '--output':
      case '-o':
        options.output = args[++i];
        break;
      case '--api-key':
      case '-k':
        options.apiKey = args[++i];
        break;
      case '--model':
      case '-m':
        options.model = args[++i];
        break;
      case '--skip-ai':
        options.skipAI = true;
        break;
      case '--json':
      case '-j':
        options.json = true;
        break;
      case '--help':
      case '-h':
        console.log(`
Usage: node analyze.js --base <base-stats.json> --pr <pr-stats.json> [options]

Run full analysis on bundle stats including rule detection and AI analysis.

Options:
  -b, --base <path>     Path to base stats file (required)
  -p, --pr <path>       Path to PR stats file (required)
  -l, --lines <n>       Lines changed in PR
  -o, --output <path>   Save report to file
  -k, --api-key <key>   OpenAI API key
  -m, --model <model>   OpenAI model
  --skip-ai             Skip AI analysis
  -j, --json            Output as JSON
  -h, --help            Show this help
`);
        process.exit(0);
    }
  }

  return options;
}

module.exports = {
  runAnalysis,
  generateAnalysisReport,
  generateJSONOutput,
};
