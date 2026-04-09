#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────
# Hyperswitch Bundle AI — Full Report Generator
#
# Clones fresh copies of base and PR branches into a temp folder,
# installs deps, builds production webpack stats, runs AI analysis,
# and generates every report format.
#
# Usage:
#   ./bundle-ai/run.sh                              # current branch vs main
#   ./bundle-ai/run.sh --pr feat/my-feature         # specific PR branch vs main
#   ./bundle-ai/run.sh --base develop --pr feat/x   # specific base + PR
#   ./bundle-ai/run.sh --force-build                # always rebuild (no cache)
#
# Required env vars (in bundle-ai/.env):
#   REPO_URL         — git clone URL
#   OPENAI_API_KEY   — Grid AI API key
#   OPENAI_BASE_URL  — Grid AI base URL
# ──────────────────────────────────────────────────────────────
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TMP_DIR="$SCRIPT_DIR/tmp"
REPORTS_DIR="$SCRIPT_DIR/reports"

# ── Load .env ───────────────────────────────────────────────
if [[ -f "$SCRIPT_DIR/.env" ]]; then
  set -a
  source "$SCRIPT_DIR/.env"
  set +a
fi

# ── Defaults ────────────────────────────────────────────────
BASE_REF="main"
PR_REF=""
FORCE_BUILD=false

# ── Parse args ──────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --base|-b)        BASE_REF="$2"; shift 2 ;;
    --pr|-p)          PR_REF="$2"; shift 2 ;;
    --force-build|-f) FORCE_BUILD=true; shift ;;
    --help|-h)
      echo "Usage: ./bundle-ai/run.sh [options]"
      echo ""
      echo "  --base <branch>   Base branch to compare against (default: main)"
      echo "  --pr <branch>     PR branch to analyze (default: current git branch)"
      echo "  --force-build     Skip cache, rebuild everything from scratch"
      echo ""
      echo "Required in bundle-ai/.env:"
      echo "  REPO_URL          Git clone URL for the repository"
      echo "  OPENAI_API_KEY    Grid AI API key"
      echo "  OPENAI_BASE_URL   Grid AI base URL"
      echo ""
      echo "Outputs go to bundle-ai/reports/"
      exit 0
      ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# ── Colors (only on TTY) ────────────────────────────────────
if [ -t 1 ]; then
  BOLD='\033[1m' CYAN='\033[36m' GREEN='\033[32m'
  YELLOW='\033[33m' RED='\033[31m' RESET='\033[0m'
else
  BOLD="" CYAN="" GREEN="" YELLOW="" RED="" RESET=""
fi

info()  { echo -e "${CYAN}${BOLD}▸${RESET} $1"; }
ok()    { echo -e "${GREEN}✓${RESET} $1"; }
warn()  { echo -e "${YELLOW}⚠${RESET} $1"; }
fail()  { echo -e "${RED}✗${RESET} $1"; exit 1; }

# ── Banner ──────────────────────────────────────────────────
echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════════════════╗${RESET}"
echo -e "${CYAN}║        HYPERSWITCH BUNDLE AI — FULL REPORT              ║${RESET}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${RESET}"
echo ""

# ── Preflight checks ───────────────────────────────────────
[[ -f "$SCRIPT_DIR/.env" ]] || fail ".env missing at $SCRIPT_DIR/.env"
[[ -n "${REPO_URL:-}" ]]    || fail "REPO_URL not set in $SCRIPT_DIR/.env"
[[ -n "${OPENAI_API_KEY:-}" ]] || fail "OPENAI_API_KEY not set in $SCRIPT_DIR/.env"

