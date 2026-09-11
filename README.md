# imdapp — compute control plane

`imdapp` is the **control plane** for this workspace. It vendors
[`open-reverselab`](https://github.com/LING71671/open-reverselab) as a pinned git
submodule and enforces a single, non-negotiable rule:

> **Every compute task runs on GitHub Actions. The local machine only edits,
> commits and dispatches.**

See [`​.github/COMPUTE_POLICY.md`](.github/COMPUTE_POLICY.md) for the full policy.

---

## Architecture

```
imdapp/                          <- this repo (control plane)
├── .github/
│   ├── workflows/
│   │   ├── ci.yml               full verification pipeline
│   │   ├── compute.yml          the ONLY sanctioned compute entry point
│   │   ├── cd-deploy.yml        deploy after CI passes
│   │   └── security.yml         CodeQL · dependency review · secret scan
│   ├── COMPUTE_POLICY.md        the mandate
│   ├── CODEOWNERS
│   └── dependabot.yml
├── open-reverselab/             <- vendored component (git submodule)
├── scripts/
│   ├── compute.sh|.ps1|.bat     thin dispatchers -> gh workflow run
│   ├── bootstrap-local.ps1      local setup (no compute)
│   └── verify-integrations.sh   read-only repo health check
├── docs/
│   ├── INSTALL.md
│   ├── ARCHITECTURE.md
│   └── VERIFICATION.md
├── .env.example
└── README.md
```

## Quick start

```bash
# 1. Clone with the vendored component
git clone --recurse-submodules https://github.com/jerryboganda/imdapp.git
cd imdapp

# 2. Prepare the thin client (installs uv, MCP env, .env). No compute.
pwsh ./scripts/bootstrap-local.ps1        # Windows
# or: bash scripts/misc/bootstrap.sh      # inside the component, POSIX

# 3. Run ANY compute task - it executes on GitHub Actions
./scripts/compute.sh full                 # POSIX
./scripts/compute.ps1 -Task full          # Windows
```

## Compute tasks

| Task | What it runs | Where |
| --- | --- | --- |
| `healthcheck` | `lab_healthcheck.py` | Actions |
| `mcp-smoke` | `uv sync` + MCP CLI + `mcp_smoke_check.py` | Actions |
| `toolcheck` | `ai_toolcheck.py --board <board>` | Actions |
| `kb-audit` | KB doc audit · frontmatter · SEO | Actions |
| `tests` | `pytest` | Actions |
| `site-build` | `npm ci && npm run build` | Actions |
| `release-check` | `public_release_check.py` | Actions |
| `full` | all of the above | Actions |

## Required secrets

Set in **Settings → Secrets and variables → Actions** (or on the `production`
environment):

| Name | Purpose |
| --- | --- |
| `GITHUB_PERSONAL_ACCESS_TOKEN` | MCP + GitHub integration |
| `CLOUDFLARE_API_TOKEN` | docs site deploy |
| `CLOUDFLARE_ACCOUNT_ID` | docs site deploy |

## License

This control plane is a separate work from the vendored component.
`open-reverselab` is licensed **GPL-3.0-only** — see
`open-reverselab/LICENSE`. Vendoring via submodule keeps the boundary clean.
