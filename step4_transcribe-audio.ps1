# step4_transcribe-audio.ps1
# Audio transcription using WhisperPS

# Maintenance: This file uses English comments to avoid PowerShell 5.1 parser errors.
$OutputEncoding = [System.Text.UTF8Encoding]::new($false)

# Get script root
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
$transConfig = $settings.transcription

$whisperDir = Join-Path $scriptDir "WhisperDesktop"
$modelPath = Join-Path $whisperDir "ggml-medium.bin"

Write-Host "========================================"
Write-Host "  Step 4: Audio Transcription (Whisper)"
Write-Host "========================================"
Write-Host ""

if (-not (Test-Path "$modelPath")) {
    Write-Host "Error: Model file not found. Please run Step 1." -ForegroundColor Red
    Read-Host; exit 1
}

# Load Module
Write-Host "Loading WhisperPS module..." -ForegroundColor Gray
try {
    Import-Module WhisperPS -DisableNameChecking -ErrorAction Stop
} catch {
    Write-Host "Error: WhisperPS module not found." -ForegroundColor Red
    Read-Host; exit 1
}

# Load Model
Write-Host "Loading model (please wait)..." -ForegroundColor Cyan
try {
    $model = Import-WhisperModel "$modelPath"
    Write-Host "Model loaded success!" -ForegroundColor Green
} catch {
    Write-Host "Error loading model: $_" -ForegroundColor Red
    Read-Host; exit 1
}

# Search files
Write-Host ""
Write-Host "Searching for audio files..." -ForegroundColor Gray
# FIX: Use "$scriptDir\*" (not "$scriptDir") with -Include.
# When -Path points to a directory, PowerShell's -Include filter matches against
# the directory name itself and never reaches the files inside it.
# Appending \* makes -Include apply to the directory's contents as expected.
$audioFiles = @(Get-ChildItem -Path "$scriptDir\*" -Include *.mp3, *.wav, *.m4a, *.wma, *.ogg, *.flac -File | Where-Object {
    $_.Name -notmatch "^(WhisperDesktop|FFmpeg|temp)"
})

if ($audioFiles.Count -eq 0) {
    Write-Host "No audio files found." -ForegroundColor Yellow
    Read-Host; exit 0
}

Write-Host "Found $($audioFiles.Count) file(s):" -ForegroundColor Cyan
for ($i=0; $i -lt $audioFiles.Count; $i++) {
    Write-Host "  [$($i+1)] $($audioFiles[$i].Name)"
}
Write-Host ""

# Select
if ($audioFiles.Count -eq 1) {
    $filesToProcess = $audioFiles
    Write-Host "Auto-selecting: $($audioFiles[0].Name)" -ForegroundColor Cyan
} else {
    Write-Host "Enter number (or 'A' for all):"
    $selection = Read-Host "Choice"
    if ($selection -eq "A" -or $selection -eq "a") { $filesToProcess = $audioFiles }
    elseif ($selection -match "^\d+$") {
        $index = [int]$selection - 1
        if ($index -ge 0 -and $index -lt $audioFiles.Count) { $filesToProcess = @($audioFiles[$index]) }
        else { Write-Host "Invalid index."; Read-Host; exit 1 }
    } else { Write-Host "Invalid input."; Read-Host; exit 1 }
}

# Process
Write-Host ""
foreach ($file in $filesToProcess) {
    Write-Host "========================================"
    Write-Host "Processing: $($file.Name)" -ForegroundColor Yellow
    Write-Host "Language: $($transConfig.language)" -ForegroundColor Gray

    try {
        $result = Transcribe-File -model $model -path "$($file.FullName)" -language $transConfig.language -prompt $transConfig.prompt

        $txtPath = [System.IO.Path]::ChangeExtension($file.FullName, ".txt")
        $result | Export-Text -Path "$txtPath"
        Write-Host "Saved TXT: $(Split-Path $txtPath -Leaf)" -ForegroundColor Green

        $srtPath = [System.IO.Path]::ChangeExtension($file.FullName, ".srt")
        $result | Export-SubRip -Path "$srtPath"
        Write-Host "Saved SRT: $(Split-Path $srtPath -Leaf)" -ForegroundColor Green
    } catch {
        Write-Host "Error transcribing $($file.Name): $_" -ForegroundColor Red
    }
    Write-Host ""
}

Write-Host "Transcription completed!"
Read-Host "Press Enter to exit"
