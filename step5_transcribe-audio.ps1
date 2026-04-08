# step5_transcribe-audio.ps1
# Audio transcription using Whisper CLI (main.exe)

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
$mainExePath = Join-Path $whisperDir "main.exe"
$modelPath = Join-Path $whisperDir "ggml-medium.bin"

Write-Host "======================================="
Write-Host "  Step 5: Audio Transcription (Whisper)"
Write-Host "======================================="
Write-Host ""

if (-not (Test-Path $mainExePath)) {
    Write-Host "Error: main.exe not found. Please run Step 1." -ForegroundColor Red
    Read-Host "Press Enter to exit"; exit 1
}

if (-not (Test-Path $modelPath)) {
    Write-Host "Error: Model file not found. Please run Step 1." -ForegroundColor Red
    Read-Host "Press Enter to exit"; exit 1
}

# Map settings.json language names to whisper CLI language codes
$langMap = @{
    "Chinese"    = "zh"
    "Japanese"   = "ja"
    "Korean"     = "ko"
    "English"    = "en"
    "French"     = "fr"
    "German"     = "de"
    "Spanish"    = "es"
    "Russian"    = "ru"
    "Portuguese" = "pt"
    "Italian"    = "it"
}
$langCode = if ($langMap.ContainsKey($transConfig.language)) { $langMap[$transConfig.language] } else { $transConfig.language }

# Search files
Write-Host ""
Write-Host "Searching for audio files..." -ForegroundColor Gray
# FIX: Use "$scriptDir\*" (not "$scriptDir") with -Include.
# When -Path points to a directory, PowerShell's -Include filter matches against
# the directory name itself and never reaches the files inside it.
# Appending \* makes -Include apply to the directory's contents as expected.
$audioFiles = @(Get-ChildItem -Path "$scriptDir\*" -Include *.mp3, *.wav, *.m4a, *.wma, *.ogg, *.flac, *.mp4 -File | Where-Object {
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

    # main.exe writes output files alongside the input file (PathCchRenameExtension).
    # -otxt: <name>.txt  -osrt: <name>.srt  -nc: suppress ANSI color codes
    # -nt: suppress timestamps in .txt (does not affect .srt, which always has timestamps)
    $cmdArgs = @(
        "-m", $modelPath,
        "-l", $langCode,
        "-otxt", "-osrt",
        "-nt", "-nc",
        "--prompt", $transConfig.prompt,
        "-f", $file.FullName
    )
    $cliOutput = & $mainExePath @cmdArgs 2>&1
    $cliExit = $LASTEXITCODE

    $elapsed = (Get-Date) - $startTime
    $elapsedStr = "{0:N0} min {1:N0} sec" -f $elapsed.TotalMinutes, $elapsed.Seconds

    if ($cliExit -ne 0) {
        Write-Host ""
        Write-Host "  Transcription failed (exit $cliExit):" -ForegroundColor Red
        $cliOutput | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
    }
    else {
        Write-Host ""
        Write-Host "  Completed in $elapsedStr" -ForegroundColor Green

        $txtPath = [System.IO.Path]::ChangeExtension($file.FullName, ".txt")
        $srtPath = [System.IO.Path]::ChangeExtension($file.FullName, ".srt")

        if (Test-Path $txtPath) {
            Write-Host "  Saved TXT: $(Split-Path $txtPath -Leaf)" -ForegroundColor Green
        }
        if (Test-Path $srtPath) {
            Write-Host "  Saved SRT: $(Split-Path $srtPath -Leaf)" -ForegroundColor Green
        }
    }
    Write-Host ""
}

Write-Host "Transcription completed!"
Read-Host "Press Enter to exit"
