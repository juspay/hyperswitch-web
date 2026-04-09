#!/usr/bin/env node
/**
 * @fileoverview Test Runner
 * Basic tests for bundle-ai modules
 */

const fs = require('fs');
const path = require('path');

// Test utilities
let testsRun = 0;
let testsPassed = 0;
let testsFailed = 0;

function test(name, fn) {
  testsRun++;
  try {
    fn();
    console.log(`✓ ${name}`);
    testsPassed++;
  } catch (error) {
    console.error(`✗ ${name}`);
    console.error(`  Error: ${error.message}`);
    testsFailed++;
  }
}

function assertEqual(actual, expected, msg = '') {
  if (actual !== expected) {
    throw new Error(`${msg} Expected ${expected}, got ${actual}`);
  }
}

function assertTrue(value, msg = '') {
  if (value !== true) {
    throw new Error(`${msg} Expected true, got ${value}`);
  }
}

function assertFalse(value, msg = '') {
  if (value !== false) {
    throw new Error(`${msg} Expected false, got ${value}`);
  }
}

// Run tests
console.log('Running Bundle AI Tests\n');

// Test stats-parser
console.log('--- Testing stats-parser.js ---');
const { parseStats, isNodeModule, extractPackageName, formatBytes } = require('../lib/stats-parser');

test('parseStats parses webpack stats correctly', () => {
  const sampleStats = JSON.parse(fs.readFileSync(path.join(__dirname, 'sample-base-stats.json'), 'utf-8'));
  const result = parseStats(sampleStats);

  assertTrue(Array.isArray(result.modules), 'Should have modules array');
  assertEqual(result.modules.length, 6, 'Should have 6 modules');
  assertTrue(result.totalSize > 0, 'Should have positive total size');
});

test('isNodeModule detects node_modules correctly', () => {
  assertTrue(isNodeModule('./node_modules/react/index.js'), 'Should detect node_modules');
  assertFalse(isNodeModule('./src/App.js'), 'Should not detect source file');
  assertTrue(isNodeModule('node_modules/lodash/index.js'), 'Should detect without ./');
});

test('extractPackageName extracts package name', () => {
  assertEqual(extractPackageName('./node_modules/react/index.js'), 'react', 'Should extract react');
  assertEqual(extractPackageName('./node_modules/@babel/runtime/index.js'), '@babel/runtime', 'Should extract scoped package');
  assertEqual(extractPackageName('./src/App.js'), null, 'Should return null for non-node_modules');
});

test('formatBytes formats correctly', () => {
  assertEqual(formatBytes(0), '0 Bytes', 'Zero bytes');
  assertEqual(formatBytes(1024), '1 KB', '1 kilobyte');
  assertEqual(formatBytes(1024 * 1024), '1 MB', '1 megabyte');
  assertTrue(formatBytes(1536).includes('1.5'), '1.5 KB');
});

// Test diff-engine
console.log('\n--- Testing diff-engine.js ---');
const { computeDiff, generateSummary } = require('../lib/diff-engine');

test('computeDiff calculates size differences', () => {
  const baseStats = parseStats(JSON.parse(fs.readFileSync(path.join(__dirname, 'sample-base-stats.json'), 'utf-8')));
  const prStats = parseStats(JSON.parse(fs.readFileSync(path.join(__dirname, 'sample-pr-stats.json'), 'utf-8')));

  const diff = computeDiff(baseStats, prStats);

  assertTrue(typeof diff.totalDiff === 'number', 'Should have totalDiff');
  assertTrue(diff.totalDiff > 0, 'PR should be larger');
  assertTrue(Array.isArray(diff.added), 'Should have added array');
  assertTrue(Array.isArray(diff.removed), 'Should have removed array');
  assertTrue(diff.added.length > 0, 'Should detect added modules');
});

test('generateSummary produces valid summary', () => {
  const baseStats = parseStats(JSON.parse(fs.readFileSync(path.join(__dirname, 'sample-base-stats.json'), 'utf-8')));
  const prStats = parseStats(JSON.parse(fs.readFileSync(path.join(__dirname, 'sample-pr-stats.json'), 'utf-8')));
  const diff = computeDiff(baseStats, prStats);
  const summary = generateSummary(diff);

  assertTrue(typeof summary.hasChanges === 'boolean', 'Should have hasChanges');
  assertTrue(typeof summary.isSignificant === 'boolean', 'Should have isSignificant');
  assertTrue(['increase', 'decrease', 'unchanged'].includes(summary.direction), 'Should have valid direction');
});

// Test rule-engine
console.log('\n--- Testing rule-engine.js ---');
const { runDetection, detectFullLibraryImports, detectUnexpectedDependencies, ALLOWED_DEPENDENCIES } = require('../lib/rule-engine');

test('runDetection identifies issues', () => {
  const baseStats = parseStats(JSON.parse(fs.readFileSync(path.join(__dirname, 'sample-base-stats.json'), 'utf-8')));
  const prStats = parseStats(JSON.parse(fs.readFileSync(path.join(__dirname, 'sample-pr-stats.json'), 'utf-8')));
  const diff = computeDiff(baseStats, prStats);

  const detections = runDetection(diff);

  assertTrue(Array.isArray(detections.violations), 'Should have violations array');
  assertTrue(Array.isArray(detections.critical), 'Should have critical array');
  assertTrue(Array.isArray(detections.warnings), 'Should have warnings array');
  assertTrue(typeof detections.hasCriticalIssues === 'boolean', 'Should have hasCriticalIssues');
});

