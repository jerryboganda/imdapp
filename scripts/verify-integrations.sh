#!/usr/bin/env bash
# =============================================================================
# Repository integration verification.
# Confirms the GitHub side of the control plane is wired up correctly:
#   - authentication and scopes
#   - Actions enabled + workflow permissions
#   - branch protection / required checks
#   - environments and secrets present
#   - workflows registered and their latest runs
# Read-only: makes no changes.
#
# NOTE: `gh api` writes its error payload to STDOUT as well as stderr, so
# checking "is the output non-empty?" produces false positives. Every check
# below branches on the exit code instead.
# =============================================================================
set -uo pipefail

REPO="${IMDAPP_REPO:-jerryboganda/imdapp}"
PASS=0; WARN=0; FAIL=0

ok()   { printf '  \033[32mPASS\033[0m  %s\n' "$1"; PASS=$((PASS+1)); }
warn() { printf '  \033[33mWARN\033[0m  %s\n' "$1"; WARN=$((WARN+1)); }
bad()  { printf '  \033[31mFAIL\033[0m  %s\n' "$1"; FAIL=$((FAIL+1)); }

# Run a gh api call; sets API_OK and API_OUT
api() { API_OUT="$(gh api "$@" 2>/dev/null)"; API_OK=$?; }

echo "==> Verifying integrations for $REPO"
echo

# --- 1. auth -----------------------------------------------------------------
echo "[1] Authentication"
if ! gh auth token >/dev/null 2>&1; then
  bad "no gh token available (run: gh auth login)"
else
  api user --jq '.login'
  if [[ $API_OK -eq 0 && -n "$API_OUT" ]]; then
    ok "authenticated as $API_OUT"
  else
    bad "token present but API call failed"
  fi
  SCOPES="$(gh api -i user 2>/dev/null | grep -i '^x-oauth-scopes:' | cut -d: -f2- | tr -d '\r')"
  for need in repo workflow; do
    if echo "$SCOPES" | grep -q "$need"; then ok "scope: $need"; else bad "missing scope: $need"; fi
  done
fi

# --- 2. repo access ----------------------------------------------------------
echo
echo "[2] Repository access"
api "repos/$REPO" --jq '.permissions.admin'
if [[ $API_OK -ne 0 ]]; then
  bad "cannot access repos/$REPO"
elif [[ "$API_OUT" == "true" ]]; then
  ok "admin access to $REPO"
else
  warn "no admin access to $REPO"
fi

# --- 3. Actions enabled + permissions ---------------------------------------
echo
echo "[3] Actions configuration"
api "repos/$REPO/actions/permissions"
if [[ $API_OK -ne 0 ]]; then
  warn "could not read Actions permissions"
else
  if echo "$API_OUT" | grep -q '"enabled":true'; then ok "Actions enabled"; else bad "Actions disabled"; fi
fi

api "repos/$REPO/actions/permissions/workflow"
if [[ $API_OK -ne 0 ]]; then
  warn "could not read workflow token permissions"
else
  if echo "$API_OUT" | grep -q '"default_workflow_permissions":"write"'; then
    ok "default workflow token: write"
  else
    warn "default workflow token is read-only (some jobs may need write)"
  fi
  if echo "$API_OUT" | grep -q '"can_approve_pull_request_reviews":true'; then
    ok "Actions may create/approve PRs"
  else
    warn "Actions cannot create/approve PRs (Dependabot PRs won't auto-run CI)"
  fi
fi

# --- 4. workflows ------------------------------------------------------------
echo
echo "[4] Workflows"
api "repos/$REPO/actions/workflows" --jq '.workflows[].path'
if [[ $API_OK -ne 0 || -z "$API_OUT" ]]; then
  warn "no workflows registered yet (push the repo first)"
else
  while IFS= read -r w; do [[ -n "$w" ]] && ok "registered: $w"; done <<< "$API_OUT"
fi

# --- 5. environments & secrets ----------------------------------------------
echo
echo "[5] Environments and secrets"
api "repos/$REPO/environments" --jq '.environments[].name'
if [[ $API_OK -ne 0 || -z "$API_OUT" ]]; then
  warn "no environments defined (production env needed for CD deploy)"
else
  while IFS= read -r e; do [[ -n "$e" ]] && ok "environment: $e"; done <<< "$API_OUT"
fi

api "repos/$REPO/actions/secrets" --jq '.secrets[].name'
if [[ $API_OK -ne 0 || -z "$API_OUT" ]]; then
  warn "no repository secrets set"
else
  while IFS= read -r s; do [[ -n "$s" ]] && ok "secret: $s"; done <<< "$API_OUT"
fi

# --- 6. branch protection ----------------------------------------------------
echo
echo "[6] Branch protection (main)"
api "repos/$REPO/branches/main/protection"
if [[ $API_OK -eq 0 ]]; then
  ok "branch protection active on main"
  api "repos/$REPO/branches/main/protection" --jq '.required_status_checks.contexts[]?'
  [[ -n "$API_OUT" ]] && while IFS= read -r c; do ok "required check: $c"; done <<< "$API_OUT"
else
  warn "no branch protection on main (recommended once CI is green)"
fi

# --- summary -----------------------------------------------------------------
echo
echo "==========================================="
printf '  PASS: %d   WARN: %d   FAIL: %d\n' "$PASS" "$WARN" "$FAIL"
echo "==========================================="
[[ "$FAIL" -eq 0 ]] && exit 0 || exit 1
