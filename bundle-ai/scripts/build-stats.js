#!/usr/bin/env node
/**
 * @fileoverview Build Stats Script
 * Runs webpack with --profile --json and saves stats to file
 */

const { execSync, spawn } = require('child_process');
const fs = require('fs');
const path = require('path');

/**
 * Build webpack stats for current project
 * Production builds only for bundle analysis
 * @param {Object} options
 * @param {string} [options.outputPath] - Where to save stats
 * @param {string} [options.webpackConfig] - Path to webpack config
 * @param {string} [options.mode] - webpack mode (production/development)
 * @param {boolean} [options.verbose] - Show webpack output
 * @returns {Promise<string>} Path to generated stats file
 */
async function buildStats(options = {}) {
  const outputPath = options.outputPath || 'bundle-stats.json';
  const webpackConfig = options.webpackConfig || findWebpackConfig();
  
  // FORCE production mode for accurate bundle analysis
  const mode = 'production';

  console.log(`Building webpack stats for PRODUCTION bundle analysis...`);
  console.log(`Output: ${outputPath}`);

  // Build webpack command
  const args = ['--profile', '--json'];

  if (webpackConfig) {
    args.push('--config', webpackConfig);
  }

  args.push('--mode', mode);

  // Add any additional webpack options
  if (options.analyze) {
    console.log('Running with detailed analysis...');
  }

  return new Promise((resolve, reject) => {
    const webpackCmd = getWebpackCommand();
    console.log(`Running: ${webpackCmd} ${args.join(' ')}`);

    const child = spawn(webpackCmd, args, {
      stdio: ['inherit', 'pipe', 'pipe'],
      cwd: process.cwd(),
      shell: true,
      env: {
        ...process.env,
        NODE_ENV: mode,
        // sdkEnv and SDK_VERSION are inherited from process.env via spread above.
        // Override only if explicitly provided via options.
        ...(options.sdkEnv ? { sdkEnv: options.sdkEnv } : {}),
        ...(options.sdkVersion ? { SDK_VERSION: options.sdkVersion } : {}),
      },
    });

    let stdout = '';
    let stderr = '';

    child.stdout.on('data', data => {
      stdout += data.toString();
      if (options.verbose) {
        process.stdout.write(data);
      }
    });

    child.stderr.on('data', data => {
      stderr += data.toString();
      if (options.verbose) {
        process.stderr.write(data);
      }
    });

    child.on('close', code => {
      // Webpack often exits 0 even with warnings
      if (code !== 0 && !stdout.includes('modules')) {
        console.error('Webpack build failed:', stderr);
        reject(new Error(`Webpack exited with code ${code}: ${stderr}`));
        return;
      }

      try {
        // Find the JSON output (webpack may output non-JSON before/after)
        const jsonStart = stdout.indexOf('{');
        const jsonEnd = stdout.lastIndexOf('}') + 1;

        if (jsonStart === -1 || jsonEnd <= jsonStart) {
          reject(new Error('Could not find JSON output in webpack output'));
          return;
        }

        const jsonContent = stdout.substring(jsonStart, jsonEnd);
        const stats = JSON.parse(jsonContent);

        // Save to file
        fs.writeFileSync(outputPath, JSON.stringify(stats, null, 2));

        console.log(`✓ Stats saved to ${outputPath}`);
        console.log(`  Total modules: ${stats.modules?.length || 0}`);
        console.log(`  Chunks: ${stats.chunks?.length || 0}`);
        console.log(`  Assets: ${stats.assets?.length || 0}`);

        resolve(path.resolve(outputPath));
      } catch (error) {
        reject(new Error(`Failed to parse webpack output: ${error.message}`));
      }
    });

    child.on('error', error => {
      reject(new Error(`Failed to spawn webpack: ${error.message}`));
    });
  });
}

/**
 * Find webpack config in project
 * Hyperswitch-specific: Looks for webpack.common.js as primary config
 * @returns {string|null}
 */
function findWebpackConfig() {
  // Hyperswitch-specific webpack configs
  const candidates = [
    'webpack.common.js',      // Primary config for Hyperswitch
    'webpack.prod.js',
    'webpack.config.js',
    'webpack.config.ts',
    'webpack.production.js',
    'config/webpack.config.js',
    'config/webpack.prod.js',
  ];

  for (const candidate of candidates) {
    if (fs.existsSync(candidate)) {
      return candidate;
    }
  }

  return null;
}

/**
 * Get the webpack command (npx webpack or local binary)
 * @returns {string}
 */
