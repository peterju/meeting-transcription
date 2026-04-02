# step1_download-dependencies.ps1
# Download required tools and models (skip if already exists)

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

$downloadDir = Join-Path $scriptDir "temp_download"
$ffmpegDir = Join-Path $scriptDir "FFmpeg"
$whisperDir = Join-Path $scriptDir "WhisperDesktop"

Write-Host "========================================"
Write-Host "  Step 1: Download Dependencies"
Write-Host "========================================"
Write-Host ""

function Test-DownloadNeeded {
    param([string]$path, [string]$name)
    if (Test-Path "$path") {
        Write-Host "[$name] Already exists, skipping..." -ForegroundColor Yellow
        return $false
    }
    return $true
}

$needsFFmpeg = Test-DownloadNeeded (Join-Path $ffmpegDir "ffmpeg.exe") "FFmpeg"
$needsWhisperDesktop = Test-DownloadNeeded (Join-Path $whisperDir "WhisperDesktop.exe") "WhisperDesktop"
$modelPath = Join-Path $whisperDir "ggml-medium.bin"
$needsModel = Test-DownloadNeeded $modelPath "Whisper Model"
$modulesDir = Join-Path $env:USERPROFILE "Documents\WindowsPowerShell\Modules"
$whisperPSDir = Join-Path $modulesDir "WhisperPS"
$needsWhisperPS = Test-DownloadNeeded $whisperPSDir "WhisperPS Module"

$arnndnModelName = "bd.rnnn"
$arnndnPath = Join-Path $ffmpegDir $arnndnModelName
$needsArnndn = Test-DownloadNeeded $arnndnPath "ARNNDN Model ($arnndnModelName)"

if (-not ($needsFFmpeg -or $needsWhisperDesktop -or $needsModel -or $needsWhisperPS -or $needsArnndn)) {
    Write-Host "All files ready. Done." -ForegroundColor Green
    Write-Host ""; Read-Host "Press Enter to exit"; exit 0
}

if (Test-Path "$downloadDir") {
    Remove-Item "$downloadDir" -Recurse -Force -ErrorAction SilentlyContinue
}
New-Item -ItemType Directory -Path "$downloadDir" -Force | Out-Null

# [1/4] FFmpeg
if ($needsFFmpeg) {
    Write-Host "[1/4] Resolving latest FFmpeg version..."

    # Get latest version string from GyanD
    try {
        $latestVer = curl.exe -sL "https://www.gyan.dev/ffmpeg/builds/release-version"
        $latestVer = $latestVer.Trim()
        Write-Host "Latest version identified: $latestVer" -ForegroundColor Gray

        # Build GitHub URL based on version and base URL in settings.json
        # Format: base_url + version + filename
        $ffmpegUrl = "$($settings.urls.ffmpegReleaseBase)$latestVer/ffmpeg-$latestVer-essentials_build.zip"
    } catch {
        Write-Host "Failed to resolve version, using fallback URL..." -ForegroundColor Yellow
        $ffmpegUrl = $settings.urls.ffmpegFallback
    }

    Write-Host "Downloading FFmpeg from GitHub for speed..."
    $ffmpegZip = Join-Path $downloadDir "ffmpeg.zip"
    curl.exe -L -o "$ffmpegZip" "$ffmpegUrl"

    if ($LASTEXITCODE -ne 0) {
        Write-Host "Download failed" -ForegroundColor Red
        Read-Host "Press Enter to exit"; exit 1
    }

    Write-Host "Extracting FFmpeg..."
    $ffmpegTemp = Join-Path $downloadDir "ffmpeg_temp"
    Expand-Archive -Path "$ffmpegZip" -DestinationPath "$ffmpegTemp" -Force

    if (-not (Test-Path "$ffmpegDir")) { New-Item -ItemType Directory -Path "$ffmpegDir" -Force | Out-Null }

    $binDir = Get-ChildItem -Path "$ffmpegTemp" -Recurse -Filter "bin" | Select-Object -First 1
    if ($binDir) {
        $srcFfmpeg = Join-Path $binDir.FullName "ffmpeg.exe"
        $srcFfplay = Join-Path $binDir.FullName "ffplay.exe"
        if (Test-Path "$srcFfmpeg") { Copy-Item "$srcFfmpeg" (Join-Path $ffmpegDir "ffmpeg.exe") -Force }
        if (Test-Path "$srcFfplay") { Copy-Item "$srcFfplay" (Join-Path $ffmpegDir "ffplay.exe") -Force }
        Write-Host "FFmpeg/FFplay installed" -ForegroundColor Green
    } else {
        Write-Host "Error: No bin folder in zip" -ForegroundColor Red
        Read-Host "Press Enter to exit"; exit 1
    }
}

