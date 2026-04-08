# stepN_description.ps1
# TODO: Replace with a short description of this step

# Maintenance: This file uses English comments to avoid PowerShell 5.1 parser errors.
$OutputEncoding = [System.Text.UTF8Encoding]::new($false)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if ([string]::IsNullOrEmpty($scriptDir)) { $scriptDir = "." }

# --- Load settings from JSON ---
$settingsPath = Join-Path $scriptDir "settings.json"
if (-not (Test-Path "$settingsPath")) {
    Write-Host "Error: settings.json not found." -ForegroundColor Red
    pause; exit 1
}
$jsonStr = [System.IO.File]::ReadAllText($settingsPath, [System.Text.Encoding]::UTF8)
$settings = $jsonStr | ConvertFrom-Json
$null = $settings  # TODO: access $settings properties as needed; remove this line when done

# FIX: menuCli.cmd sets 'chcp 950' before launching this script.
# Override to UTF-8 so console output renders correctly.
chcp 65001 | Out-Null
[Console]::InputEncoding = [System.Text.UTF8Encoding]::new($false)
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)

Write-Host "========================================"
Write-Host "  Step N: TODO Step Title" -ForegroundColor Cyan
Write-Host "========================================"
Write-Host ""

# TODO: implement step logic here

Read-Host "Press Enter to exit"
