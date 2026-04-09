/**
 * @fileoverview AI Client
 * OpenAI API integration for bundle analysis classification and suggestions
 */

/**
 * @typedef {Object} AIAnalysisResult
 * @property {string} verdict - 'expected' | 'unexpected' | 'needs_review'
 * @property {number} confidence - 0-1 confidence score
 * @property {string} explanation - Human readable explanation
 * @property {string} rootCause - Identified root cause
 * @property {string[]} suggestedFixes - List of fix recommendations
 * @property {Object} metadata - Additional structured data
 */

const DEFAULT_MODEL = 'kimi-latest';
const MAX_TOKENS = 3000;
const TEMPERATURE = 0.1;

/**
 * Initialize AI client
 * @param {Object} options
 * @param {string} [options.apiKey] - OpenAI API key (defaults to env.OPENAI_API_KEY)
 * @param {string} [options.model] - Model to use
 * @returns {Object} Client instance
 */
function createClient(options = {}) {
  const apiKey = options.apiKey || process.env.OPENAI_API_KEY;

  if (!apiKey) {
    throw new Error(
      'OpenAI API key required. Set OPENAI_API_KEY environment variable or pass apiKey option.'
    );
  }

  return {
    apiKey,
    model: options.model || DEFAULT_MODEL,
    baseURL: options.baseURL || process.env.OPENAI_BASE_URL || 'https://api.openai.com/v1',
  };
}

/**
 * Analyze bundle diff with AI
 * @param {Object} client - AI client from createClient
 * @param {import('./diff-engine').BundleDiff} diff
 * @param {import('./rule-engine').DetectionResults} detections
 * @param {Object} context - Additional context
 * @returns {Promise<AIAnalysisResult>}
 */
