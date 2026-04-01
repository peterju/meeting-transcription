# step3_transcribe-audio.ps1
# Audio transcription using WhisperPS

chcp 65001 > $null

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$whisperDir = Join-Path $scriptDir "WhisperDesktop"
$modelPath = Join-Path $whisperDir "ggml-medium.bin"

# ============================================================
# Transcription Configuration
# ============================================================
$prompt = "This is a meeting recording. Please transcribe in Traditional Chinese."

Write-Host "========================================"
Write-Host "  Audio Transcription (WhisperPS)"
Write-Host "========================================"
Write-Host ""

# Check model exists
if (-not (Test-Path $modelPath)) {
    Write-Host "Error: Model not found. Please run Step 1 first." -ForegroundColor Red
    Read-Host
    exit 1
}

# Load WhisperPS module
Write-Host "Loading WhisperPS module..."
try {
    Import-Module WhisperPS -DisableNameChecking -ErrorAction Stop
} catch {
    Write-Host "Error: WhisperPS module not found. Please run Step 1 first." -ForegroundColor Red
    Write-Host "If problem persists, run PowerShell as Administrator:" -ForegroundColor Yellow
    Write-Host "  Install-Module -Name WhisperPS -Scope CurrentUser" -ForegroundColor Yellow
    Read-Host
    exit 1
}

# Load Whisper model
Write-Host "Loading Whisper model (this may take a while)..."
try {
    $model = Import-WhisperModel $modelPath
    Write-Host "Model loaded successfully" -ForegroundColor Green
} catch {
    Write-Host "Error loading model: $_" -ForegroundColor Red
    Read-Host
    exit 1
}

# Find audio files
Write-Host ""
Write-Host "Searching for audio files..."
$audioFiles = @(Get-ChildItem -Path $scriptDir -Include *.mp3, *.wav, *.m4a, *.wma, *.ogg, *.flac -Recurse | Where-Object { $_.Name -notmatch "^(WhisperDesktop|FFmpeg|temp)" -and $_.DirectoryName -notmatch "(WhisperDesktop|FFmpeg|temp)" })

if ($audioFiles.Count -eq 0) {
    Write-Host "No audio files found. Please record audio first using Step 2." -ForegroundColor Yellow
    Read-Host
    exit 0
}

Write-Host "Found $($audioFiles.Count) audio file(s):" -ForegroundColor Cyan
Write-Host ""
$count = 1
foreach ($file in $audioFiles) {
    Write-Host "  [$count] $($file.Name)"
    $count++
}
Write-Host ""
if ($audioFiles.Count -eq 1) {
    $filesToProcess = $audioFiles
    Write-Host "Auto-selected: $($audioFiles[0].Name)" -ForegroundColor Cyan
} else {
    Write-Host "Enter file number to transcribe (or 'A' for all):"
    $selection = Read-Host "Your choice"
    
    if ($selection -eq "A" -or $selection -eq "a") {
        $filesToProcess = $audioFiles
    } elseif ($selection -match "^\d+$") {
        $index = [int]$selection - 1
        if ($index -ge 0 -and $index -lt $audioFiles.Count) {
            $filesToProcess = @($audioFiles[$index])
        } else {
            Write-Host "Invalid selection." -ForegroundColor Red
            Read-Host
            exit 1
        }
    } else {
        Write-Host "Invalid selection." -ForegroundColor Red
        Read-Host
        exit 1
    }
}

# Transcribe files
Write-Host ""

foreach ($file in $filesToProcess) {
    Write-Host "Transcribing: $($file.Name)..."
    try {
Write-Host "Using prompt: $prompt" -ForegroundColor Cyan
        $result = Transcribe-File -model $model -path $file.FullName -language Chinese
        
        $txtPath = [System.IO.Path]::ChangeExtension($file.FullName, ".txt")
        $result | Export-Text -Path $txtPath
        Write-Host "Saved: $txtPath" -ForegroundColor Green
        
        $srtPath = [System.IO.Path]::ChangeExtension($file.FullName, ".srt")
        $result | Export-SubRip -Path $srtPath
        Write-Host "Saved: $srtPath" -ForegroundColor Green
        
    } catch {
        Write-Host "Error transcribing $($file.Name): $_" -ForegroundColor Red
    }
    Write-Host ""
}

Write-Host "========================================"
Write-Host "  Transcription completed!"
Write-Host "========================================"
Write-Host ""

Read-Host "Press Enter to exit"