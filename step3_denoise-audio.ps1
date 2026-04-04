# step3_denoise-audio.ps1
# Audio post-processing: apply noise reduction filters

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if ([string]::IsNullOrEmpty($scriptDir)) { $scriptDir = "." }

$settingsPath = Join-Path $scriptDir "settings.json"
if (-not (Test-Path "$settingsPath")) {
    Write-Host "Error: settings.json not found." -ForegroundColor Red
    pause; exit 1
}

$jsonStr = [System.IO.File]::ReadAllText($settingsPath, [System.Text.Encoding]::UTF8)
$settings = $jsonStr | ConvertFrom-Json

$ffmpegPath = Join-Path $scriptDir "FFmpeg\ffmpeg.exe"
if (-not (Test-Path "$ffmpegPath")) {
    Write-Host "Error: ffmpeg.exe not found at $ffmpegPath" -ForegroundColor Red
    pause; exit 1
}

chcp 65001 | Out-Null
[Console]::InputEncoding  = [System.Text.UTF8Encoding]::new($false)
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)

$recordConfig = $settings.record
$profiles = $recordConfig.profiles
$activeProfileName = $recordConfig.activeProfile

Write-Host "========================================"
Write-Host "  Audio Post-Processing (Noise Reduction)" -ForegroundColor Cyan
Write-Host "========================================"
Write-Host ""

$profile = $profiles.$activeProfileName

if ($null -eq $profile) {
    Write-Host "Warning: Profile '$activeProfileName' not found in settings.json." -ForegroundColor Yellow
    Write-Host "Using top-level settings as fallback." -ForegroundColor Yellow
    Write-Host ""
    $useArnndn = $false
    $gateValue = $recordConfig.gate
    $lowpassValue = $recordConfig.lowpass
    $hipassValue = $recordConfig.hipass
    $profileName = "(default)"
} else {
    $useArnndn = $profile.arnndn.enabled
    $modelFile = $profile.arnndn.model
    $gateValue = if ($null -ne $profile.gate) { $profile.gate } else { $recordConfig.gate }
    $lowpassValue = if ($null -ne $profile.lowpass) { $profile.lowpass } else { $recordConfig.lowpass }
    $hipassValue = if ($null -ne $profile.hipass) { $profile.hipass } else { $recordConfig.hipass }
    $profileName = $profile.name
}

Write-Host "Current profile: $profileName" -ForegroundColor Yellow
Write-Host ""

$audioFiles = @()
$allFiles = Get-ChildItem -Path $scriptDir -File
foreach ($f in $allFiles) {
    $ext = $f.Extension.ToLower()
    if ($ext -match '\.(mp3|wav|m4a|wma|ogg|flac)$' -and $f.Name -notmatch '^(WhisperDesktop|FFmpeg|temp|test|.*_denoised)') {
        $audioFiles += $f
    }
}

if ($audioFiles.Count -eq 0) {
    Write-Host "No audio files found." -ForegroundColor Yellow
    Write-Host "Please record audio first using Step 2." -ForegroundColor Yellow
    pause; exit 0
}

Write-Host "Found $($audioFiles.Count) audio file(s):" -ForegroundColor Cyan
for ($i = 0; $i -lt $audioFiles.Count; $i++) {
    Write-Host "  [$($i+1)] $($audioFiles[$i].Name)"
}
Write-Host ""
Write-Host "  [A] Process all files"
Write-Host "  [Enter] Quit"
Write-Host ""

$selection = Read-Host "Select file number or [A]"
if ([string]::IsNullOrEmpty($selection)) { exit 0 }

$filesToProcess = @()
if ($selection -eq "A" -or $selection -eq "a") {
    $filesToProcess = $audioFiles
} elseif ($selection -match "^\d+$") {
    $idx = [int]$selection - 1
    if ($idx -ge 0 -and $idx -lt $audioFiles.Count) {
        $filesToProcess = @($audioFiles[$idx])
    } else {
        Write-Host "Invalid selection." -ForegroundColor Red
        pause; exit 1
    }
} else {
    Write-Host "Invalid selection." -ForegroundColor Red
    pause; exit 1
}

