# Verification

How to prove the installation is correct and the integrations are functional.

## Level 1 — repository integration (read-only, local)

```bash
bash scripts/verify-integrations.sh
```

Checks: auth + scopes, repo access, Actions enabled, workflow token permissions,
registered workflows, environments, secrets, branch protection. Exit code is
non-zero if any **FAIL** is recorded.

## Level 2 — compute pipeline (remote)

```bash
./scripts/compute.sh full
```

Dispatches `compute.yml` and watches the run. Expected: every task step green and
`reports/` uploaded as an artifact.

Equivalent, by hand:

```bash
gh workflow run compute.yml -f task=full -f board=misc -f runner=ubuntu-latest -f write_report=true
gh run list --workflow compute.yml --limit 5
gh run watch <run-id> --exit-status
```

## Level 3 — CI gate (remote)

Push to `main` (or open a PR). Expected jobs:

| Job | Runner | Meaning |
| --- | --- | --- |
| `lint-and-test` | ubuntu | release boundary, health, toolcheck, KB audit, SEO, pytest |
| `windows-smoke` | windows | PowerShell syntax sweep, CVE pipeline smoke |
| `mcp-smoke` | ubuntu | `uv sync`, MCP CLI `--help`, tool smoke check |
| `site-build` | ubuntu | `npm ci && npm run build` |
| `gate` | ubuntu | aggregate — all of the above must be `success` |

## Level 4 — component-level checks

These mirror `open-reverselab`'s own `release-check.yml` and are run *inside*
the CI pipeline, never locally:

```bash
# on Actions only, working-directory: open-reverselab
python scripts/misc/public_release_check.py
python scripts/misc/lab_healthcheck.py
python scripts/misc/ai_toolcheck.py --board misc
python scripts/misc/kb_doc_audit.py
python scripts/misc/add_frontmatter.py --verify
python scripts/misc/seo_audit.py
python -m pytest
```

## Expected evidence

| Artifact | Where |
| --- | --- |
| `mcp-smoke-report` | CI run artifacts |
| `site-dist` | CI run artifacts |
| `compute-reports-<task>` | compute run artifacts |
| `first-run-report.json` | `open-reverselab/reports/misc/` (component-local) |
| Step summary | each run's Summary tab |

## Known non-blockers

- **`gh auth status` false negative** — a valid token can exist while
  `gh auth status` reports "not logged in". Trust `gh api user`.
- **Cloudflare secrets absent** — CD still builds and uploads the site; only the
  publish step is skipped, with a warning.
- **Windows Defender** — the component ships security-testing payloads that may
  be flagged. That is expected content; exclude narrowly if needed.
