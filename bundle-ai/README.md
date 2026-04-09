# Hyperswitch Bundle Analyzer

Bundle analyzer specifically tailored for the **Hyperswitch Web SDK** (`orca-payment-page`) — a payment orchestration platform.

**Analyzes PRODUCTION bundles only** to ensure accurate size measurements.

## Features

- **Bundle Diff Analysis**: Compare production bundle stats between branches
- **Module-Level Tracking**: See exactly which modules changed and why
- **Import Chain Extraction**: Trace which file caused which dependency
- **Deep Context AI**: Sends full import chains, usedExports, tree-shaking data, and webpack config snippets to the AI for specific, actionable suggestions
- **ReScript-Aware**: Analyzes `.res` file changes and their JS dependency impact
- **GitHub Integration**: Automatic PR comments with analysis results

### Detection Capabilities

- **Unexpected Dependency Guard**: Flags any `node_modules` package that appears in the bundle but is not listed in `package.json` dependencies (CRITICAL severity)
- Large dependency additions (>30KB)
- Full library imports (e.g. importing all of recoil instead of specific atoms)
- Tree-shaking failures
- Suspicious size spikes
- node_modules growth tracking

### Important Note on Payment SDKs

**Payment SDKs (Stripe, PayPal, Braintree, Klarna, Apple Pay, Google Pay, Samsung Pay, Plaid, etc.) are NOT bundled.** They are loaded dynamically via CDN/script injection at runtime. These won't appear in webpack bundle stats.

## Setup

The `bundle-ai/` folder is already included in the Hyperswitch Web SDK project. No additional installation needed — it has zero npm dependencies.

### Environment Variables

Create a `.env` file in the `bundle-ai/` directory:

```bash
# bundle-ai/.env
OPENAI_API_KEY=<your-api-key>
OPENAI_BASE_URL=<your-api-endpoint>
REPO_URL=<git-clone-url-for-the-repo>
```

The CLI and `run.sh` both automatically load `bundle-ai/.env` at startup — no `dotenv` dependency required.

> **Note:** The `.env` file is gitignored and will not be committed. Each developer needs to create their own.

Without the API key, the analyzer falls back to rule-based analysis only (no AI verdict).

| Variable | Description | Required |
|----------|-------------|----------|
| `OPENAI_API_KEY` | API key for AI-powered analysis | No (falls back to rules-only) |
| `OPENAI_BASE_URL` | AI API endpoint | No (defaults to OpenAI) |
| `REPO_URL` | Git clone URL for the repository | Only for `run.sh` |
| `GITHUB_TOKEN` | GitHub token for PR comments | Only for `--post-comment` |
| `GITHUB_REPOSITORY` | Repo name (auto-detected in CI) | No |
| `sdkEnv` | Hyperswitch environment (sandbox/prod/integ) | No (defaults to sandbox) |
| `SDK_VERSION` | SDK version (v1/v2) | No (defaults to v1) |

**Default AI model:** `kimi-latest` (override with `--model <name>`)

## Usage

### Quick Start with `run.sh` (Recommended)

The `run.sh` script handles the full workflow: clones fresh copies of base and PR branches, installs deps, builds production webpack stats, runs AI analysis, and generates all report formats into `bundle-ai/reports/`.

```bash
# Compare current branch to main
./bundle-ai/run.sh

# Compare a specific PR branch to main
./bundle-ai/run.sh --pr feat/my-feature

# Compare specific base + PR branches
./bundle-ai/run.sh --base develop --pr feat/x

# Force rebuild (skip cache)
./bundle-ai/run.sh --force-build
```

Reports are generated into `bundle-ai/reports/` (gitignored):
- `analyze-report.txt` — AI-powered text analysis
- `analyze-output.json` — structured JSON output
- `comment-report.md` — PR comment markdown
- `cli-with-ai.txt` — full CLI output
- `cli-json-output.json` — CLI JSON output
- `diff-report.txt` — raw diff report
- `test-results.txt` — test results

### CLI (Direct Usage)

