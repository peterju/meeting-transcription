# step5_transcribe-audio.ps1
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
$whisperExePath = Join-Path $whisperDir "WhisperDesktop.exe"
$modelPath = Join-Path $whisperDir "ggml-medium.bin"

Write-Host "========================================"
Write-Host "  Step 4: Audio Transcription (Whisper)"
Write-Host "========================================"
Write-Host ""

if (-not (Test-Path "$whisperExePath")) {
    Write-Host "Error: WhisperDesktop.exe not found. Please run Step 1." -ForegroundColor Red
    Read-Host "Press Enter to exit"; exit 1
}

if (-not (Test-Path "$modelPath")) {
    Write-Host "Error: Model file not found. Please run Step 1." -ForegroundColor Red
    Read-Host "Press Enter to exit"; exit 1
}

# Load Module
Write-Host "Loading WhisperPS module..." -ForegroundColor Gray
$userModulesPath = Join-Path $env:USERPROFILE "Documents\WindowsPowerShell\Modules"
$whisperPSModulePath = Join-Path $userModulesPath "WhisperPS"
if (Test-Path $whisperPSModulePath) {
    Import-Module $whisperPSModulePath -DisableNameChecking -ErrorAction Stop
}
else {
    try {
        Import-Module WhisperPS -DisableNameChecking -ErrorAction Stop
    }
    catch {
        Write-Host "Error: WhisperPS module not found." -ForegroundColor Red
        Write-Host "Please run Step 1 to install the module." -ForegroundColor Yellow
        Read-Host; exit 1
    }
}

# Load Model
Write-Host "Loading model (please wait)..." -ForegroundColor Cyan
try {
    $model = Import-WhisperModel "$modelPath"
    Write-Host "Model loaded success!" -ForegroundColor Green
}
catch {
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
for ($i = 0; $i -lt $audioFiles.Count; $i++) {
    Write-Host "  [$($i+1)] $($audioFiles[$i].Name)"
}
Write-Host "  [Enter] Quit" -ForegroundColor Yellow
Write-Host ""

# Select
Write-Host "Enter number (or 'A' for all):"
$selection = Read-Host "Choice"
if ([string]::IsNullOrEmpty($selection)) { exit 0 }
elseif ($selection -eq "A" -or $selection -eq "a") { $filesToProcess = $audioFiles }
elseif ($selection -match "^\d+$") {
    $index = [int]$selection - 1
    if ($index -ge 0 -and $index -lt $audioFiles.Count) { $filesToProcess = @($audioFiles[$index]) }
    else { Write-Host "Invalid index."; Read-Host; exit 1 }
}
else { Write-Host "Invalid input."; Read-Host; exit 1 }

# Process
Write-Host ""
$totalFiles = $filesToProcess.Count
$currentFile = 0

foreach ($file in $filesToProcess) {
    $currentFile++
    Write-Host "========================================"
    Write-Host "  File [$currentFile / $totalFiles]: $($file.Name)" -ForegroundColor Yellow
    Write-Host "  Language: $($transConfig.language)" -ForegroundColor Gray
    Write-Host "========================================"
    Write-Host ""

    # Show estimated duration
    $ffmpegPath = Join-Path $scriptDir "FFmpeg\ffmpeg.exe"
    if (Test-Path $ffmpegPath) {
        $probeResult = & "$ffmpegPath" -i "$($file.FullName)" 2>&1
        $durMatch = $probeResult | Where-Object { $_ -match "Duration:\s*(\d{2}):(\d{2}):(\d{2})" }
        if ($durMatch) {
            $hh = [int]$Matches[1]; $mm = [int]$Matches[2]; $ss = [int]$Matches[3]
            $totalSecs = $hh * 3600 + $mm * 60 + $ss
            $estMins = [math]::Ceiling($totalSecs / 60)
            Write-Host "  Audio duration: $([string]::Format('{0:D2}:{1:D2}:{2:D2}', $hh, $mm, $ss))" -ForegroundColor Gray
            Write-Host "  Est. transcription time: ~${estMins} min (CPU, medium model)" -ForegroundColor Gray
            Write-Host ""
        }
    }

    Write-Host "  Transcribing... (this may take a while)" -ForegroundColor Cyan
    $startTime = Get-Date

    try {
        $result = Transcribe-File -model $model -path "$($file.FullName)" -language $transConfig.language -prompt $transConfig.prompt

        $elapsed = (Get-Date) - $startTime
        $elapsedStr = "{0:N0} min {1:N0} sec" -f $elapsed.TotalMinutes, $elapsed.Seconds

        Write-Host ""
        Write-Host "  Completed in $elapsedStr" -ForegroundColor Green

        $txtPath = [System.IO.Path]::ChangeExtension($file.FullName, ".txt")
        $result | Export-Text -Path "$txtPath"
        Write-Host "  Saved TXT: $(Split-Path $txtPath -Leaf)" -ForegroundColor Green

        $srtPath = [System.IO.Path]::ChangeExtension($file.FullName, ".srt")
        $result | Export-SubRip -Path "$srtPath"
        Write-Host "  Saved SRT: $(Split-Path $srtPath -Leaf)" -ForegroundColor Green
    }
    catch {
        Write-Host "  Error transcribing $($file.Name): $_" -ForegroundColor Red
    }
    Write-Host ""
}

Write-Host "Transcription completed!"
Read-Host "Press Enter to exit"
