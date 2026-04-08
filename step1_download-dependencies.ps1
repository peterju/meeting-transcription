# step1_download-dependencies.ps1
# Download required tools and models (skip if already exists)

# Maintenance: This file uses English comments to avoid PowerShell 5.1 parser errors.
$OutputEncoding = [System.Text.UTF8Encoding]::new($false)

# Get script root
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if ([string]::IsNullOrEmpty($scriptDir)) { $scriptDir = "." }

if (-not (Get-Command curl.exe -ErrorAction SilentlyContinue)) {
    Write-Host "Error: curl.exe not found. Please ensure curl is in your PATH." -ForegroundColor Red
    pause; exit 1
}

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
$needsWhisperCli = Test-DownloadNeeded (Join-Path $whisperDir "main.exe") "Whisper CLI (main.exe)"
$modelPath = Join-Path $whisperDir "ggml-medium.bin"
$needsModel = Test-DownloadNeeded $modelPath "Whisper Model"

$arnndnModelName = "bd.rnnn"
$arnndnPath = Join-Path $ffmpegDir $arnndnModelName
$needsArnndn = Test-DownloadNeeded $arnndnPath "ARNNDN Model ($arnndnModelName)"

if (-not ($needsFFmpeg -or $needsWhisperDesktop -or $needsWhisperCli -or $needsModel -or $needsArnndn)) {
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
    }
    catch {
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
    }
    else {
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

# [2.5] Whisper CLI (main.exe) - required by step5 for correct SRT timestamps
if ($needsWhisperCli) {
    Write-Host "[2.5] Downloading Whisper CLI (main.exe)..."
    $whisperCliZip = Join-Path $downloadDir "whisper_cli.zip"
    curl.exe -L -o "$whisperCliZip" "$($settings.urls.whisperCli)"
    if ($LASTEXITCODE -ne 0) { Write-Host "Download failed"; Read-Host; exit 1 }

    $cliTemp = Join-Path $downloadDir "cli_temp"
    Expand-Archive -Path "$whisperCliZip" -DestinationPath "$cliTemp" -Force
    if (-not (Test-Path "$whisperDir")) { New-Item -ItemType Directory -Path "$whisperDir" -Force | Out-Null }
    # Only copy main.exe; Whisper.dll is already provided by WhisperDesktop
    $mainExeSrc = Join-Path $cliTemp "main.exe"
    if (Test-Path $mainExeSrc) {
        Copy-Item $mainExeSrc (Join-Path $whisperDir "main.exe") -Force
        Write-Host "Whisper CLI (main.exe) installed" -ForegroundColor Green
    }
    else {
        Write-Host "Error: main.exe not found in cli.zip" -ForegroundColor Red
        Read-Host; exit 1
    }
}

# [3/4] Whisper model
if ($needsModel) {
    Write-Host "[3/4] Downloading Whisper model..."
    curl.exe -L -o "$modelPath" "$($settings.urls.whisperModel)"
    if ($LASTEXITCODE -ne 0) { Write-Host "Download failed"; Read-Host; exit 1 }
    Write-Host "Model downloaded" -ForegroundColor Green
}

# [4/4] ARNNDN model
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
