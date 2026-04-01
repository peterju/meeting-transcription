# step1_download-dependencies.ps1
# Download all required tools and models (skip if already exists)

chcp 65001 > $null

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$downloadDir = Join-Path $scriptDir "temp_download"
$ffmpegDir = Join-Path $scriptDir "FFmpeg"
$whisperDir = Join-Path $scriptDir "WhisperDesktop"

Write-Host "========================================"
Write-Host "  Download Required Files"
Write-Host "========================================"
Write-Host ""

# Function to check if file exists
function Test-DownloadNeeded {
    param([string]$path, [string]$name)
    if (Test-Path $path) {
        Write-Host "[$name] Already exists, skipping..." -ForegroundColor Yellow
        return $false
    }
    return $true
}

# Check what needs to be downloaded
$needsFFmpeg = Test-DownloadNeeded (Join-Path $ffmpegDir "ffmpeg.exe") "FFmpeg"
$needsWhisperDesktop = Test-DownloadNeeded (Join-Path $whisperDir "WhisperDesktop.exe") "WhisperDesktop"
$modelPath = Join-Path $whisperDir "ggml-medium.bin"
$needsModel = Test-DownloadNeeded $modelPath "Whisper model"
$modulesDir = Join-Path $env:USERPROFILE "Documents\WindowsPowerShell\Modules"
$whisperPSDir = Join-Path $modulesDir "WhisperPS"
$needsWhisperPS = Test-DownloadNeeded $whisperPSDir "WhisperPS module"

# If nothing needs to be downloaded, exit early
if (-not ($needsFFmpeg -or $needsWhisperDesktop -or $needsModel -or $needsWhisperPS)) {
    Write-Host "All files already exist. Nothing to download." -ForegroundColor Green
    Write-Host ""
    Read-Host "Press Enter to exit"
    exit 0
}

# Create temp directory
if (Test-Path $downloadDir) {
    Remove-Item $downloadDir -Recurse -Force
}
New-Item -ItemType Directory -Path $downloadDir -Force | Out-Null

# [1/4] FFmpeg
if ($needsFFmpeg) {
    Write-Host "[1/4] Downloading FFmpeg..."
    $ffmpegZip = Join-Path $downloadDir "ffmpeg.zip"
    curl.exe -L -o $ffmpegZip "https://github.com/GyanD/codexffmpeg/releases/download/8.1/ffmpeg-8.1-essentials_build.zip"
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "FFmpeg download failed" -ForegroundColor Red
        Read-Host
        exit 1
    }
    
    Write-Host "Extracting FFmpeg..."
    $ffmpegTemp = Join-Path $downloadDir "ffmpeg_temp"
    Expand-Archive -Path $ffmpegZip -DestinationPath $ffmpegTemp -Force
    
    if (-not (Test-Path $ffmpegDir)) {
        New-Item -ItemType Directory -Path $ffmpegDir -Force | Out-Null
    }
    
    $srcExe = Join-Path $ffmpegTemp "ffmpeg-8.1-essentials_build\bin\ffmpeg.exe"
    $dstExe = Join-Path $ffmpegDir "ffmpeg.exe"
    Copy-Item $srcExe $dstExe -Force
    Write-Host "FFmpeg done" -ForegroundColor Green
    Write-Host ""
}

# [2/4] WhisperDesktop
if ($needsWhisperDesktop) {
    Write-Host "[2/4] Downloading WhisperDesktop..."
    $whisperZip = Join-Path $downloadDir "whisper.zip"
    curl.exe -L -o $whisperZip "https://github.com/Const-me/Whisper/releases/download/1.12.0/WhisperDesktop.zip"
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "WhisperDesktop download failed" -ForegroundColor Red
        Read-Host
        exit 1
    }
    
    Write-Host "Extracting WhisperDesktop..."
    $whisperTemp = Join-Path $downloadDir "whisper_temp"
    Expand-Archive -Path $whisperZip -DestinationPath $whisperTemp -Force
    
    if (-not (Test-Path $whisperDir)) {
        New-Item -ItemType Directory -Path $whisperDir -Force | Out-Null
    }
    
    Copy-Item "$whisperTemp\*" $whisperDir -Force
    Write-Host "WhisperDesktop done" -ForegroundColor Green
    Write-Host ""
}

# [3/4] Whisper model
if ($needsModel) {
    Write-Host "[3/4] Downloading Whisper model (ggml-medium.bin)..."
    curl.exe -L -o $modelPath "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-medium.bin"
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Model download failed" -ForegroundColor Red
        Read-Host
        exit 1
    }
    
    Write-Host "Model done" -ForegroundColor Green
    Write-Host ""
}

# [4/4] WhisperPS module
if ($needsWhisperPS) {
    Write-Host "[4/4] Downloading WhisperPS module..."
    $whisperPSZip = Join-Path $downloadDir "WhisperPS.zip"
    curl.exe -L -o $whisperPSZip "https://github.com/Const-me/Whisper/releases/download/1.12.0/WhisperPS.zip"
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "WhisperPS download failed" -ForegroundColor Red
        Read-Host
        exit 1
    }
    
    Write-Host "Installing WhisperPS module..."
    $whisperPSTemp = Join-Path $downloadDir "WhisperPS_temp"
    Expand-Archive -Path $whisperPSZip -DestinationPath $whisperPSTemp -Force
    
    if (-not (Test-Path $modulesDir)) {
        New-Item -ItemType Directory -Path $modulesDir -Force | Out-Null
    }
    
    if (Test-Path $whisperPSDir) {
        Remove-Item $whisperPSDir -Recurse -Force
    }
    Copy-Item $whisperPSTemp\WhisperPS $modulesDir -Recurse -Force
    Write-Host "WhisperPS module installed" -ForegroundColor Green
    Write-Host ""
}

Write-Host "Cleaning up temporary files..."
Remove-Item $downloadDir -Recurse -Force -ErrorAction SilentlyContinue
Write-Host ""

Write-Host "========================================"
Write-Host "  All required files ready!"
Write-Host "========================================"

Read-Host "Press Enter to exit"
