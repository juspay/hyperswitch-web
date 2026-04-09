/**
 * @fileoverview ReScript Analyzer
 * Analyzes .res files in git diff to detect added imports and dependencies
 */

const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');

/**
 * @typedef {Object} ReScriptAnalysis
 * @property {string[]} filesChanged - List of .res files changed
 * @property {string[]} importsAdded - New imports detected
 * @property {Object.<string, string[]>} importsByFile - Imports grouped by file
 * @property {Object.<string, string>} jsDependencies - Mapping of ReScript modules to potential JS deps
 */

// Known ReScript/ReasonML to JS dependency mappings
// Matches package.json dependencies exactly
const RESCRIPT_TO_JS_DEPS = {
  // ReScript Core Libraries
  'RescriptCore': ['@rescript/core'],
  'RescriptReact': ['@rescript/react'],
  '@rescript/react': ['@rescript/react'],
  '@rescript/core': ['@rescript/core'],
  
  // Network/Fetch
  '@glennsl/rescript-fetch': ['@glennsl/rescript-fetch'],
  
  // State Management
  'Recoil': ['recoil'],
  
  // UI Components
  'ReactDatepicker': ['react-datepicker'],
  
  // Analytics
  'Sentry': ['@sentry/react'],
  
  // Note: Payment SDKs (Stripe, PayPal, Klarna, etc.) are NOT bundled
  // They are loaded dynamically via CDN at runtime
};

// Import patterns in ReScript
const IMPORT_PATTERNS = {
  OPEN_STATEMENT: /open\s+(\w+(?:\.\w+)*)/g,
  MODULE_ALIAS: /module\s+(\w+)\s*=\s*(\w+(?:\.\w+)*)/g,
  EXTERNAL_DECLARATION: /external\s+\w+\s*:\s*[^=]+=\s*"([^"]+)"/g,
  LET_EXTERNAL: /@module\("([^"]+)"\)/g,
};

/**
 * Analyze ReScript files in git diff
 * @param {string} baseBranch - Base branch name
 * @param {string} headBranch - Head branch name
 * @returns {ReScriptAnalysis}
 */
function analyzeReScriptChanges(baseBranch, headBranch) {
  try {
    // Get list of changed .res files
    const filesChanged = getChangedReScriptFiles(baseBranch, headBranch);

    if (filesChanged.length === 0) {
      return {
        filesChanged: [],
        importsAdded: [],
        importsByFile: {},
        jsDependencies: {},
      };
    }

    const importsAdded = [];
    const importsByFile = {};
    const jsDependencies = {};

    for (const file of filesChanged) {
      const fileImports = analyzeFileImports(file, baseBranch, headBranch);
      importsByFile[file] = fileImports;
      importsAdded.push(...fileImports.newImports);

      // Map ReScript imports to potential JS dependencies
      const deps = mapToJSDependencies(fileImports.newImports);
      jsDependencies[file] = deps;
    }

    return {
      filesChanged,
      importsAdded: [...new Set(importsAdded)],
      importsByFile,
      jsDependencies,
    };
  } catch (error) {
    console.warn('Warning: Could not analyze ReScript changes:', error.message);
    return {
      filesChanged: [],
      importsAdded: [],
      importsByFile: {},
      jsDependencies: {},
    };
  }
}

/**
 * Get list of changed ReScript files between branches
 * @param {string} baseBranch
 * @param {string} headBranch
 * @returns {string[]}
 */
function getChangedReScriptFiles(baseBranch, headBranch) {
  try {
    const cmd = `git diff --name-only ${baseBranch}...${headBranch} -- '*.res' '*.resi'`;
    const output = execSync(cmd, { encoding: 'utf-8', cwd: process.cwd() });

    return output
      .trim()
      .split('\n')
      .filter(f => f.trim() && (f.endsWith('.res') || f.endsWith('.resi')));
  } catch (error) {
    // No changes or git error
    return [];
  }
}

/**
 * Analyze imports in a single file
 * @param {string} filePath
 * @param {string} baseBranch
 * @param {string} headBranch
 * @returns {Object}
 */
function analyzeFileImports(filePath, baseBranch, headBranch) {
  const oldContent = getFileAtRef(filePath, baseBranch);
  const newContent = getFileAtRef(filePath, headBranch);

  const oldImports = extractImports(oldContent);
  const newImports = extractImports(newContent);

  // Find added imports
  const addedImports = newImports.filter(imp => !oldImports.includes(imp));

  return {
    oldImports,
    newImports,
    addedImports,
  };
}

/**
 * Get file content at specific git ref
 * @param {string} filePath
 * @param {string} ref
 * @returns {string}
 */
function getFileAtRef(filePath, ref) {
  try {
    return execSync(`git show ${ref}:${filePath}`, {
      encoding: 'utf-8',
      cwd: process.cwd(),
    });
  } catch {
    // File didn't exist at that ref
    return '';
  }
}

/**
 * Extract imports from ReScript file content
 * @param {string} content
 * @returns {string[]}
 */
function extractImports(content) {
  const imports = new Set();

  // Extract open statements
  let match;
  while ((match = IMPORT_PATTERNS.OPEN_STATEMENT.exec(content)) !== null) {
    imports.add(match[1]);
  }

  // Reset regex
  IMPORT_PATTERNS.OPEN_STATEMENT.lastIndex = 0;

  // Extract module aliases
  while ((match = IMPORT_PATTERNS.MODULE_ALIAS.exec(content)) !== null) {
    imports.add(match[2]); // The module being aliased
  }
  IMPORT_PATTERNS.MODULE_ALIAS.lastIndex = 0;

  // Extract external declarations with @module
  while ((match = IMPORT_PATTERNS.LET_EXTERNAL.exec(content)) !== null) {
    imports.add(match[1]);
  }
  IMPORT_PATTERNS.LET_EXTERNAL.lastIndex = 0;

  // Extract external declarations
  while ((match = IMPORT_PATTERNS.EXTERNAL_DECLARATION.exec(content)) !== null) {
    imports.add(match[1]);
  }
  IMPORT_PATTERNS.EXTERNAL_DECLARATION.lastIndex = 0;

  return [...imports];
}

