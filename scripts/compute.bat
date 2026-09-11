@echo off
REM ============================================================================
REM imdapp compute dispatcher (Windows cmd)
REM Routes ALL compute to GitHub Actions. See .github\COMPUTE_POLICY.md
REM Usage: scripts\compute.bat <task> [board] [runner]
REM ============================================================================
setlocal
set TASK=%1
if "%TASK%"=="" set TASK=full
set BOARD=%2
if "%BOARD%"=="" set BOARD=misc
set RUNNER=%3
if "%RUNNER%"=="" set RUNNER=ubuntu-latest

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0compute.ps1" -Task %TASK% -Board %BOARD% -Runner %RUNNER%
endlocal
