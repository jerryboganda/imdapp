# Compute Policy — GitHub Actions Only

**Status: MANDATORY / mission-critical.**

All compute tasks for this project run on **GitHub Actions**. The local machine is a
*thin client*: it edits files, commits, and dispatches workflows. It does **not** run
builds, tests, analysis pipelines, or tool-chain checks.

## 1. What counts as "compute"

| Category | Examples | Where it runs |
| --- | --- | --- |
| Build | `npm run build`, site bundling | Actions |
| Test | `pytest`, PowerShell syntax sweep | Actions |
| Analysis | `lab_healthcheck.py`, `kb_doc_audit.py`, `seo_audit.py` | Actions |
| Tool-chain | `ai_toolcheck.py`, CVE pipeline smoke | Actions |
| MCP | `uv sync`, `reverse_lab_tools_mcp.py --help`, smoke checks | Actions |
| Deploy | Cloudflare Pages publish | Actions |

Everything in the right-hand column is **forbidden on the local machine**.

## 2. How to trigger compute

Use the dispatcher, never the underlying script:

```bash
# POSIX
./scripts/compute.sh <task> [board]

# Windows PowerShell
./scripts/compute.ps1 -Task <task> -Board <board>

# Windows cmd
scripts\compute.bat <task> [board]
```

Tasks: `healthcheck` · `mcp-smoke` · `toolcheck` · `kb-audit` · `tests` ·
`site-build` · `release-check` · `full`

The dispatcher calls `gh workflow run compute.yml`, then `gh run watch`.

## 3. Why

- **Reproducibility** — every run happens on a clean, pinned runner image.
- **Uniformity** — Windows and Linux checks execute identically every time.
- **Auditability** — every run is logged, attributed, and retained by GitHub.
- **Zero local drift** — the local box never accumulates half-installed tool chains.

## 4. Exceptions

Local execution is permitted **only** for:

1. `git` operations (clone, commit, push, submodule update).
2. Dependency *installation* for local IDE/MCP support (`uv sync`, `npm ci`) —
   installation is setup, not compute. It must not be used to run pipelines.
3. Reading files, syntax-only checks that do not execute project code.

If you believe a task must run locally, open an issue and get it recorded here first.

## 5. Enforcement

- `ci.yml` and `compute.yml` are the single source of truth for how checks run.
- `scripts/*` wrappers refuse to execute project scripts directly; they only dispatch.
- Reviewers must reject PRs that add local compute entry points without an
  explicit amendment to this policy.
