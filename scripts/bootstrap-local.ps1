# =============================================================================
# Local bootstrap - installs what the *thin client* needs. No compute.
# -----------------------------------------------------------------------------
# This prepares the machine to edit, commit and dispatch. It deliberately does
# NOT run tests, builds or analysis. See .github/COMPUTE_POLICY.md
# =============================================================================
[CmdletBinding()]
param(
  [string]$RepoRoot = (Split-Path -Parent $PSScriptRoot),
  [switch]$SkipUv,
  [switch]$SkipSubmodules
)

$ErrorActionPreference = 'Stop'
Write-Host "==> imdapp local bootstrap"
Write-Host "    repo root: $RepoRoot"

# --- 1. Git submodules -------------------------------------------------------
if (-not $SkipSubmodules) {
  Write-Host "`n[1/5] Syncing git submodules..."
  Push-Location $RepoRoot
  try {
    git submodule update --init --recursive
    if ($LASTEXITCODE -ne 0) { throw 'git submodule update failed' }
  } finally { Pop-Location }
} else { Write-Host "`n[1/5] Skipping submodules." }

# --- 1b. Downstream component patches ---------------------------------------
if (-not $SkipSubmodules) {
  Write-Host "`n[1b/5] Applying downstream component patches..."
  $patcher = Join-Path $RepoRoot 'scripts\apply-component-patches.sh'
  if (Test-Path $patcher) {
    if (Get-Command bash -ErrorAction SilentlyContinue) {
      & bash $patcher
      if ($LASTEXITCODE -ne 0) { Write-Warning 'Some component patches did not apply cleanly.' }
    } else {
      Write-Warning 'bash not found; apply patches manually before building the site.'
    }
  }
}

# --- 2. uv -------------------------------------------------------------------
if (-not $SkipUv) {
  Write-Host "`n[2/5] Ensuring uv is installed..."
  if (Get-Command uv -ErrorAction SilentlyContinue) {
    Write-Host "    uv already present: $(uv --version)"
  } else {
    Write-Host "    Installing uv via the official installer..."
    powershell -NoProfile -ExecutionPolicy Bypass -Command "irm https://astral.sh/uv/install.ps1 | iex"
    $uvBin = Join-Path $env:USERPROFILE '.local\bin'
    if (Test-Path $uvBin) { $env:Path = "$uvBin;$env:Path" }
    if (Get-Command uv -ErrorAction SilentlyContinue) {
      Write-Host "    uv installed: $(uv --version)"
    } else {
      Write-Warning "uv installed but not on PATH for this session. Add $uvBin to PATH."
    }
  }
} else { Write-Host "`n[2/5] Skipping uv." }

# --- 3. MCP virtualenv -------------------------------------------------------
Write-Host "`n[3/5] Preparing the reverse_lab_tools MCP environment..."
$mcpProj = Join-Path $RepoRoot 'open-reverselab\tools\skills\mcp\ReverseLabToolsMCP'
if (Test-Path $mcpProj) {
  if (Get-Command uv -ErrorAction SilentlyContinue) {
    Push-Location (Join-Path $RepoRoot 'open-reverselab')
    try {
      uv sync --project tools/skills/mcp/ReverseLabToolsMCP
      if ($LASTEXITCODE -ne 0) { Write-Warning 'uv sync failed - check network/pyproject.' }
      else { Write-Host '    MCP environment ready.' }
    } finally { Pop-Location }
  } else {
    Write-Warning 'uv not available; skipped MCP environment.'
  }
} else {
  Write-Warning "MCP project not found at $mcpProj - run git submodule update --init --recursive"
}

# --- 4. .env -----------------------------------------------------------------
Write-Host "`n[4/5] Checking environment file..."
$envFile = Join-Path $RepoRoot '.env'
$envExample = Join-Path $RepoRoot '.env.example'
if (-not (Test-Path $envFile)) {
  if (Test-Path $envExample) {
    Copy-Item $envExample $envFile
    Write-Host "    Created .env from .env.example - fill in your tokens."
  }
} else {
  Write-Host "    .env already exists - leaving it untouched."
}

# --- 5. Local component env --------------------------------------------------
Write-Host "`n[5/5] Checking component .env..."
$labEnv = Join-Path $RepoRoot 'open-reverselab\.env'
$labExample = Join-Path $RepoRoot 'open-reverselab\.env.example'
if ((Test-Path $labExample) -and (-not (Test-Path $labEnv))) {
  Copy-Item $labExample $labEnv
  Write-Host "    Created open-reverselab\.env from its example."
}

Write-Host "`n==> Bootstrap complete."
Write-Host "    Compute is REMOTE ONLY. Run: ./scripts/compute.ps1 -Task full"
