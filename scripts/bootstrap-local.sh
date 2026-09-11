#!/usr/bin/env bash
# =============================================================================
# Local bootstrap (POSIX) - prepares the thin client. No compute.
# Mirrors scripts/bootstrap-local.ps1
# =============================================================================
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
echo "==> imdapp local bootstrap"
echo "    repo root: $ROOT"

echo
echo "[1/4] Syncing git submodules..."
( cd "$ROOT" && git submodule update --init --recursive )

echo
echo "[1b/4] Applying downstream component patches..."
bash "$ROOT/scripts/apply-component-patches.sh" || echo "    WARNING: some patches did not apply (see above)"

echo
echo "[2/4] Ensuring uv is installed..."
if command -v uv >/dev/null 2>&1; then
  echo "    uv already present: $(uv --version)"
else
  echo "    Installing uv via the official installer..."
  curl -LsSf https://astral.sh/uv/install.sh | sh
  export PATH="$HOME/.local/bin:$PATH"
  if command -v uv >/dev/null 2>&1; then
    echo "    uv installed: $(uv --version)"
  else
    echo "    WARNING: uv installed but not on PATH. Add \$HOME/.local/bin to PATH." >&2
  fi
fi

echo
echo "[3/4] Preparing the reverse_lab_tools MCP environment..."
if [[ -d "$ROOT/open-reverselab/tools/skills/mcp/ReverseLabToolsMCP" ]]; then
  if command -v uv >/dev/null 2>&1; then
    ( cd "$ROOT/open-reverselab" && uv sync --project tools/skills/mcp/ReverseLabToolsMCP )
    echo "    MCP environment ready."
  else
    echo "    WARNING: uv unavailable, skipped." >&2
  fi
else
  echo "    WARNING: MCP project missing - run git submodule update --init --recursive" >&2
fi

echo
echo "[4/4] Environment files..."
[[ -f "$ROOT/.env" ]] || { cp "$ROOT/.env.example" "$ROOT/.env" && echo "    created .env"; }
if [[ -f "$ROOT/open-reverselab/.env.example" && ! -f "$ROOT/open-reverselab/.env" ]]; then
  cp "$ROOT/open-reverselab/.env.example" "$ROOT/open-reverselab/.env"
  echo "    created open-reverselab/.env"
fi

echo
echo "==> Bootstrap complete. Compute is REMOTE ONLY: ./scripts/compute.sh full"