/**
 * Map ReScript imports to potential JS dependencies
 * @param {string[]} rescriptImports
 * @returns {string[]}
 */
function mapToJSDependencies(rescriptImports) {
  const jsDeps = new Set();

  for (const imp of rescriptImports) {
    // Direct mapping
    if (RESCRIPT_TO_JS_DEPS[imp]) {
      RESCRIPT_TO_JS_DEPS[imp].forEach(dep => jsDeps.add(dep));
    }

    // Heuristic matching for binding libraries (prefixed with Bs or Re)
    const normalized = imp
      .replace(/^Bs/, '')
      .replace(/^Re/, '')
      .toLowerCase();

    // Map to actual project dependencies only
    if (normalized.includes('datepicker') || normalized.includes('date')) {
      jsDeps.add('react-datepicker');
    }
    if (normalized.includes('recoil') || normalized.includes('atom') || normalized.includes('selector')) {
      jsDeps.add('recoil');
    }
    if (normalized.includes('sentry')) {
      jsDeps.add('@sentry/react');
    }
    if (normalized.includes('fetch')) {
      jsDeps.add('@glennsl/rescript-fetch');
    }
  }

  return [...jsDeps];
}

/**
 * Correlate ReScript changes with bundle changes
 * @param {ReScriptAnalysis} resAnalysis
 * @param {import('./diff-engine').BundleDiff} bundleDiff
 * @returns {Object[]}
 */
function correlateWithBundleChanges(resAnalysis, bundleDiff) {
  const correlations = [];

  for (const [file, jsDeps] of Object.entries(resAnalysis.jsDependencies)) {
    for (const dep of jsDeps) {
      // Look for this dependency in bundle changes
      const relatedChanges = bundleDiff.allChanges.filter(change => {
        const name = change.name.toLowerCase();
        const pkgName = (change.packageName || '').toLowerCase();
        return name.includes(dep.toLowerCase()) || pkgName.includes(dep.toLowerCase());
      });

      if (relatedChanges.length > 0) {
        correlations.push({
          rescriptFile: file,
          jsDependency: dep,
          relatedBundleChanges: relatedChanges.map(c => ({
            name: c.name,
            change: c.change,
            isNew: c.type === 'added',
          })),
        });
      }
    }
  }

  return correlations;
}

/**
 * Get lines changed in a file
 * @param {string} filePath
 * @param {string} baseBranch
 * @param {string} headBranch
 * @returns {number}
 */
function getLinesChanged(filePath, baseBranch, headBranch) {
  try {
    const cmd = `git diff --numstat ${baseBranch}...${headBranch} -- '${filePath}'`;
    const output = execSync(cmd, { encoding: 'utf-8', cwd: process.cwd() });

    // Format: added\tremoved\tfile
    const parts = output.trim().split('\t');
    if (parts.length >= 2) {
      const added = parseInt(parts[0], 10) || 0;
      const removed = parseInt(parts[1], 10) || 0;
      return added + removed;
    }
    return 0;
  } catch {
    return 0;
  }
}

/**
 * Generate summary of ReScript impact on bundle
 * @param {ReScriptAnalysis} analysis
 * @param {import('./diff-engine').BundleDiff} bundleDiff
 * @returns {Object}
 */
function generateReScriptSummary(analysis, bundleDiff) {
  const correlations = correlateWithBundleChanges(analysis, bundleDiff);

  return {
    filesModified: analysis.filesChanged.length,
    importsAdded: analysis.importsAdded.length,
    jsDependenciesIntroduced: [...new Set(Object.values(analysis.jsDependencies).flat())],
    bundleCorrelationCount: correlations.length,
    correlations,
    riskAssessment: assessRisk(analysis, bundleDiff),
  };
}

/**
 * Assess risk level based on ReScript changes
 * @param {ReScriptAnalysis} analysis
 * @param {import('./diff-engine').BundleDiff} bundleDiff
 * @returns {string}
 */
function assessRisk(analysis, bundleDiff) {
  const jsDeps = Object.values(analysis.jsDependencies).flat();

  // High risk: Adding known heavy dependencies (actual project deps only)
  const heavyDeps = ['react-datepicker', '@sentry/react', 'recoil'];
  const hasHeavyDep = jsDeps.some(dep =>
    heavyDeps.some(h => dep.toLowerCase().includes(h))
  );

  if (hasHeavyDep && bundleDiff.nodeModulesDiff > 30 * 1024) {
    return 'high';
  }

  // Medium risk: Any new dependencies
  if (jsDeps.length > 0 && bundleDiff.nodeModulesDiff > 10 * 1024) {
    return 'medium';
  }

  // Low risk: Only code changes
  if (analysis.filesChanged.length > 0) {
    return 'low';
  }

  return 'none';
}

module.exports = {
  analyzeReScriptChanges,
  getChangedReScriptFiles,
  extractImports,
  mapToJSDependencies,
  correlateWithBundleChanges,
  generateReScriptSummary,
  assessRisk,
  getLinesChanged,
  RESCRIPT_TO_JS_DEPS,
};
