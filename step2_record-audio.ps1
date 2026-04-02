# step2_record-audio.ps1
# Record audio from microphone using FFmpeg

# Maintenance: This file uses English comments to avoid PowerShell 5.1 parser errors.

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
$audioConfig = $settings.audio

$ffmpegPath = Join-Path $scriptDir "FFmpeg\ffmpeg.exe"
if (-not (Test-Path "$ffmpegPath")) {
    Write-Host "Error: ffmpeg.exe not found at $ffmpegPath" -ForegroundColor Red
    pause; exit 1
}

# FIX: menu.cmd sets 'chcp 950' (Big5) before launching this script.
# We must override it with UTF-8 (65001) so that Chinese device names
# and menu text are displayed correctly in the console.
chcp 65001 | Out-Null
[Console]::InputEncoding  = [System.Text.UTF8Encoding]::new($false)
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)

# --- Robust Device Discovery ---
Write-Host "Searching for audio devices..." -ForegroundColor Gray

$raw = & "$ffmpegPath" -list_devices true -f dshow -i dummy 2>&1

$mics = @()
foreach ($line in $raw) {
    if ($line -match '"([^"]+)"\s*\(audio\)') {
        $mics += $Matches[1].Trim()
    }
}

if ($mics.Count -eq 0) {
    Write-Host "Error: No audio devices found!" -ForegroundColor Red
    pause; exit 1
}

# --- Menu Display ---
Write-Host "=========================================="
Write-Host "      Select Recording Device" -ForegroundColor Cyan
Write-Host "=========================================="
for ($i=0; $i -lt $mics.Count; $i++) {
    Write-Host " [$($i+1)] : $($mics[$i])" -ForegroundColor Green
}
Write-Host " [Enter] : Quit" -ForegroundColor Yellow
Write-Host "=========================================="

$choice = Read-Host "Choice"
if ([string]::IsNullOrEmpty($choice)) { exit 0 }

# FIX: Always initialize $userVal before passing it as [ref] to TryParse.
# Without this, PowerShell reuses the stale value from a previous run in the
# same session, causing the wrong device to be selected.
$userVal = 0
if (-not [int]::TryParse($choice, [ref]$userVal) -or $userVal -lt 1 -or $userVal -gt $mics.Count) {
    Write-Host "Invalid choice." -ForegroundColor Red
    pause; exit 1
}

$selectedDevice = $mics[$userVal - 1]
$time = Get-Date -Format "MMdd_HHmm"
$fileName = "Record_$time.$($audioConfig.format)"
$filePath = Join-Path $scriptDir $fileName

# --- Start Recording ---
Clear-Host
Write-Host "------------------------------------------"
Write-Host " Selected Device: $selectedDevice" -ForegroundColor Yellow
Write-Host " Output File:     $fileName"
Write-Host " Press [Q] to stop recording" -ForegroundColor Red
Write-Host "------------------------------------------"

$ffmpegArgs = @("-f", "dshow", "-i", "audio=$selectedDevice")

if ($audioConfig.format -eq "mp3") {
    $ffmpegArgs += @("-c:a", "libmp3lame", "-q:a", "$($audioConfig.mp3Quality)")
} else {
    $ffmpegArgs += @("-c:a", "aac", "-b:a", "$($audioConfig.m4aQuality)k")
}
$ffmpegArgs += @("-y", "$filePath")

# FIX: Use the call operator (&) with splatting (@ffmpegArgs) instead of
# Start-Process -ArgumentList. Start-Process joins the array with spaces and
# does not quote individual arguments, so device names containing spaces
# (e.g. "麥克風 (Logi C310 HD WebCam)") would be split and fail.
# Splatting passes each element as a separate argument, no quoting needed.
& "$ffmpegPath" @ffmpegArgs

Start-Sleep -Milliseconds 500

if (Test-Path "$filePath") {
    $size = (Get-Item "$filePath").Length
    if ($size -gt 1000) {
        Write-Host "`nSuccess! Saved to: $fileName" -ForegroundColor Green
        Write-Output "Recording saved: $fileName"
    } else {
        Write-Host "`nError: Captured file is empty. The device may be in use." -ForegroundColor Red
    }
} else {
    Write-Host "`nError: FFmpeg process failed to create a file." -ForegroundColor Red
}
pause
