#!/usr/bin/env node
/**
 * @fileoverview Main CLI Entry Point
 * Bundle AI - AI-powered bundle analyzer and optimization system
 *
 * Usage:
 *   node bundle-ai/cli.js --base main --head current    # Local mode with branch comparison
 *   node bundle-ai/cli.js --base-stats base.json --pr-stats pr.json  # File mode
 */

const fs = require("fs");
const path = require("path");
const { execSync } = require("child_process");

// Load .env file from bundle-ai directory (no external dependency needed)
const envPath = path.join(__dirname, ".env");
if (fs.existsSync(envPath)) {
  const envContent = fs.readFileSync(envPath, "utf-8");
  for (const line of envContent.split("\n")) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith("#")) continue;
    const eqIdx = trimmed.indexOf("=");
    if (eqIdx === -1) continue;
    const key = trimmed.slice(0, eqIdx).trim();
    const value = trimmed.slice(eqIdx + 1).trim();
    if (!process.env[key]) {
      process.env[key] = value;
    }
  }
}

const { buildStatsForRef } = require("./scripts/build-stats");
const { runAnalysis } = require("./scripts/analyze");
const { generateComment, upsertComment } = require("./scripts/comment");
const {
  analyzeReScriptChanges,
  generateReScriptSummary,
} = require("./lib/rescript-analyzer");

// ANSI color codes
const colors = {
  reset: "\x1b[0m",
  red: "\x1b[31m",
  green: "\x1b[32m",
  yellow: "\x1b[33m",
  blue: "\x1b[34m",
  magenta: "\x1b[35m",
  cyan: "\x1b[36m",
  bold: "\x1b[1m",
};

/**
 * Whether to use colors (only on TTY, not when piped)
 */
const useColors = process.stdout.isTTY === true;

/**
 * Print colored message (strips ANSI when not a TTY)
 * @param {string} msg
 * @param {string} color
 */
function print(msg, color = "") {
  if (useColors) {
    console.log(`${colors[color] || ""}${msg}${colors.reset}`);
  } else {
    console.log(msg);
  }
}

/**
 * Print banner
 */
function printBanner() {
  print("");
  print(
    "╔══════════════════════════════════════════════════════════════╗",
    "cyan",
  );
  print(
    "║            HYPERSWITCH PRODUCTION BUNDLE ANALYZER            ║",
    "cyan",
  );
  print(
    "╚══════════════════════════════════════════════════════════════╝",
    "cyan",
  );
  print("");
}

/**
 * Main entry point
 */
async function main() {
  const args = process.argv.slice(2);
  const options = parseArgs(args);

  if (options.help) {
    printHelp();
    process.exit(0);
  }

  if (options.version) {
    printVersion();
    process.exit(0);
  }

  // Only print banner if not in JSON-only mode
  if (options.json !== true) {
    printBanner();
  }

  // Determine mode
  const mode = determineMode(options);

  try {
    let result;

    if (mode === "local-branches") {
      result = await runLocalBranchMode(options);
    } else if (mode === "file-mode") {
      result = await runFileMode(options);
    } else {
      print(
        "Error: Invalid mode. Use --base/--head for branch mode or --base-stats/--pr-stats for file mode.",
        "red",
      );
      printHelp();
      process.exit(1);
    }

    // Output results
    await outputResults(result, options);

    // Exit with appropriate code
    const exitCode = result.analysis.detections.hasCriticalIssues ? 1 : 0;
    process.exit(exitCode);
  } catch (error) {
    print(`\n❌ Error: ${error.message}`, "red");
    if (options.verbose) {
      console.error(error.stack);
    }
    process.exit(1);
  }
}

/**
 * Run in local branch comparison mode
 * @param {Object} options
 * @returns {Promise<Object>}
 */