async function analyzeBundle(client, diff, detections, context = {}) {
  const prompt = buildAnalysisPrompt(diff, detections, context);

  try {
    const response = await fetch(`${client.baseURL}/chat/completions`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${client.apiKey}`,
      },
      body: JSON.stringify({
        model: client.model,
        messages: [
          {
            role: 'system',
            content: SYSTEM_PROMPT,
          },
          {
            role: 'user',
            content: prompt,
          },
        ],
        temperature: TEMPERATURE,
        max_tokens: MAX_TOKENS,
        response_format: { type: 'json_object' },
      }),
    });

    if (!response.ok) {
      const error = await response.text();
      throw new Error(`OpenAI API error: ${response.status} - ${error}`);
    }

    const data = await response.json();
    const content = data.choices[0]?.message?.content;

    if (!content) {
      throw new Error('Empty response from OpenAI API');
    }

    return parseAIResponse(content);
  } catch (error) {
    console.error('AI analysis failed:', error.message);

    // Return fallback analysis
    return generateFallbackAnalysis(diff, detections);
  }
}

/**
 * System prompt for bundle analysis
 */
const SYSTEM_PROMPT = `You are an expert bundle analyzer specializing in the Hyperswitch Web SDK (orca-payment-page), a ReScript/React payment UI application built with webpack.

IMPORTANT DOMAIN CONTEXT:
- This is a payment SDK — bundle size directly impacts checkout load time and conversion rates
- The project uses ReScript (.res) compiled to JavaScript — module boundaries differ from hand-written JS
- Payment SDKs (Stripe, PayPal, Braintree, Klarna, Apple Pay, Google Pay, etc.) are NOT bundled — they're loaded dynamically via CDN/script injection at runtime
- Production dependencies are: @glennsl/rescript-fetch, @rescript/core, @rescript/react, @sentry/react, @sentry/webpack-plugin, react, react-datepicker, react-dom, recoil, webpack-merge
- Any node_modules package not in the above list that appears in the bundle is either a sub-dependency or was accidentally added

Your task: Analyze webpack bundle changes and determine if size increases are expected or indicate problems.

CRITICAL INSTRUCTION FOR SUGGESTIONS:
You will receive detailed context including:
- usedExports: Which specific exports each package uses vs ships (tree-shaking efficiency)
- Import chains: Which source files (.res.js/.bs.js) import each bloated dependency
- Package sizes: Absolute size of each node_modules package in the bundle

Use this data to give SPECIFIC, ACTIONABLE fixes. Do NOT give generic advice.

BAD (generic): "Consider lazy loading large dependencies"
GOOD (specific): "Dynamically import react-datepicker in DynamicFields.bs.js and DateOfBirth.bs.js using React.lazy() — this single change would defer 1035KB from initial load"

BAD (generic): "Review tree-shaking configuration"
GOOD (specific): "recoil ships 269KB but only 5 exports are used (RecoilRoot, atom, useRecoilState, useRecoilValue, useSetRecoilState). Since recoil doesn't support tree-shaking well, consider jotai (2KB) as a drop-in replacement for these specific atoms"

BAD (generic): "Check if all imports are necessary"
GOOD (specific): "@sentry/react pulls in @sentry-internal/replay (293KB) for session replay. If session replay is not used, configure Sentry with { replaysSessionSampleRate: 0 } or import from @sentry/react/minimal to exclude replay"

Guidelines:
1. Classify changes as: "expected", "unexpected", or "needs_review"
2. Identify the root cause with specific file paths and import chains
3. Suggest fixes that reference actual file names, function names, and concrete alternatives
4. Quantify the impact of each suggestion (e.g., "would save ~293KB")
5. Be conservative — flag suspicious changes even if uncertain

Rules for classification:
- "expected": Small changes proportional to code added, known dependencies, or zero diff
- "unexpected": Disproportionate size increases, full library imports, tree-shaking failures
- "needs_review": Ambiguous cases requiring human judgment

Confidence scoring rubric (FOLLOW THIS EXACTLY):
- 0.90-0.99: Very high certainty. Unambiguous evidence (e.g., zero diff, or obvious full-library import)
- 0.75-0.89: High certainty. Clear pattern (e.g., known dependency proportional to code change)
- 0.50-0.74: Moderate certainty. Mixed signals or partial evidence
- 0.25-0.49: Low certainty. Ambiguous, multiple explanations possible
- 0.01-0.24: Very low certainty. Insufficient data

Key confidence rules:
- Zero bundle change → confidence MUST be >= 0.90
- Critical rule violations found → confidence MUST be >= 0.85
- Large diff with no rule violations → confidence SHOULD be <= 0.60

Output MUST be valid JSON with these fields:
{
  "verdict": "expected|unexpected|needs_review",
  "confidence": 0.0-1.0,
  "explanation": "Clear explanation referencing specific modules and files",
  "rootCause": "Specific root cause with file paths and import chains",
  "suggestedFixes": ["Specific fix 1 with file names and estimated savings", "Specific fix 2..."],
  "metadata": {
    "riskLevel": "low|medium|high",
    "categories": ["tree_shaking", "dependency_addition", "dynamic_import", "dead_code", etc.],
    "estimatedSavings": "total KB that could be saved if all fixes applied"
  }
}`;

/**
 * Build analysis prompt from bundle data
 * @param {import('./diff-engine').BundleDiff} diff
 * @param {import('./rule-engine').DetectionResults} detections
 * @param {Object} context
 * @returns {string}
 */
function buildAnalysisPrompt(diff, detections, context) {
  const { formatBytes } = require('./diff-engine');

  const promptParts = [
    '# Bundle Analysis Request',
    '',
    '## Summary',
    `- Total Size Change: ${diff.totalDiffFormatted} (${formatBytes(diff.prSize)} vs ${formatBytes(diff.baseSize)})`,
    `- node_modules Change: ${diff.nodeModulesDiff > 0 ? '+' : ''}${formatBytes(diff.nodeModulesDiff)}`,
    `- Files Changed: ${context.linesChanged || 'Unknown'}`,
    '',
    '## Top Changes',
  ];

  // Add top changes
  for (const change of diff.topChanges.slice(0, 10)) {
    const type = change.type === 'added' ? '[NEW]' : change.type === 'removed' ? '[DEL]' : '[CHG]';
    promptParts.push(`- ${type} ${change.name}: ${change.changeFormatted}`);
    if (change.importChain.length > 0) {
      promptParts.push(`  Imported by: ${change.importChain.slice(0, 2).join(' ← ')}`);
    }
  }

  // Add detection results
  if (detections.violations.length > 0) {
    promptParts.push('', '## Detected Issues');
    for (const v of detections.violations.slice(0, 10)) {
      promptParts.push(`- [${v.severity.toUpperCase()}] ${v.id}: ${v.message}`);
    }
  }

  // Add ReScript context if available
  if (context.reScriptAnalysis) {
    const ra = context.reScriptAnalysis;
    promptParts.push('', '## ReScript Changes');
    promptParts.push(`- Files Modified: ${ra.filesModified || ra.filesChanged?.length || 0}`);

    if (ra.importsAdded && ra.importsAdded.length > 0) {
      promptParts.push(`- New Imports: ${ra.importsAdded.join(', ')}`);
    }

    if (ra.jsDependenciesIntroduced && ra.jsDependenciesIntroduced.length > 0) {
      promptParts.push(`- Potential JS Dependencies: ${ra.jsDependenciesIntroduced.join(', ')}`);
    }

    if (ra.correlations && ra.correlations.length > 0) {
      promptParts.push('- Correlations Found:');
      for (const corr of ra.correlations.slice(0, 5)) {
        promptParts.push(`  - ${corr.rescriptFile} → ${corr.jsDependency}`);
      }
    }
  }

  // Add package changes
  const pkgChanges = Object.entries(diff.packageDiffs)
    .filter(([, change]) => Math.abs(change) > 1024)
    .slice(0, 10);

  if (pkgChanges.length > 0) {
    promptParts.push('', '## Package Changes');
    for (const [pkg, change] of pkgChanges) {
      promptParts.push(`- ${pkg}: ${change > 0 ? '+' : ''}${formatBytes(change)}`);
    }
  }

  // === DEEP CONTEXT: Extract rich data from raw stats ===
  if (context.rawStats) {
    const deepContext = extractDeepContext(context.rawStats, diff);
    if (deepContext) {
      promptParts.push(deepContext);
    }
  }

  promptParts.push(
    '',
    '## Analysis Request',
    'Analyze this bundle diff and provide:',
    '1. Verdict: Is this expected, unexpected, or needs_review?',
    '2. Confidence: How certain are you (0.0-1.0)? Follow the rubric in the system prompt exactly.',
    '3. Explanation: Why did the bundle change (or not change)? Reference specific files and modules.',
    '4. Root Cause: What specifically caused it? Name the source files and import chains.',
    '5. Fixes: What should the developer do? Give specific file paths, function names, and estimated KB savings for each fix. If no issues, say so.',
    '',
    'Respond with valid JSON only.'
  );

  return promptParts.join('\n');
}

/**
 * Extract deep context from raw parsed webpack stats for AI enrichment.
 * This provides the AI with usedExports, full import chains, and tree-shaking data
 * so it can give specific, actionable suggestions instead of generic advice.
 *
 * @param {Object} rawStats - { baseStats, prStats } from parsed webpack stats
 * @param {import('./diff-engine').BundleDiff} diff
 * @returns {string|null} Formatted deep context section for the prompt
 */
function extractDeepContext(rawStats, diff) {
  const { formatBytes } = require('./diff-engine');
  const { extractPackageName } = require('./stats-parser');

  const prStats = rawStats.prStats;
  if (!prStats || !prStats.modules) return null;

  const sections = [];

  // --- 1. Top packages by size with usedExports analysis ---
  const packageModules = {};
  for (const mod of prStats.modules) {
    if (!mod.isNodeModule) continue;
    const pkg = extractPackageName(mod.name);
    if (!pkg) continue;
    if (!packageModules[pkg]) {
      packageModules[pkg] = { totalSize: 0, modules: [], usedExports: new Set(), allExportsUsed: false };
    }
    packageModules[pkg].totalSize += mod.size;
    packageModules[pkg].modules.push(mod);

    // Collect usedExports
    if (mod.usedExports) {
      if (mod.usedExports.includes('*')) {
        packageModules[pkg].allExportsUsed = true;
      } else {
        for (const exp of mod.usedExports) {
          packageModules[pkg].usedExports.add(exp);
        }
      }
    }
  }

  // Sort packages by size, take top 10
  const topPackages = Object.entries(packageModules)
    .sort(([, a], [, b]) => b.totalSize - a.totalSize)
    .slice(0, 10);

  if (topPackages.length > 0) {
    sections.push('', '## Deep Context: Top Packages by Size (with tree-shaking data)');
    for (const [pkgName, pkgData] of topPackages) {
      const usedList = pkgData.allExportsUsed
        ? 'ALL exports used (no tree-shaking opportunity)'
        : pkgData.usedExports.size > 0
          ? [...pkgData.usedExports].slice(0, 15).join(', ')
          : 'unknown (usedExports not available)';
      const usedCount = pkgData.allExportsUsed ? 'all' : pkgData.usedExports.size;
      const moduleCount = pkgData.modules.length;

      sections.push(`### ${pkgName} — ${formatBytes(pkgData.totalSize)} (${moduleCount} modules)`);
      sections.push(`  Used exports (${usedCount}): ${usedList}`);

      // Find who imports this package (trace to source .res.js / .bs.js files)
      const importers = new Set();
      for (const mod of pkgData.modules) {
        if (mod.reasons) {
          for (const reason of mod.reasons) {
            // Only show non-node_modules importers (source files)
            if (reason && !reason.includes('node_modules')) {
              importers.add(reason);
            }
          }
        }
        // Also check issuer
        if (mod.issuer && !mod.issuer.includes('node_modules')) {
          importers.add(mod.issuer);
        }
      }

      if (importers.size > 0) {
        const importerList = [...importers].slice(0, 8);
        sections.push(`  Imported by source files: ${importerList.join(', ')}`);
      } else {
        sections.push(`  Imported by: (only other node_modules — sub-dependency)`);
      }
    }
  }

  // --- 2. Import chain deep dive for top changed modules ---
  const topChangedNodeModules = diff.topChanges
    .filter(c => c.isNodeModule && Math.abs(c.change) > 5 * 1024) // > 5KB changes
    .slice(0, 5);

  if (topChangedNodeModules.length > 0) {
    sections.push('', '## Deep Context: Import Chains for Top Changed Modules');
    for (const change of topChangedNodeModules) {
      sections.push(`### ${change.name} (${change.changeFormatted})`);

      // Find the full import chain from PR stats
      const prModule = prStats.modules.find(m => m.name === change.name);
      if (prModule) {
        // All importers (reasons)
        if (prModule.reasons && prModule.reasons.length > 0) {
          const sourceImporters = prModule.reasons.filter(r => !r.includes('node_modules'));
          const nodeImporters = prModule.reasons.filter(r => r.includes('node_modules'));

          if (sourceImporters.length > 0) {
            sections.push(`  Source file importers: ${sourceImporters.slice(0, 5).join(', ')}`);
          }
          if (nodeImporters.length > 0) {
            sections.push(`  node_modules importers: ${nodeImporters.slice(0, 3).join(', ')}`);
          }
        }

        // usedExports for this specific module
        if (prModule.usedExports && prModule.usedExports.length > 0) {
          const exportStr = prModule.usedExports.includes('*')
            ? 'ALL (no tree-shaking)'
            : prModule.usedExports.slice(0, 10).join(', ');
          sections.push(`  Used exports: ${exportStr}`);
        }
      }
    }
  }

  // --- 3. Tree-shaking efficiency summary ---
  const treeShakeIssues = [];
  for (const [pkgName, pkgData] of topPackages) {
    if (pkgData.totalSize > 50 * 1024 && !pkgData.allExportsUsed && pkgData.usedExports.size > 0 && pkgData.usedExports.size <= 10) {
      treeShakeIssues.push({
        pkg: pkgName,
        size: pkgData.totalSize,
        usedCount: pkgData.usedExports.size,
        used: [...pkgData.usedExports].slice(0, 10),
      });
    }
  }

  if (treeShakeIssues.length > 0) {
    sections.push('', '## Deep Context: Potential Tree-Shaking Opportunities');
    for (const issue of treeShakeIssues) {
      sections.push(`- ${issue.pkg}: Ships ${formatBytes(issue.size)} but only ${issue.usedCount} exports used: [${issue.used.join(', ')}]`);
    }
  }

  return sections.length > 0 ? sections.join('\n') : null;
}

