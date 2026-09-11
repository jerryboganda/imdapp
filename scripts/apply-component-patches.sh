#!/usr/bin/env bash
# =============================================================================
# Apply downstream patches to the vendored component.
# -----------------------------------------------------------------------------
# `open-reverselab` is consumed as a pristine git submodule, so we cannot commit
# fixes into it (the pinned SHA must stay fetchable from upstream). Known
# upstream defects are therefore carried as tracked patch files here and applied
# idempotently - locally during bootstrap, and in CI before building.
#
# Idempotent: re-running is safe. If upstream fixes the defect the patch no
# longer applies and is reported as already-applied or stale.
# =============================================================================
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPONENT="$ROOT/open-reverselab"
PATCH_DIR="$ROOT/patches"

if [[ ! -d "$COMPONENT/.git" && ! -f "$COMPONENT/.git" ]]; then
  echo "component not checked out; run: git submodule update --init --recursive" >&2
  exit 1
fi

shopt -s nullglob
patches=("$PATCH_DIR"/*.patch)
shopt -u nullglob

if [[ ${#patches[@]} -eq 0 ]]; then
  echo "no component patches to apply"
  exit 0
fi

echo "==> Applying component patches (${#patches[@]})"
rc=0
for p in "${patches[@]}"; do
  name="$(basename "$p")"
  # Use a path relative to the component: native git on Windows cannot resolve
  # MSYS-style absolute paths such as /c/Users/...
  rel="../patches/$name"
  if ( cd "$COMPONENT" && git apply --check "$rel" >/dev/null 2>&1 ); then
    ( cd "$COMPONENT" && git apply "$rel" )
    echo "  APPLIED         $name"
  elif ( cd "$COMPONENT" && git apply --reverse --check "$rel" >/dev/null 2>&1 ); then
    echo "  ALREADY-APPLIED $name"
  else
    echo "  STALE           $name  (does not apply cleanly - upstream may have changed)"
    rc=1
  fi
done

exit $rc