async function runLocalBranchMode(options) {
  print(`Comparing branches: ${options.base} → ${options.head}`, "blue");
  print("");

  // Step 1: Analyze ReScript changes
  print("Step 1: Analyzing ReScript changes...", "cyan");
  const rescriptAnalysis = analyzeReScriptChanges(options.base, options.head);
  if (rescriptAnalysis.filesChanged.length > 0) {
    print(
      `  ✓ ${rescriptAnalysis.filesChanged.length} .res files changed`,
      "green",
    );
    print(
      `  ✓ ${rescriptAnalysis.importsAdded.length} new imports detected`,
      "green",
    );
  } else {
    print("  ℹ No ReScript changes detected", "yellow");
  }
  print("");

  // Step 2: Build base stats
  print(`Step 2: Building stats for base branch: ${options.base}`, "cyan");
  const baseStatsPath = await buildStatsForRef(options.base, {
    outputPath: path.join(
      ".bundle-ai-cache",
      `stats-base-${options.base.replace(/[^a-zA-Z0-9_-]/g, "_")}.json`,
    ),
    verbose: options.verbose,
  });
  print(`  ✓ Base stats saved: ${baseStatsPath}`, "green");
  print("");

  // Step 3: Build PR stats
  print(`Step 3: Building stats for PR branch: ${options.head}`, "cyan");
  const prStatsPath = await buildStatsForRef(options.head, {
    outputPath: path.join(
      ".bundle-ai-cache",
      `stats-head-${options.head.replace(/[^a-zA-Z0-9_-]/g, "_")}.json`,
    ),
    verbose: options.verbose,
  });
  print(`  ✓ PR stats saved: ${prStatsPath}`, "green");
  print("");

  // Step 4: Get lines changed
  const linesChanged = getLinesChanged(options.base, options.head);
  print(`Lines changed: ${linesChanged}`, "blue");
  print("");

  // Step 5: Run analysis
  print("Step 4: Running bundle analysis...", "cyan");
  const context = {
    linesChanged,
    reScriptAnalysis:
      rescriptAnalysis.filesChanged.length > 0
        ? generateReScriptSummary(rescriptAnalysis, { nodeModulesDiff: 0 })
        : null,
  };

  const analysis = await runAnalysis(baseStatsPath, prStatsPath, context, {
    skipAI: options.skipAI,
    aiOptions: {
      apiKey: process.env.OPENAI_API_KEY,
      model: options.model,
    },
  });

  return { analysis, context, baseStatsPath, prStatsPath };
}

/**
 * Run in file mode (pre-built stats)
 * @param {Object} options
 * @returns {Promise<Object>}
 */
async function runFileMode(options) {
  if (options.json !== true) {
    print("Running in file mode (pre-built stats)", "blue");
    print(`Base stats: ${options.baseStats}`, "cyan");
    print(`PR stats: ${options.prStats}`, "cyan");
    print("");
  }

  // Verify files exist
  if (!fs.existsSync(options.baseStats)) {
    throw new Error(`Base stats file not found: ${options.baseStats}`);
  }
  if (!fs.existsSync(options.prStats)) {
    throw new Error(`PR stats file not found: ${options.prStats}`);
  }

  const context = {
    linesChanged: options.lines ? parseInt(options.lines, 10) : undefined,
  };

  const analysis = await runAnalysis(
    options.baseStats,
    options.prStats,
    context,
    {
      skipAI: options.skipAI,
      silent: options.json === true,
      aiOptions: {
        apiKey: process.env.OPENAI_API_KEY,
        model: options.model,
      },
    },
  );

  return {
    analysis,
    context,
    baseStatsPath: options.baseStats,
    prStatsPath: options.prStats,
  };
}

/**
 * Output results based on options
 * @param {Object} result
 * @param {Object} options
 */
async function outputResults(result, options) {
  const { analysis, context } = result;

  // If --json with no file path (stdout mode), output ONLY clean JSON and return
  if (options.json === true) {
    const jsonOutput = JSON.stringify(
      {
        summary: {
          baseSize: analysis.diff.baseSize,
          prSize: analysis.diff.prSize,
          totalDiff: analysis.diff.totalDiff,
          totalDiffFormatted: analysis.diff.totalDiffFormatted,
        },
        ai: analysis.ai,
        issues: analysis.detections.violations.length,
      },
      null,
      2,
    );
    process.stdout.write(jsonOutput + "\n");
    return;
  }

  // Print CLI report
  print("", "bold");
  print(analysis.report);

  // Save comment text for PR
  const comment = generateComment(analysis, options);

  if (options.commentFile) {
    fs.writeFileSync(options.commentFile, comment);
    print(`\n✓ Comment saved to: ${options.commentFile}`, "green");
  }

  // Save JSON output to file
  if (options.json) {
    const jsonOutput = JSON.stringify(
      {
        summary: {
          baseSize: analysis.diff.baseSize,
          prSize: analysis.diff.prSize,
          totalDiff: analysis.diff.totalDiff,
          totalDiffFormatted: analysis.diff.totalDiffFormatted,
        },
        ai: analysis.ai,
        issues: analysis.detections.violations.length,
      },
      null,
      2,
    );

    fs.writeFileSync(options.json, jsonOutput);
    print(`\n✓ JSON output saved to: ${options.json}`, "green");
  }

  // Post to GitHub if requested
  if (options.postComment) {
    print("\nPosting comment to GitHub PR...", "cyan");
    try {
      await upsertComment(comment, { prNumber: options.prNumber });
      print("✓ Comment posted/updated", "green");
    } catch (error) {
      print(`⚠ Failed to post comment: ${error.message}`, "yellow");
    }
  }
}