/**
 * Parse and validate AI response
 * @param {string} content
 * @returns {AIAnalysisResult}
 */
function parseAIResponse(content) {
  try {
    const parsed = JSON.parse(content);

    // Validate required fields
    if (!parsed.verdict || !['expected', 'unexpected', 'needs_review'].includes(parsed.verdict)) {
      parsed.verdict = 'needs_review';
    }

    return {
      verdict: parsed.verdict,
      confidence: Math.max(0, Math.min(1, parsed.confidence ?? 0.5)),
      explanation: parsed.explanation || 'No explanation provided',
      rootCause: parsed.rootCause || 'Unknown',
      suggestedFixes: Array.isArray(parsed.suggestedFixes) ? parsed.suggestedFixes : [],
      metadata: parsed.metadata || {},
    };
  } catch (error) {
    console.warn('Failed to parse AI response as JSON:', error.message);

    // Try to extract meaningful content from non-JSON response
    return {
      verdict: 'needs_review',
      confidence: 0.5,
      explanation: content.substring(0, 500),
      rootCause: 'Parse error',
      suggestedFixes: ['Review bundle changes manually'],
      metadata: { parseError: true },
    };
  }
}

/**
 * Generate fallback analysis when AI fails
 * @param {import('./diff-engine').BundleDiff} diff
 * @param {import('./rule-engine').DetectionResults} detections
 * @returns {AIAnalysisResult}
 */