function getWebpackCommand() {
  // Check for local webpack
  const localWebpack = path.join(process.cwd(), 'node_modules/.bin/webpack');
  if (fs.existsSync(localWebpack)) {
    return localWebpack;
  }

  // Fall back to npx
  return 'npx webpack';
}

/**
 * Build stats for a specific git ref
 * @param {string} ref - Git reference (branch, tag, commit)
 * @param {Object} options
 * @returns {Promise<string>} Path to generated stats file
 */
async function buildStatsForRef(ref, options = {}) {
  const tempDir = path.join(process.cwd(), '.bundle-ai-cache');
  if (!fs.existsSync(tempDir)) {
    fs.mkdirSync(tempDir, { recursive: true });
  }

  const outputPath = path.join(tempDir, `stats-${ref.replace(/[^a-zA-Z0-9_-]/g, '_')}.json`);

  // Check if we already have cached stats
  if (fs.existsSync(outputPath) && !options.force) {
    const stats = fs.statSync(outputPath);
    const age = Date.now() - stats.mtime.getTime();
    const maxAge = 24 * 60 * 60 * 1000; // 24 hours

    if (age < maxAge) {
      console.log(`Using cached stats for ${ref}`);
      return outputPath;
    }
  }

  const currentBranch = getCurrentBranch();
  let stashed = false;

  try {
    // Stash any uncommitted changes
    if (hasUncommittedChanges()) {
      console.log('Stashing uncommitted changes...');
      execSync('git stash push -m "bundle-ai-auto-stash"', { cwd: process.cwd() });
      stashed = true;
    }

    // Checkout target ref
    console.log(`Checking out ${ref}...`);
    execSync(`git checkout ${ref}`, { cwd: process.cwd(), stdio: 'ignore' });

    // Install dependencies if needed
    if (options.install !== false && !fs.existsSync('node_modules')) {
      console.log('Installing dependencies...');
      execSync('npm ci', { cwd: process.cwd(), stdio: 'inherit' });
    }

    // Build stats
    await buildStats({
      ...options,
      outputPath,
    });

    return outputPath;
  } finally {
    // Restore original state
    if (currentBranch) {
      execSync(`git checkout ${currentBranch}`, { cwd: process.cwd(), stdio: 'ignore' });
    }

    if (stashed) {
      console.log('Restoring stashed changes...');
      execSync('git stash pop', { cwd: process.cwd(), stdio: 'ignore' });
    }
  }
}

/**
 * Get current git branch
 * @returns {string|null}
 */
function getCurrentBranch() {
  try {
    return execSync('git rev-parse --abbrev-ref HEAD', {
      cwd: process.cwd(),
      encoding: 'utf-8',
    }).trim();
  } catch {
    return null;
  }
}

/**
 * Check for uncommitted changes
 * @returns {boolean}
 */
function hasUncommittedChanges() {
  try {
    const output = execSync('git status --porcelain', {
      cwd: process.cwd(),
      encoding: 'utf-8',
    });
    return output.trim().length > 0;
  } catch {
    return false;
  }
}

/**
 * CLI entry point
 */
if (require.main === module) {
  const args = process.argv.slice(2);
  const options = parseArgs(args);

  if (options.ref) {
    buildStatsForRef(options.ref, options)
      .then(path => {
        console.log(`\nStats built: ${path}`);
        process.exit(0);
      })
      .catch(error => {
        console.error('Error:', error.message);
        process.exit(1);
      });
  } else {
    buildStats(options)
      .then(() => process.exit(0))
      .catch(error => {
        console.error('Error:', error.message);
        process.exit(1);
      });
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
      case '--ref':
      case '-r':
        options.ref = args[++i];
        break;
      case '--output':
      case '-o':
        options.outputPath = args[++i];
        break;
      case '--config':
      case '-c':
        options.webpackConfig = args[++i];
        break;
      case '--mode':
      case '-m':
        options.mode = args[++i];
        break;
      case '--verbose':
      case '-v':
        options.verbose = true;
        break;
      case '--force':
      case '-f':
        options.force = true;
        break;
      case '--help':
      case '-h':
        console.log(`
Usage: node build-stats.js [options]

Options:
  -r, --ref <ref>         Build stats for specific git ref
  -o, --output <path>     Output path for stats JSON
  -c, --config <path>     Path to webpack config
  -m, --mode <mode>       webpack mode (production/development)
  -v, --verbose           Show webpack output
  -f, --force             Force rebuild even if cache exists
  -h, --help              Show this help
`);
        process.exit(0);
    }
  }

  return options;
}

module.exports = {
  buildStats,
  buildStatsForRef,
  findWebpackConfig,
};
