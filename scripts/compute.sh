#!/usr/bin/env bash
# =============================================================================
# imdapp compute dispatcher (POSIX)
# -----------------------------------------------------------------------------
# Routes ALL compute to GitHub Actions. This script intentionally does NOT
# execute any project script locally. See .github/COMPUTE_POLICY.md
#
# Usage: ./scripts/compute.sh <task> [board] [runner] [--no-watch]
# =============================================================================
set -euo pipefail

REPO="${IMDAPP_REPO:-jerryboganda/imdapp}"
TASK="${1:-full}"
BOARD="${2:-misc}"
RUNNER="${3:-ubuntu-latest}"
WATCH=1

for arg in "$@"; do
  [[ "$arg" == "--no-watch" ]] && WATCH=0
done

case "$TASK" in
  healthcheck|mcp-smoke|toolcheck|kb-audit|tests|site-build|release-check|full) ;;
  *) echo "Unknown task: $TASK" >&2
     echo "Valid: healthcheck mcp-smoke toolcheck kb-audit tests site-build release-check full" >&2
     exit 2 ;;
esac

command -v gh >/dev/null 2>&1 || { echo "gh CLI not found. Install: https://cli.github.com/" >&2; exit 127; }

REF="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo main)"
echo "==> Dispatching compute to GitHub Actions"
echo "    repo   : $REPO"
echo "    task   : $TASK"
echo "    board  : $BOARD"
echo "    runner : $RUNNER"
echo "    ref    : $REF"
echo

gh workflow run compute.yml \
  --repo "$REPO" \
  --ref "$REF" \
  -f task="$TASK" \
  -f board="$BOARD" \
  -f runner="$RUNNER" \
  -f write_report=true

if [[ "$WATCH" -eq 0 ]]; then
  echo "Dispatched. View: gh run list --repo $REPO --workflow compute.yml"
  exit 0
fi

echo
echo "==> Waiting for the run to register..."
RUN_ID=""
for _ in $(seq 1 20); do
  RUN_ID="$(gh run list --repo "$REPO" --workflow compute.yml --limit 1 --json databaseId --jq '.[0].databaseId' 2>/dev/null || true)"
  [[ -n "$RUN_ID" && "$RUN_ID" != "null" ]] && break
  sleep 3
done

if [[ -z "$RUN_ID" || "$RUN_ID" == "null" ]]; then
  echo "Could not resolve run id. Check: gh run list --repo $REPO --workflow compute.yml" >&2
  exit 1
fi

echo "==> Watching run $RUN_ID"
gh run watch "$RUN_ID" --repo "$REPO" --exit-status