function generateFallbackAnalysis(diff, detections) {
  const hasCritical = detections.critical.length > 0;
  const hasWarnings = detections.warnings.length > 0;
  const significantIncrease = diff.totalDiff > 100 * 1024;

  let verdict = 'expected';
  let explanation = 'Bundle changes appear normal.';
  const suggestedFixes = [];

  if (hasCritical) {
    verdict = 'unexpected';
    explanation = 'Critical issues detected requiring attention.';
    suggestedFixes.push('Address critical bundle size issues');
  } else if (significantIncrease && hasWarnings) {
    verdict = 'unexpected';
    explanation = 'Large size increase with detected issues suggests potential problems.';
  } else if (significantIncrease) {
    verdict = 'needs_review';
    explanation = 'Large size increase - review recommended.';
  } else if (hasWarnings) {
    verdict = 'needs_review';
    explanation = 'Warnings detected - manual review suggested.';
  }

  // Add rule-based fixes
  for (const violation of detections.violations) {
    if (violation.details?.suggestion) {
      suggestedFixes.push(violation.details.suggestion);
    }
  }

  return {
    verdict,
    confidence: computeFallbackConfidence(diff, detections, verdict),
    explanation,
    rootCause: detections.violations[0]?.message || 'No specific root cause identified',
    suggestedFixes: [...new Set(suggestedFixes)].slice(0, 5),
    metadata: {
      fallback: true,
      violations: detections.violations.length,
    },
  };
}