# [2/4] WhisperDesktop
if ($needsWhisperDesktop) {
    Write-Host "[2/4] Downloading WhisperDesktop..."
    $whisperZip = Join-Path $downloadDir "whisper.zip"
    curl.exe -L -o "$whisperZip" "$($settings.urls.whisperDesktop)"
    if ($LASTEXITCODE -ne 0) { Write-Host "Download failed"; Read-Host; exit 1 }

    $whisperTemp = Join-Path $downloadDir "whisper_temp"
    Expand-Archive -Path "$whisperZip" -DestinationPath "$whisperTemp" -Force
    if (-not (Test-Path "$whisperDir")) { New-Item -ItemType Directory -Path "$whisperDir" -Force | Out-Null }
    Copy-Item "$whisperTemp\*" "$whisperDir" -Force
    Write-Host "WhisperDesktop installed" -ForegroundColor Green
}

# [3/4] Whisper model
if ($needsModel) {
    Write-Host "[3/4] Downloading Whisper model..."
    curl.exe -L -o "$modelPath" "$($settings.urls.whisperModel)"
    if ($LASTEXITCODE -ne 0) { Write-Host "Download failed"; Read-Host; exit 1 }
    Write-Host "Model downloaded" -ForegroundColor Green
}

# [4/4] WhisperPS module
if ($needsWhisperPS) {
    Write-Host "[4/4] Downloading WhisperPS module..."
    $whisperPSZip = Join-Path $downloadDir "WhisperPS.zip"
    curl.exe -L -o "$whisperPSZip" "$($settings.urls.whisperPS)"
    if ($LASTEXITCODE -ne 0) { Write-Host "Download failed"; Read-Host; exit 1 }

    $whisperPSTemp = Join-Path $downloadDir "WhisperPS_temp"
    Expand-Archive -Path "$whisperPSZip" -DestinationPath "$whisperPSTemp" -Force
    if (-not (Test-Path "$modulesDir")) { New-Item -ItemType Directory -Path "$modulesDir" -Force | Out-Null }
    if (Test-Path "$whisperPSDir") { Remove-Item "$whisperPSDir" -Recurse -Force }
    Copy-Item "$whisperPSTemp\WhisperPS" "$modulesDir" -Recurse -Force
    Write-Host "WhisperPS module installed" -ForegroundColor Green
}

# [5/5] ARNNDN model
if ($needsArnndn) {
    Write-Host "[5/5] Downloading ARNNDN model ($arnndnModelName)..."
    $arnndnUrl = $settings.urls.arnndnModel
    curl.exe -L -o "$arnndnPath" "$arnndnUrl"
    if ($LASTEXITCODE -ne 0) { Write-Host "Download failed"; Read-Host; exit 1 }
    Write-Host "ARNNDN model installed" -ForegroundColor Green
}

Write-Host "Cleaning up..."
Remove-Item "$downloadDir" -Recurse -Force -ErrorAction SilentlyContinue
Write-Host ""
Write-Host "========================================"
Write-Host "  Success! All files ready."
Write-Host "========================================"
Read-Host "Press Enter to exit"