Write-Host ""
Write-Host "Active settings:" -ForegroundColor Green
Write-Host "  ARNNDN: $(if ($useArnndn) { 'Enabled' } else { 'Disabled' })"
Write-Host "  Gate: $gateValue dB"
Write-Host "  Lowpass: $lowpassValue Hz"
Write-Host "  Hipass: $hipassValue Hz"
Write-Host ""

$hasArnndnModel = $false
if ($useArnndn) {
    $modelFile = if ($null -ne $profile.arnndn.model) { $profile.arnndn.model } else { "bd.rnnn" }
    $arnndnPath = Join-Path $scriptDir "FFmpeg\$modelFile"
    $hasArnndnModel = Test-Path $arnndnPath
}

if ($useArnndn -and -not $hasArnndnModel) {
    Write-Host "Warning: ARNNDN model file not found at $arnndnPath" -ForegroundColor Yellow
    Write-Host "Will process without ARNNDN." -ForegroundColor Yellow
    $useArnndn = $false
}

$audioFilters = @()

if ($useArnndn -and $hasArnndnModel) {
    $arnndnRelPath = ".\FFmpeg\$modelFile" -replace '\\', '/'
    $audioFilters += "arnndn=m=$arnndnRelPath"
}

if ($gateValue -ne 0) {
    $audioFilters += "agate=threshold=${gateValue}dB"
}

if ($lowpassValue -gt 0) {
    $audioFilters += "lowpass=f=$lowpassValue"
}

if ($hipassValue -gt 0) {
    $audioFilters += "highpass=f=$hipassValue"
}

$afString = ($audioFilters -join ",")

if ([string]::IsNullOrEmpty($afString)) {
    Write-Host "No filters configured. Nothing to do." -ForegroundColor Yellow
    pause; exit 0
}

Write-Host "Filter string: $afString" -ForegroundColor Gray
Write-Host ""
Write-Host "Processing..." -ForegroundColor Cyan
Write-Host ""

function Test-AudioContent {
    param([string]$filePath)
    $result = & "$ffmpegPath" -hide_banner -i "$filePath" -af "volumedetect" -f null nul 2>&1
    $maxVol = $result | Where-Object { $_ -match "max_volume:\s*([-\d.]+)\s*dB" } | ForEach-Object { $Matches[1] }
    if ($null -ne $maxVol -and [double]$maxVol -gt -60) {
        return @{ Valid = $true; MaxVolume = $maxVol }
    }
    return @{ Valid = $false; MaxVolume = $null }
}

foreach ($file in $filesToProcess) {
    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
    $ext = $file.Extension
    $outputName = "${baseName}_denoised${ext}"
    $outputPath = Join-Path $scriptDir $outputName

    Write-Host "Processing: $($file.Name) -> $outputName"

    $ffmpegArgs = @("-i", $file.FullName, "-af", $afString, "-y", "$outputPath")
    & "$ffmpegPath" @ffmpegArgs 2>&1 | Out-Null

    if ($LASTEXITCODE -ne 0) {
        Write-Host "  Error: FFmpeg exited with code $LASTEXITCODE." -ForegroundColor Red
        if (Test-Path $outputPath) { Remove-Item $outputPath -Force -ErrorAction SilentlyContinue }
    } elseif (Test-Path $outputPath) {
        $audioCheck = Test-AudioContent $outputPath
        if ($audioCheck.Valid) {
            Write-Host "  Saved: $outputName (max volume: $($audioCheck.MaxVolume) dB)" -ForegroundColor Green
        } else {
            Write-Host "  Error: Output file has no audio content." -ForegroundColor Red
            Remove-Item $outputPath -Force
        }
    } else {
        Write-Host "  Error: Output file not created." -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "========================================"
Write-Host "  Post-processing completed!"
Write-Host "========================================"
pause