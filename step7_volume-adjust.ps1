# step7_volume-adjust.ps1
# Analyze audio volume and apply gain adjustment

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if ([string]::IsNullOrEmpty($scriptDir)) { $scriptDir = "." }

$ffmpegPath = Join-Path $scriptDir "FFmpeg\ffmpeg.exe"
if (-not (Test-Path "$ffmpegPath")) {
    Write-Host "Error: ffmpeg.exe not found. Please run Step 1." -ForegroundColor Red
    Read-Host; exit 1
}

chcp 65001 | Out-Null
[Console]::InputEncoding  = [System.Text.UTF8Encoding]::new($false)
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)

function Get-AudioFiles {
    $files = @(Get-ChildItem -Path "$scriptDir\*" -Include *.mp3, *.wav, *.m4a, *.wma, *.ogg, *.flac -File | Where-Object {
        $_.Name -notmatch "^(WhisperDesktop|FFmpeg|temp|_level_test)"
    })
    return $files
}

function Analyze-Volume {
    param([string]$filePath)
    $result = & "$ffmpegPath" -hide_banner -i "$filePath" -af "volumedetect" -f null nul 2>&1
    $maxVol = $result | Where-Object { $_ -match "max_volume:\s*([-\d.]+)\s*dB" } | ForEach-Object { $Matches[1] }
    $meanVol = $result | Where-Object { $_ -match "mean_volume:\s*([-\d.]+)\s*dB" } | ForEach-Object { $Matches[1] }
    return @{ MaxVolume = $maxVol; MeanVolume = $meanVol }
}

function Format-Status {
    param([double]$maxVol)
    if ($maxVol -lt -30) { return @{ Text = "TOO QUIET"; Color = "Red"; Suggestion = "Increase gain by +10~20 dB" } }
    elseif ($maxVol -lt -12) { return @{ Text = "GOOD"; Color = "Green"; Suggestion = "Volume is appropriate" } }
    elseif ($maxVol -lt -3) { return @{ Text = "STRONG"; Color = "Cyan"; Suggestion = "Watch for clipping" } }
    else { return @{ Text = "CLIPPING"; Color = "Red"; Suggestion = "Reduce gain" } }
}

# Main
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Volume Analysis & Adjustment" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$audioFiles = Get-AudioFiles
if ($audioFiles.Count -eq 0) {
    Write-Host "No audio files found." -ForegroundColor Yellow
    Read-Host; exit 0
}

Write-Host "Found $($audioFiles.Count) file(s):" -ForegroundColor Cyan
Write-Host ""

# Analyze all files
$analysisResults = @()
for ($i = 0; $i -lt $audioFiles.Count; $i++) {
    $f = $audioFiles[$i]
    $vol = Analyze-Volume $f.FullName
    $maxVolNum = if ($vol.MaxVolume) { [double]$vol.MaxVolume } else { 0 }
    $status = Format-Status $maxVolNum

    $analysisResults += @{
        Index = $i + 1
        File = $f
        MaxVolume = $vol.MaxVolume
        MeanVolume = $vol.MeanVolume
        Status = $status
    }

    Write-Host "  [$($i+1)] $($f.Name)" -ForegroundColor White
    Write-Host "       Max: $($vol.MaxVolume) dB | Mean: $($vol.MeanVolume) dB" -ForegroundColor DarkGray
    Write-Host "       Status: " -NoNewline -ForegroundColor DarkGray
    Write-Host "$($status.Text)" -ForegroundColor $status.Color
    Write-Host ""
}

Write-Host "  [Enter] Exit" -ForegroundColor Gray
Write-Host ""

$selection = Read-Host "Select file number to adjust volume"
if ([string]::IsNullOrEmpty($selection)) { exit 0 }

$userVal = 0
if (-not [int]::TryParse($selection, [ref]$userVal) -or $userVal -lt 1 -or $userVal -gt $audioFiles.Count) {
    Write-Host "Invalid selection." -ForegroundColor Red
    Read-Host; exit 1
}

$target = $analysisResults[$userVal - 1]
$selectedFile = $target.File

Write-Host ""
Write-Host "Selected: $($selectedFile.Name)" -ForegroundColor Yellow
Write-Host "Current max volume: $($target.MaxVolume) dB ($($target.Status.Text))" -ForegroundColor Gray
Write-Host ""

# Calculate suggested gain
$currentMax = [double]$target.MaxVolume
$suggestedGain = 0
if ($currentMax -lt -12) {
    $suggestedGain = [math]::Round(-12 - $currentMax, 1)
} elseif ($currentMax -gt -3) {
    $suggestedGain = [math]::Round(-3 - $currentMax, 1)
}

Write-Host "Suggested gain: ${suggestedGain} dB" -ForegroundColor Cyan
$gainInput = Read-Host "Enter gain in dB (positive=louder, negative=quieter, or Enter for suggested)"

if ([string]::IsNullOrEmpty($gainInput)) {
    $gain = $suggestedGain
} else {
    $gain = [double]$gainInput
}

$baseName = [System.IO.Path]::GetFileNameWithoutExtension($selectedFile.Name)
$ext = $selectedFile.Extension
$outputName = "${baseName}_vol${gain}dB${ext}"
$outputPath = Join-Path $scriptDir $outputName

Write-Host ""
Write-Host "Applying ${gain} dB gain..." -ForegroundColor Cyan
Write-Host "Output: $outputName" -ForegroundColor Gray
Write-Host ""

$ffmpegArgs = @("-i", $selectedFile.FullName, "-af", "volume=${gain}dB", "-y", "$outputPath")
& "$ffmpegPath" @ffmpegArgs 2>&1 | Out-Null

if (Test-Path $outputPath) {
    $size = (Get-Item $outputPath).Length
    if ($size -gt 1000) {
        # Verify new volume
        $newVol = Analyze-Volume $outputPath
        Write-Host "Saved: $outputName" -ForegroundColor Green
        Write-Host "New max volume: $($newVol.MaxVolume) dB" -ForegroundColor Gray
    } else {
        Write-Host "Error: Output file is empty." -ForegroundColor Red
        Remove-Item $outputPath -Force -ErrorAction SilentlyContinue
    }
} else {
    Write-Host "Error: FFmpeg process failed." -ForegroundColor Red
}

Write-Host ""
Read-Host "Press Enter to exit"
