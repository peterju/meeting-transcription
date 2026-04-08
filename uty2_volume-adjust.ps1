# uty2_volume-adjust.ps1
# Loudness normalization using EBU R128 two-pass loudnorm

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if ([string]::IsNullOrEmpty($scriptDir)) { $scriptDir = "." }

$ffmpegPath = Join-Path $scriptDir "FFmpeg\ffmpeg.exe"
if (-not (Test-Path "$ffmpegPath")) {
    Write-Host "Error: ffmpeg.exe not found. Please run Step 1." -ForegroundColor Red
    Read-Host; exit 1
}

chcp 65001 | Out-Null
[Console]::InputEncoding = [System.Text.UTF8Encoding]::new($false)
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)

$audioFiles = @(Get-ChildItem -Path "$scriptDir\*" -Include *.mp3, *.wav, *.m4a, *.wma, *.ogg, *.flac, *.mp4, *.mkv -File | Where-Object {
        $_.Name -notmatch "_norm\." -and $_.Name -notmatch "^(WhisperDesktop|FFmpeg|temp)"
    })

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Volume Normalization (EBU R128 loudnorm)" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

if ($audioFiles.Count -eq 0) {
    Write-Host "No audio files found." -ForegroundColor Yellow
    Read-Host; exit 0
}

Write-Host "Found $($audioFiles.Count) file(s):" -ForegroundColor Cyan
Write-Host ""

# Show volumedetect stats for each file
for ($i = 0; $i -lt $audioFiles.Count; $i++) {
    $f = $audioFiles[$i]
    $vd = & "$ffmpegPath" -hide_banner -i $f.FullName -vn -af "volumedetect" -f null nul 2>&1
    $mean = ($vd | Where-Object { $_ -match "mean_volume:\s*([-\d.]+)" } | ForEach-Object { $Matches[1] }) | Select-Object -First 1
    $max = ($vd | Where-Object { $_ -match "max_volume:\s*([-\d.]+)" }  | ForEach-Object { $Matches[1] }) | Select-Object -First 1
    Write-Host "  [$($i+1)] $($f.Name)" -ForegroundColor White
    Write-Host "       Mean: $mean dB  |  Max: $max dB" -ForegroundColor DarkGray
    Write-Host ""
}

Write-Host "  [Enter] Exit" -ForegroundColor Gray
$selection = Read-Host "Select file number"
if ([string]::IsNullOrEmpty($selection)) { exit 0 }

$userVal = 0
if (-not [int]::TryParse($selection, [ref]$userVal) -or $userVal -lt 1 -or $userVal -gt $audioFiles.Count) {
    Write-Host "Invalid selection." -ForegroundColor Red
    Read-Host; exit 1
}

$selectedFile = $audioFiles[$userVal - 1]
Write-Host ""
Write-Host "Selected: $($selectedFile.Name)" -ForegroundColor Yellow
Write-Host "Target:   -16 LUFS / True Peak -1.5 dBTP (EBU R128)" -ForegroundColor Gray
Write-Host ""

# Pass 1: analyze loudness and collect measured values
Write-Host "Pass 1: Analyzing loudness..." -ForegroundColor Cyan
$pass1 = & "$ffmpegPath" -hide_banner -vn -i $selectedFile.FullName `
    -af "loudnorm=I=-16:TP=-1.5:LRA=11:print_format=json" -f null nul 2>&1

# Extract JSON block from pass1 output
$jsonLines = @()
$inJson = $false
foreach ($line in $pass1) {
    if ($line -match "^\s*\{") { $inJson = $true }
    if ($inJson) { $jsonLines += $line }
    if ($line -match "^\s*\}") { $inJson = $false }
}

if ($jsonLines.Count -eq 0) {
    Write-Host "Error: Could not parse loudnorm analysis output." -ForegroundColor Red
    Read-Host; exit 1
}

$loud = ($jsonLines -join "`n") | ConvertFrom-Json
$measI = $loud.input_i
$measTP = $loud.input_tp
$measLRA = $loud.input_lra
$measThresh = $loud.input_thresh

$approxGain = [math]::Round(-16.0 - [double]$measI, 1)

Write-Host ""
Write-Host "  Integrated loudness: $measI LUFS  (target: -16.0)" -ForegroundColor White
Write-Host "  True Peak:           $measTP dBTP" -ForegroundColor Gray
Write-Host "  LRA:                 $measLRA LU" -ForegroundColor Gray
Write-Host "  Applied gain:        ~${approxGain} dB (linear)" -ForegroundColor Cyan
Write-Host ""

$baseName = [System.IO.Path]::GetFileNameWithoutExtension($selectedFile.Name)
$ext = $selectedFile.Extension
$outputName = "${baseName}_norm${ext}"
$outputPath = Join-Path $scriptDir $outputName

# Pass 2: apply normalization using measured values (linear=true for transparent gain)
Write-Host "Pass 2: Applying normalization..." -ForegroundColor Cyan
$af2 = "loudnorm=I=-16:TP=-1.5:LRA=11" +
":measured_I=${measI}:measured_TP=${measTP}" +
":measured_LRA=${measLRA}:measured_thresh=${measThresh}:linear=true"
$isVideo = $selectedFile.Extension -match '^\.(mp4|mkv)$'
if ($isVideo) {
    # Copy video stream, re-encode audio with loudnorm
    & "$ffmpegPath" -y -i $selectedFile.FullName `
        -map "0:v" -c:v copy -map "0:a" -af $af2 -c:a aac `
        $outputPath 2>&1 | Out-Null
}
else {
    & "$ffmpegPath" -y -i $selectedFile.FullName -af $af2 $outputPath 2>&1 | Out-Null
}

if ($LASTEXITCODE -ne 0 -or -not (Test-Path $outputPath)) {
    Write-Host "Error: Normalization failed." -ForegroundColor Red
    Read-Host; exit 1
}

# Verify output
$vd2 = & "$ffmpegPath" -hide_banner -i $outputPath -af "volumedetect" -f null nul 2>&1
$newMean = ($vd2 | Where-Object { $_ -match "mean_volume:\s*([-\d.]+)" } | ForEach-Object { $Matches[1] }) | Select-Object -First 1
$newMax = ($vd2 | Where-Object { $_ -match "max_volume:\s*([-\d.]+)" }  | ForEach-Object { $Matches[1] }) | Select-Object -First 1

Write-Host ""
Write-Host "Saved: $outputName" -ForegroundColor Green
Write-Host "  Mean volume: $newMean dB  |  Max volume: $newMax dB" -ForegroundColor Gray
Write-Host ""
Read-Host "Press Enter to exit"