```bash
# Compare current branch to main (always analyzes production build)
node bundle-ai/cli.js

# Compare specific branches
node bundle-ai/cli.js --base develop --head feature/new-payment-method

# Run without AI (faster, rules-only)
node bundle-ai/cli.js --skip-ai
```

### File Mode (Pre-built Stats)

```bash
# If you already have webpack stats files
node bundle-ai/cli.js \
  --base-stats ./stats/base.json \
  --pr-stats ./stats/pr.json \
  --lines 150
```

### Generate PR Comment

```bash
# Save comment to file (only created when explicitly requested)
node bundle-ai/cli.js --comment-file bundle-report.md

# Or post directly to GitHub (requires GITHUB_TOKEN)
node bundle-ai/cli.js --post-comment --pr 123
```

## Individual Scripts

### Build Stats
```bash
# Build stats for current branch
node bundle-ai/scripts/build-stats.js

# Build stats for specific ref
node bundle-ai/scripts/build-stats.js --ref main --output main-stats.json
```

### Diff Only
```bash
node bundle-ai/scripts/diff.js \
  --base base-stats.json \
  --pr pr-stats.json \
  --output diff-report.txt
```

### Analysis Only
```bash
node bundle-ai/scripts/analyze.js \
  --base base-stats.json \
  --pr pr-stats.json \
  --lines 200 \
  --json analysis.json
```

### Generate Comment
```bash
node bundle-ai/scripts/comment.js \
  --input analysis.json \
  --output comment.md
```

## Hyperswitch-Specific Configuration

### Webpack Config Detection

The analyzer automatically detects `webpack.common.js` (primary config) in the Hyperswitch project. Build mode is always forced to `production`.

### Payment SDK Detection

The following payment-related dependencies are flagged if found in the main bundle:

| SDK | Recommendation |
|-----|----------------|
| `@braintree/braintree-web` | Lazy load in Braintree payment component |
| `@paypal/paypal-js` | Lazy load when PayPal method selected |
| `@stripe/stripe-js` | Lazy load in Stripe payment component |
| `@adyen/adyen-web` | Lazy load in Adyen payment component |
| `@klarna/kco-server` | Lazy load in Klarna payment component |
| Apple Pay SDK | Load dynamically when Apple Pay button rendered |
| Samsung Pay SDK | Lazy load only when needed |
| Plaid SDK | Lazy load for ACH/Bank transfer payments |

### ReScript Analysis

The analyzer tracks changes in `.res` and `.resi` files to detect:
- New module imports (`open` statements)
- External bindings (`@module` declarations)
- Correlation with JavaScript dependency changes

## GitHub Actions

Example workflow for automatic bundle analysis on PRs:

```yaml
name: Bundle Analysis
on:
  pull_request:
    types: [opened, synchronize]
    paths:
      - '**.js'
      - '**.res'
      - 'package.json'

jobs:
  analyze:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      pull-requests: write
    steps:
      - uses: actions/checkout@v4
        with:
          ref: refs/pull/${{ github.event.pull_request.number }}/merge

      - uses: actions/setup-node@v4
        with:
          node-version: '20'

      - run: |
          npm ci
          node bundle-ai/cli.js --base main --head HEAD
```

### Required Secrets

- `OPENAI_API_KEY`: API key for AI analysis (optional, falls back to rules-only)
- `OPENAI_BASE_URL`: AI endpoint URL
- `GITHUB_TOKEN`: Automatically provided by GitHub Actions

## Output Format

### CLI Output

```
╔══════════════════════════════════════════════════════════════╗
║               HYPERSWITCH BUNDLE ANALYZER                    ║
╚══════════════════════════════════════════════════════════════╝

SUMMARY
────────────────────────────────────────────────────────────
Base Branch Size:  1.2 MB
PR Branch Size:    1.4 MB
Change:            +207 KB
node_modules:      +156 KB
ReScript files:    3 changed

AI VERDICT
────────────────────────────────────────────────────────────
Status: unexpected
Confidence: 85%

Explanation: Large Stripe SDK addition detected despite small code changes.
             Stripe SDK should be lazy-loaded in the payment component.

Root Cause: Added @stripe/stripe-js import in PaymentElement.res

Suggested Fixes:
  1. Lazy load Stripe SDK: React.lazy(() => import('@stripe/stripe-js'))
  2. Move import to Stripe-specific payment component
  3. Use dynamic import for conditional loading

DETECTED ISSUES
────────────────────────────────────────────────────────────

CRITICAL:
   - Payment SDK in main bundle: @stripe/stripe-js (+89 KB)
     Lazy load in Stripe payment component, not in main bundle

WARNINGS:
   - Large dependency added: framer-motion (42 KB)
     Import specific components: import { motion } from "framer-motion"
```

