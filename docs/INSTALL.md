# Installation

Two layers: the **control plane** (this repo) and the **vendored component**
(`open-reverselab`). Installation is split so that *setup* happens locally and
*compute* happens on Actions.

## Prerequisites

| Tool | Version | Why |
| --- | --- | --- |
| Git | ≥ 2.40 | submodules |
| Python | 3.12 | project scripts (runs on Actions; local only for IDE) |
| Node | 22 | docs site (Actions only) |
| `uv` | latest | MCP server runtime |
| `gh` | ≥ 2.40 | dispatching workflows |

## 1. Clone

```bash
git clone --recurse-submodules https://github.com/jerryboganda/imdapp.git
cd imdapp
```

If you already cloned without submodules:

```bash
git submodule update --init --recursive
```

## 2. Authenticate `gh`

```bash
gh auth login          # scopes needed: repo, workflow, read:org
gh auth status
```

> Some `gh` builds report "not logged in" while still holding a valid token.
> Verify with `gh api user --jq .login` rather than trusting `gh auth status`.

## 3. Local bootstrap (no compute)

```powershell
pwsh ./scripts/bootstrap-local.ps1
```

This will:

1. sync submodules
2. install `uv` if missing
3. create the MCP environment (`uv sync`)
4. create `.env` from `.env.example`
5. create `open-reverselab/.env` from its example

It does **not** run tests, builds or analysis — that is deliberate.

## 4. Configure secrets

Repository → **Settings → Secrets and variables → Actions**:

| Secret | Required for |
| --- | --- |
| `GITHUB_PERSONAL_ACCESS_TOKEN` | MCP / GitHub integration |
| `CLOUDFLARE_API_TOKEN` | site deploy (optional) |
| `CLOUDFLARE_ACCOUNT_ID` | site deploy (optional) |

## 5. Verify

```bash
bash scripts/verify-integrations.sh
```

Then run the first compute task:

```bash
./scripts/compute.sh full
```

## Troubleshooting

| Symptom | Fix |
| --- | --- |
| `open-reverselab/` is empty | `git submodule update --init --recursive` |
| `uv: command not found` | reopen the shell after bootstrap, or add `%USERPROFILE%\.local\bin` to PATH |
| `gh workflow run` → 404 | wrong `IMDAPP_REPO`, or workflow not yet pushed to the default branch |
| CI job can't see component files | workflow must checkout with `submodules: recursive` |
