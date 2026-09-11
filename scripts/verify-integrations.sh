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
# =============================================================================
set -uo pipefail

REPO="${IMDAPP_REPO:-jerryboganda/imdapp}"
PASS=0; WARN=0; FAIL=0

ok()   { printf '  \033[32mPASS\033[0m  %s\n' "$1"; PASS=$((PASS+1)); }
warn() { printf '  \033[33mWARN\033[0m  %s\n' "$1"; WARN=$((WARN+1)); }
bad()  { printf '  \033[31mFAIL\033[0m  %s\n' "$1"; FAIL=$((FAIL+1)); }

echo "==> Verifying integrations for $REPO"
echo

# --- 1. auth -----------------------------------------------------------------
echo "[1] Authentication"
if ! gh auth token >/dev/null 2>&1; then
  bad "no gh token available (run: gh auth login)"
else
  LOGIN="$(gh api user --jq '.login' 2>/dev/null)"
  if [[ -n "$LOGIN" ]]; then ok "authenticated as $LOGIN"; else bad "token present but API call failed"; fi
  SCOPES="$(gh api -i user 2>/dev/null | grep -i '^x-oauth-scopes:' | cut -d: -f2- | tr -d '\r')"
  for need in repo workflow; do
    if echo "$SCOPES" | grep -q "$need"; then ok "scope: $need"; else bad "missing scope: $need"; fi
  done
fi

# --- 2. repo access ----------------------------------------------------------
echo
echo "[2] Repository access"
if gh api "repos/$REPO" >/dev/null 2>&1; then
  PERM="$(gh api "repos/$REPO" --jq '.permissions.admin' 2>/dev/null)"
  [[ "$PERM" == "true" ]] && ok "admin access to $REPO" || warn "no admin access to $REPO"
else
  bad "cannot access repos/$REPO"
fi

# --- 3. Actions enabled + permissions ---------------------------------------
echo
echo "[3] Actions configuration"
ACT="$(gh api "repos/$REPO/actions/permissions" 2>/dev/null)"
if [[ -n "$ACT" ]]; then
  ENABLED="$(echo "$ACT" | grep -o '"enabled":[a-z]*' | cut -d: -f2)"
  [[ "$ENABLED" == "true" ]] && ok "Actions enabled" || bad "Actions disabled"
  WP="$(gh api "repos/$REPO/actions/permissions/workflow" 2>/dev/null)"
  echo "$WP" | grep -q '"default_workflow_permissions":"write"' \
    && ok "default workflow token: write" \
    || warn "default workflow token is read-only (some jobs may need write)"
  echo "$WP" | grep -q '"can_approve_pull_request_reviews":true' \
    && ok "Actions may create/approve PRs" \
    || warn "Actions cannot create/approve PRs (Dependabot PRs won't auto-run CI)"
else
  warn "could not read Actions permissions"
fi

# --- 4. workflows ------------------------------------------------------------
echo
echo "[4] Workflows"
WFS="$(gh api "repos/$REPO/actions/workflows" --jq '.workflows[].path' 2>/dev/null)"
if [[ -n "$WFS" ]]; then
  while IFS= read -r w; do [[ -n "$w" ]] && ok "registered: $w"; done <<< "$WFS"
else
  warn "no workflows registered yet (push the repo first)"
fi

# --- 5. environments & secrets ----------------------------------------------
echo
echo "[5] Environments and secrets"
ENVS="$(gh api "repos/$REPO/environments" --jq '.environments[].name' 2>/dev/null)"
if [[ -n "$ENVS" ]]; then
  while IFS= read -r e; do [[ -n "$e" ]] && ok "environment: $e"; done <<< "$ENVS"
else
  warn "no environments defined (production env needed for CD deploy)"
fi

SECRETS="$(gh api "repos/$REPO/actions/secrets" --jq '.secrets[].name' 2>/dev/null)"
if [[ -n "$SECRETS" ]]; then
  while IFS= read -r s; do [[ -n "$s" ]] && ok "secret: $s"; done <<< "$SECRETS"
else
  warn "no repository secrets set"
fi

# --- 6. branch protection ----------------------------------------------------
echo
echo "[6] Branch protection (main)"
BP="$(gh api "repos/$REPO/branches/main/protection" 2>/dev/null)"
if [[ -n "$BP" ]]; then
  ok "branch protection active on main"
else
  warn "no branch protection on main (recommended once CI is green)"
fi

# --- summary -----------------------------------------------------------------
echo
echo "==========================================="
printf '  PASS: %d   WARN: %d   FAIL: %d\n' "$PASS" "$WARN" "$FAIL"
echo "==========================================="
[[ "$FAIL" -eq 0 ]] && exit 0 || exit 1