# Auto-detect PR branch from current git branch if not provided
if [[ -z "$PR_REF" ]]; then
  PR_REF=$(git -C "$PROJECT_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
  [[ -n "$PR_REF" ]] || fail "Could not detect current branch. Use --pr <branch> explicitly."
  info "Auto-detected PR branch: $PR_REF"
fi

echo "Base: $BASE_REF"
echo "PR:   $PR_REF"
echo "Repo: $REPO_URL"
echo ""

# ── Step 1: Clean tmp directory ─────────────────────────────
info "Cleaning tmp directory..."
rm -rf "$TMP_DIR"
mkdir -p "$TMP_DIR"
ok "Cleared $TMP_DIR"
echo ""

# ── Step 2: Clone and build stats ───────────────────────────

clone_and_build() {
  local branch="$1"
  local label="$2"
  local clone_dir="$TMP_DIR/$label"
  local stats_file="$TMP_DIR/stats-${label}.json"

  info "[$label] Cloning $branch ..."
  git clone --depth 1 --branch "$branch" --single-branch "$REPO_URL" "$clone_dir" 2>&1 | tail -1
  ok "[$label] Cloned into $clone_dir"

  info "[$label] Installing dependencies..."
  npm ci --prefix "$clone_dir" --loglevel=error 2>&1
  ok "[$label] Dependencies installed"

  info "[$label] Building production webpack stats..."
  local webpack_bin="$clone_dir/node_modules/.bin/webpack"
  local webpack_config="$clone_dir/webpack.common.js"

  if [[ ! -f "$webpack_config" ]]; then
    # Fallback config names
    for cfg in webpack.prod.js webpack.config.js; do
      if [[ -f "$clone_dir/$cfg" ]]; then
        webpack_config="$clone_dir/$cfg"
        break
      fi
    done
  fi

  if [[ ! -f "$webpack_bin" ]]; then
    fail "[$label] webpack not found in node_modules. Is it a dependency?"
  fi

  # Run webpack in production mode, capture JSON stats
  local raw_output
  raw_output=$("$webpack_bin" \
    --config "$webpack_config" \
    --mode production \
    --profile --json \
    2>/dev/null) || true

  # Extract JSON from webpack output (it may print non-JSON before/after)
  local json_start json_end
  json_start=$(echo "$raw_output" | grep -n '{' | head -1 | cut -d: -f1)

  if [[ -z "$json_start" ]]; then
    fail "[$label] webpack did not produce JSON output"
  fi

  echo "$raw_output" | tail -n +"$json_start" > "$stats_file"

  # Validate JSON
  node -e "JSON.parse(require('fs').readFileSync('$stats_file','utf8'))" 2>/dev/null \
    || fail "[$label] Invalid JSON in webpack stats output"

  local size
  size=$(du -sh "$stats_file" | cut -f1)
  ok "[$label] Stats saved: $stats_file ($size)"
  echo ""
}

clone_and_build "$BASE_REF" "base"
clone_and_build "$PR_REF" "pr"

BASE_STATS="$TMP_DIR/stats-base.json"
PR_STATS="$TMP_DIR/stats-pr.json"

# ── Step 3: Run AI analysis (text report) ──────────────────
mkdir -p "$REPORTS_DIR"

info "Running AI-powered analysis..."
node "$SCRIPT_DIR/scripts/analyze.js" \
  --base "$BASE_STATS" \
  --pr "$PR_STATS" \
  2>&1 | tee "$REPORTS_DIR/analyze-report.txt"
ok "Text report saved: $REPORTS_DIR/analyze-report.txt"
echo ""

# ── Step 4: Run AI analysis (JSON output) ──────────────────
info "Generating JSON output..."
node "$SCRIPT_DIR/scripts/analyze.js" \
  --base "$BASE_STATS" \
  --pr "$PR_STATS" \
  --json \
  2>/dev/null > "$REPORTS_DIR/analyze-output.json"
ok "JSON report saved: $REPORTS_DIR/analyze-output.json"
echo ""

# ── Step 5: Generate PR comment markdown ───────────────────
info "Generating PR comment markdown..."
node "$SCRIPT_DIR/scripts/comment.js" \
  --input "$REPORTS_DIR/analyze-output.json" \
  2>/dev/null > "$REPORTS_DIR/comment-report.md"
ok "Comment report saved: $REPORTS_DIR/comment-report.md"
echo ""

# ── Step 6: Run full CLI (text + JSON + comment combined) ──
info "Running full CLI report..."
node "$SCRIPT_DIR/cli.js" \
  --base-stats "$BASE_STATS" \
  --pr-stats "$PR_STATS" \
  --comment-file "$REPORTS_DIR/comment-report.md" \
  --json "$REPORTS_DIR/cli-json-output.json" \
  2>&1 | tee "$REPORTS_DIR/cli-with-ai.txt"
ok "CLI text report saved: $REPORTS_DIR/cli-with-ai.txt"
ok "CLI JSON output saved: $REPORTS_DIR/cli-json-output.json"
echo ""

# ── Step 7: Run diff report ───────────────────────────────
info "Generating diff report..."
node "$SCRIPT_DIR/scripts/diff.js" \
  --base "$BASE_STATS" \
  --pr "$PR_STATS" \
  2>&1 > "$REPORTS_DIR/diff-report.txt"
ok "Diff report saved: $REPORTS_DIR/diff-report.txt"
echo ""

# ── Step 8: Run tests ────────────────────────────────────
info "Running tests..."
node "$SCRIPT_DIR/test/test-runner.js" 2>&1 | tee "$REPORTS_DIR/test-results.txt"
echo ""

# ── Summary ───────────────────────────────────────────────
echo -e "${CYAN}╔══════════════════════════════════════════════════════════╗${RESET}"
echo -e "${CYAN}║                    ALL DONE                             ║${RESET}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${RESET}"
echo ""
echo "Base branch: $BASE_REF"
echo "PR branch:   $PR_REF"
echo ""
echo "Reports in: $REPORTS_DIR/"
echo ""
ls -1 "$REPORTS_DIR/" | while read -r f; do
  echo "  $(du -sh "$REPORTS_DIR/$f" | cut -f1)  $f"
done
echo ""

# Show AI verdict from JSON
if [[ -f "$REPORTS_DIR/analyze-output.json" ]]; then
  VERDICT=$(node -e "const r=require('$REPORTS_DIR/analyze-output.json'); console.log(r.aiAnalysis?.verdict || r.ai?.verdict || 'unknown')")
  CONFIDENCE=$(node -e "const r=require('$REPORTS_DIR/analyze-output.json'); console.log(Math.round((r.aiAnalysis?.confidence || r.ai?.confidence || 0)*100))")
  echo -e "AI Verdict: ${BOLD}${VERDICT}${RESET} (${CONFIDENCE}% confidence)"
fi
echo ""