/**
 * Compute confidence for fallback (offline) analysis based on observable data.
 *
 * Confidence answers: "How sure are we that the verdict is correct?"
 *
 * Rubric:
 * - Zero diff → verdict is trivially correct → 0.95
 * - Critical issues found → strong signal → 0.90
 * - Warnings found → moderate signal → 0.75
 * - Large diff with no rule hits → ambiguous, could be expected or not → 0.40
 * - Small diff with no rule hits → likely fine → 0.80
 *
 * @param {import('./diff-engine').BundleDiff} diff
 * @param {import('./rule-engine').DetectionResults} detections
 * @param {string} verdict
 * @returns {number}
 */
function computeFallbackConfidence(diff, detections, verdict) {
  const absDiff = Math.abs(diff.totalDiff);
  const hasCritical = detections.critical.length > 0;
  const hasWarnings = detections.warnings.length > 0;

  // Zero change — the verdict ("expected") is trivially correct
  if (absDiff === 0) {
    return 0.95;
  }

  // Critical issues detected — strong evidence for "unexpected"
  if (hasCritical) {
    return 0.90;
  }

  // Large diff (>100KB) with no rule violations — genuinely ambiguous
  if (absDiff > 100 * 1024 && !hasWarnings) {
    return 0.40;
  }

  // Warnings but no criticals — moderate evidence
  if (hasWarnings) {
    return 0.75;
  }

  // Small diff (<10KB) with no issues — very likely fine
  if (absDiff < 10 * 1024) {
    return 0.85;
  }

  // Medium diff (10KB-100KB), no issues — probably fine but not certain
  return 0.70;
}

/**
 * Quick analysis without AI (for offline/local use)
 * @param {import('./diff-engine').BundleDiff} diff
 * @param {import('./rule-engine').DetectionResults} detections
 * @returns {AIAnalysisResult}
 */
function analyzeOffline(diff, detections) {
  return generateFallbackAnalysis(diff, detections);
}

/**
 * Check if AI analysis is available
 * @returns {boolean}
 */
function isAIAvailable() {
  return !!process.env.OPENAI_API_KEY;
}

module.exports = {
  createClient,
  analyzeBundle,
  analyzeOffline,
  isAIAvailable,
  buildAnalysisPrompt,
  extractDeepContext,
  parseAIResponse,
  DEFAULT_MODEL,
};
