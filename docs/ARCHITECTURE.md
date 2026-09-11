# Architecture

## The core constraint

> All compute runs on GitHub Actions. Locally we only edit, commit and dispatch.

This is enforced structurally, not by convention:

- Every workflow is the single source of truth for *how* a check runs.
- `scripts/compute.*` are **dispatchers** — they call `gh workflow run` and never
  invoke a project script.
- `.github/COMPUTE_POLICY.md` records the rule and the narrow exceptions.

## Layers

```
┌──────────────────────────────────────────────────────────────┐
│  Local machine (thin client)                                  │
│  edit · git · gh dispatch · read files                        │
└───────────────────────────┬──────────────────────────────────┘
                            │ gh workflow run / git push
                            ▼
┌──────────────────────────────────────────────────────────────┐
│  GitHub Actions (compute)                                     │
│  ci.yml · compute.yml · cd-deploy.yml · security.yml          │
└───────────────────────────┬──────────────────────────────────┘
                            │ checkout submodules
                            ▼
┌──────────────────────────────────────────────────────────────┐
│  open-reverselab (vendored component, GPL-3.0)                │
│  scripts/ · tools/ · kb/ · site/ · MCP server                 │
└──────────────────────────────────────────────────────────────┘
```

## Workflows

| Workflow | Trigger | Purpose |
| --- | --- | --- |
| `ci.yml` | push, PR, manual | lint, audits, tests, MCP smoke, site build, aggregate gate |
| `compute.yml` | manual only | on-demand compute, parameterised by task/board/runner |
| `cd-deploy.yml` | after CI on `main`, manual | build + deploy docs site |
| `security.yml` | push, PR, weekly, manual | CodeQL, dependency review, secret scan |

### Why a `gate` job

Branch protection needs a single stable check name. `gate` depends on every other
CI job, so "CI gate" can be the one required status without churn when jobs are
added or renamed.

### Why `compute.yml` is manual-only

Ad-hoc analysis (a specific board's toolchain, a one-off KB audit) should not run
on every push. `workflow_dispatch` with typed inputs gives a controlled, auditable
entry point — and `scripts/compute.*` wraps it so nobody types raw `gh` flags.

## Dependency boundary

`open-reverselab` is consumed as a **git submodule**, not vendored source:

- provenance and version pinning stay explicit (`.gitmodules` + gitlink)
- its GPL-3.0 license boundary is preserved
- `git submodule update --remote` is a deliberate, reviewable upgrade

Workflows must therefore always checkout with `submodules: recursive`.

## Security posture

- Default `permissions: contents: read`; jobs opt into more.
- No long-lived credentials in the repo — everything comes from Actions secrets.
- CodeQL + gitleaks run on the same pipeline that gates merges.