/**
 * Determine which mode to run
 * @param {Object} options
 * @returns {'local-branches'|'file-mode'|null}
 */
function determineMode(options) {
  // File mode takes precedence if stats files are provided
  if (options.baseStats && options.prStats) {
    return "file-mode";
  }
  // Otherwise use branch mode
  if (options.base && options.head) {
    return "local-branches";
  }
  return null;
}

/**
 * Get lines changed between branches
 * @param {string} base
 * @param {string} head
 * @returns {number}
 */
function getLinesChanged(base, head) {
  try {
    const output = execSync(
      `git diff --numstat ${base}...${head} | awk '{sum+=$1+$2} END {print sum}'`,
      {
        encoding: "utf-8",
        cwd: process.cwd(),
      },
    );
    return parseInt(output.trim(), 10) || 0;
  } catch {
    return 0;
  }
}

/**
 * Parse CLI arguments
 * @param {string[]} args
 * @returns {Object}
 */
function parseArgs(args) {
  const options = {
    // Default values
    base: "main",
    head: "HEAD",
    model: "kimi-latest",
  };

  for (let i = 0; i < args.length; i++) {
    const arg = args[i];

    switch (arg) {
      // Branch mode
      case "--base":
      case "-b":
        options.base = args[++i];
        break;
      case "--head":
        options.head = args[++i];
        break;

      // File mode
      case "--base-stats":
        options.baseStats = args[++i];
        break;
      case "--pr-stats":
        options.prStats = args[++i];
        break;

      // Options
      case "--lines":
      case "-l":
        options.lines = args[++i];
        break;
      case "--skip-ai":
        options.skipAI = true;
        break;
      case "--model":
      case "-m":
        options.model = args[++i];
        break;
      case "--comment-file":
        options.commentFile = args[++i];
        break;
      case "--json":
      case "-j":
        options.json = true;
        // If next arg doesn't start with --, it's a file path
        if (args[i + 1] && !args[i + 1].startsWith("--")) {
          options.json = args[++i];
        }
        break;
      case "--post-comment":
        options.postComment = true;
        break;
      case "--pr":
        options.prNumber = args[++i];
        break;
      case "--verbose":
      case "-v":
        options.verbose = true;
        break;

      // Meta
      case "--version":
        options.version = true;
        break;
      case "--help":
      case "-h":
        options.help = true;
        break;

      default:
        if (arg.startsWith("-")) {
          console.warn(`Unknown option: ${arg}`);
        }
    }
  }

  return options;
}

/**
 * Print help message
 */
function printHelp() {
  print(`
Usage: node bundle-ai/cli.js [options]

MODES:

  Branch Mode (for local testing):
    node bundle-ai/cli.js --base main --head my-feature

  File Mode (for CI):
    node bundle-ai/cli.js --base-stats base.json --pr-stats pr.json

OPTIONS:

  Branch Mode:
    --base <branch>       Base branch to compare against (default: main)
    --head <branch>       PR branch to analyze (default: HEAD)

  File Mode:
    --base-stats <path>   Path to base stats JSON
    --pr-stats <path>     Path to PR stats JSON

  Analysis:
    --skip-ai             Skip AI analysis (rules only)
    --model <model>       OpenAI model (default: kimi-latest)
    --lines <n>           Lines changed in PR

  Output:
    --comment-file <path> Save PR comment to file
    --json [path]         Output JSON (to stdout or file)
    --post-comment        Post/update comment on GitHub PR
    --pr <number>         PR number (for posting comment)

  Other:
    -v, --verbose         Show detailed output
    -h, --help            Show this help
    --version             Show version

ENVIRONMENT VARIABLES:

  OPENAI_API_KEY          OpenAI API key for AI analysis
  GITHUB_TOKEN            GitHub token for posting comments
  GITHUB_REPOSITORY       Repository name (owner/repo)

EXAMPLES:

  # Local testing - compare current branch to main
  node bundle-ai/cli.js

  # Local testing - specific branches
  node bundle-ai/cli.js --base develop --head feature/new-ui

  # CI mode with pre-built stats
  node bundle-ai/cli.js --base-stats ./stats/base.json --pr-stats ./stats/pr.json

  # Dry run without AI (faster)
  node bundle-ai/cli.js --skip-ai

  # Save JSON output
  node bundle-ai/cli.js --json output.json
`);
}

/**
 * Print version
 */
function printVersion() {
  print("Bundle AI v1.0.0");
}

// Run main
if (require.main === module) {
  main().catch((error) => {
    console.error("Fatal error:", error);
    process.exit(1);
  });
}

module.exports = {
  main,
  runLocalBranchMode,
  runFileMode,
};