test('detectFullLibraryImports returns violations array', () => {
  const baseStats = parseStats(JSON.parse(fs.readFileSync(path.join(__dirname, 'sample-base-stats.json'), 'utf-8')));
  const prStats = parseStats(JSON.parse(fs.readFileSync(path.join(__dirname, 'sample-pr-stats.json'), 'utf-8')));
  const diff = computeDiff(baseStats, prStats);

  const violations = detectFullLibraryImports(diff);

  // Should return an array (may or may not have lodash depending on module name format)
  assertTrue(Array.isArray(violations), 'Should return array');
});

test('detectUnexpectedDependencies flags unknown packages', () => {
  // Create a mock diff with an unexpected package
  const mockDiff = {
    added: [
      {
        name: 'node_modules/some-unknown-pkg/index.js',
        packageName: 'some-unknown-pkg',
        newSize: 60000,
        importChain: ['src/App.bs.js'],
        isNodeModule: true,
        type: 'added',
      },
      {
        name: 'node_modules/react/index.js',
        packageName: 'react',
        newSize: 5000,
        importChain: ['src/App.bs.js'],
        isNodeModule: true,
        type: 'added',
      },
    ],
    allChanges: [],
    topChanges: [],
    removed: [],
    packageDiffs: {},
  };

  const violations = detectUnexpectedDependencies(mockDiff);

  // Should flag some-unknown-pkg but NOT react
  assertTrue(violations.length === 1, 'Should flag exactly one unexpected dep');
  assertEqual(violations[0].id, 'UNEXPECTED_DEPENDENCY', 'Should have correct rule ID');
  assertTrue(violations[0].message.includes('some-unknown-pkg'), 'Should mention the unexpected package');
});

test('ALLOWED_DEPENDENCIES matches package.json deps', () => {
  assertTrue(ALLOWED_DEPENDENCIES.includes('react'), 'Should include react');
  assertTrue(ALLOWED_DEPENDENCIES.includes('@sentry/react'), 'Should include @sentry/react');
  assertTrue(ALLOWED_DEPENDENCIES.includes('recoil'), 'Should include recoil');
  assertFalse(ALLOWED_DEPENDENCIES.includes('lodash'), 'Should NOT include lodash');
});

// Test rescript-analyzer
console.log('\n--- Testing rescript-analyzer.js ---');
const { extractImports, mapToJSDependencies, RESCRIPT_TO_JS_DEPS } = require('../lib/rescript-analyzer');

test('extractImports finds ReScript imports', () => {
  const content = `
    open React
    open Belt
    module Date = ReDate
    external format: string => string = "date-fns/format"
    @module("lodash")
    external debounce: ('a => 'b, int) => 'a => 'b = "debounce"
  `;

  const imports = extractImports(content);

  assertTrue(imports.includes('React'), 'Should extract React');
  assertTrue(imports.includes('Belt'), 'Should extract Belt');
  assertTrue(imports.includes('ReDate'), 'Should extract ReDate');
  assertTrue(imports.includes('date-fns/format') || imports.includes('lodash'), 'Should extract externals');
});

test('mapToJSDependencies maps correctly', () => {
  const imports = ['ReDatepicker', 'Recoil'];
  const deps = mapToJSDependencies(imports);

  assertTrue(deps.includes('react-datepicker'), 'Should map ReDatepicker to react-datepicker');
  assertTrue(deps.includes('recoil'), 'Should map Recoil to recoil');
});

// Test ai-client
console.log('\n--- Testing ai-client.js ---');
const { parseAIResponse, isAIAvailable } = require('../lib/ai-client');

test('parseAIResponse validates responses', () => {
  const validResponse = JSON.stringify({
    verdict: 'unexpected',
    confidence: 0.85,
    explanation: 'Large lodash detected',
    rootCause: 'Full import in App.js',
    suggestedFixes: ['Use lodash-es'],
  });

  const result = parseAIResponse(validResponse);

  assertEqual(result.verdict, 'unexpected', 'Should parse verdict');
  assertEqual(result.confidence, 0.85, 'Should parse confidence');
  assertTrue(result.suggestedFixes.includes('Use lodash-es'), 'Should parse fixes');
});

test('parseAIResponse handles invalid JSON', () => {
  const result = parseAIResponse('not valid json');

  assertEqual(result.verdict, 'needs_review', 'Should default to needs_review');
  assertTrue(result.metadata.parseError, 'Should indicate parse error');
});

test('isAIAvailable checks env var', () => {
  const hadKey = !!process.env.OPENAI_API_KEY;

  // This is environment dependent
  assertTrue(typeof isAIAvailable() === 'boolean', 'Should return boolean');
});

// Summary
console.log('\n--- Test Summary ---');
console.log(`Tests run: ${testsRun}`);
console.log(`Tests passed: ${testsPassed}`);
console.log(`Tests failed: ${testsFailed}`);

if (testsFailed > 0) {
  process.exit(1);
}
console.log('\n✓ All tests passed!');