### JSON Output

```json
{
  "summary": {
    "baseSize": 1258291,
    "prSize": 1470307,
    "totalDiff": 212016,
    "totalDiffFormatted": "+207 KB"
  },
  "aiAnalysis": {
    "verdict": "unexpected",
    "confidence": 0.85,
    "explanation": "Payment SDK added to main bundle...",
    "rootCause": "Added @stripe/stripe-js import in PaymentElement.res",
    "suggestedFixes": [
      "Lazy load Stripe SDK",
      "Move import to Stripe payment component"
    ]
  },
  "rescript": {
    "filesModified": 3,
    "importsAdded": ["Stripe"],
    "riskAssessment": "high"
  },
  "issues": {
    "critical": 1,
    "warnings": 2,
    "info": 1
  }
}
```

## Detection Thresholds

Edit `lib/rule-engine.js` to customize:

```javascript
const THRESHOLDS = {
  LARGE_DEPENDENCY_KB: 30,      // Flag deps > 30KB
  SIZE_INCREASE_PERCENT: 20,    // Flag > 20% growth
  SIZE_INCREASE_ABSOLUTE_KB: 100, // Flag > 100KB growth
};
```

### Custom Rules

Add payment-specific patterns to `lib/rule-engine.js`:

```javascript
const FULL_IMPORT_PATTERNS = [
  // Existing patterns...
  { pattern: /@your-payment-provider/i, name: 'your-provider',
    suggestion: 'Lazy load in payment component' },
];
```

## Testing

```bash
# Run the 15-test suite
node bundle-ai/test/test-runner.js
```

## Troubleshooting

### Webpack Stats Generation Fails

```bash
# Check webpack config exists
ls webpack.common.js

# Verify ReScript compilation
npm run re:build

# Try manual webpack build
npx webpack --config webpack.common.js --profile --json > stats.json
```

### AI Analysis Timeout

- Increase timeout or skip AI: `--skip-ai`
- Check API key is valid
- Try a different model with `--model <name>` (default: `kimi-latest`)

### Git Operations Fail

Ensure you have:
- Uncommitted changes stashed or committed
- Clean working directory for branch switching
- Proper git remotes configured

## Project Structure

```
bundle-ai/
├── cli.js                    # Main entry point (loads .env automatically)
├── run.sh                    # Full report generator (fresh clone workflow)
├── .env                      # API keys (gitignored, create manually)
├── package.json              # Zero npm dependencies
├── README.md
├── lib/
│   ├── stats-parser.js       # Webpack stats parsing
│   ├── diff-engine.js        # Diff computation
│   ├── rule-engine.js        # Detection rules + UNEXPECTED_DEPENDENCY guard
│   ├── rescript-analyzer.js  # ReScript analysis
│   └── ai-client.js          # AI integration (deep context: import chains, usedExports, tree-shaking)
├── scripts/
│   ├── build-stats.js        # Build webpack stats for a git ref
│   ├── diff.js               # Compute diff between two stats files
│   ├── analyze.js            # Full analysis (rules + AI)
│   └── comment.js            # PR comment markdown generation
├── test/
│   ├── test-runner.js         # Unit tests (15 tests)
│   ├── sample-base-stats.json # Test fixture: base branch stats
│   └── sample-pr-stats.json   # Test fixture: PR stats
├── reports/                   # Generated at runtime by run.sh (gitignored)
└── tmp/                       # Used by run.sh for fresh clones (gitignored)
```

## License

MIT
