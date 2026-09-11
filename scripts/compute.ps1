<#
.SYNOPSIS
  imdapp compute dispatcher (Windows PowerShell).
.DESCRIPTION
  Routes ALL compute to GitHub Actions. Does NOT execute project scripts locally.
  See .github/COMPUTE_POLICY.md
.EXAMPLE
  ./scripts/compute.ps1 -Task full
  ./scripts/compute.ps1 -Task toolcheck -Board ctf-website -Runner windows-latest
#>
[CmdletBinding()]
param(
  [Parameter(Position = 0)]
  [ValidateSet('healthcheck','mcp-smoke','toolcheck','kb-audit','tests','site-build','release-check','full')]
  [string]$Task = 'full',

  [Parameter(Position = 1)]
  [string]$Board = 'misc',

  [Parameter(Position = 2)]
  [ValidateSet('ubuntu-latest','windows-latest','macos-latest')]
  [string]$Runner = 'ubuntu-latest',

  [string]$Repo = $env:IMDAPP_REPO,

  [switch]$NoWatch
)

$ErrorActionPreference = 'Stop'
if (-not $Repo) { $Repo = 'jerryboganda/imdapp' }

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
  throw "gh CLI not found. Install from https://cli.github.com/"
}

$ref = (git rev-parse --abbrev-ref HEAD 2>$null)
if (-not $ref) { $ref = 'main' }

Write-Host '==> Dispatching compute to GitHub Actions'
Write-Host "    repo   : $Repo"
Write-Host "    task   : $Task"
Write-Host "    board  : $Board"
Write-Host "    runner : $Runner"
Write-Host "    ref    : $ref"
Write-Host ''

gh workflow run compute.yml --repo $Repo --ref $ref -f task=$Task -f board=$Board -f runner=$Runner -f write_report=true
if ($LASTEXITCODE -ne 0) { throw 'gh workflow run failed' }

if ($NoWatch) {
  Write-Host "Dispatched. View: gh run list --repo $Repo --workflow compute.yml"
  exit 0
}

Write-Host ''
Write-Host '==> Waiting for the run to register...'
$runId = $null
for ($i = 0; $i -lt 20; $i++) {
  $runId = (gh run list --repo $Repo --workflow compute.yml --limit 1 --json databaseId --jq '.[0].databaseId') 2>$null
  if ($runId -and $runId -ne 'null') { break }
  Start-Sleep -Seconds 3
}

if (-not $runId -or $runId -eq 'null') {
  throw "Could not resolve run id. Check: gh run list --repo $Repo --workflow compute.yml"
}

Write-Host "==> Watching run $runId"
gh run watch $runId --repo $Repo --exit-status
