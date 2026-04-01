# step2_record-audio.ps1
# Record audio from microphone to MP3 file

# ============================================================
# Audio Configuration (adjust these values as needed)
# ============================================================
$audioConfig = @{
    # Output format: "mp3" or "m4a"
    format = "mp3"
    
    # High-pass filter: removes frequencies below this value (rumble/hum)
    # Set to 0 to disable
    highpass = 100
    
    # Low-pass filter: removes frequencies above this value (hiss)
    # Set to 0 to disable
    lowpass = 5000
    
    # Noise reduction strength: -50 (strongest) to 0 (disabled)
    # Recommended: -30 for light, -25 for moderate
    noiseReduction = -25
    
    # MP3 quality: 0 (best) to 9 (smallest file)
    # Recommended: 2-4 for voice recording
    mp3Quality = 4
    
    # M4A (AAC) quality: 0 (best) to 500 (worst), 128-192 typical
    m4aQuality = 128
}
# ============================================================

chcp 65001 | Out-Null
[Console]::InputEncoding = [System.Text.UTF8Encoding]::new($false)
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)

# Build audio filter string based on configuration
$audioFilters = @()
if ($audioConfig.highpass -gt 0) {
    $audioFilters += "highpass=f=$($audioConfig.highpass)"
}
if ($audioConfig.lowpass -gt 0) {
    $audioFilters += "lowpass=f=$($audioConfig.lowpass)"
}
if ($audioConfig.noiseReduction -ne 0 -and $audioConfig.noiseReduction -lt 0) {
    $audioFilters += "afftdn=nf=$($audioConfig.noiseReduction)"
}
$afString = ($audioFilters -join ",")

# List available audio devices
$raw = .\FFmpeg\ffmpeg -list_devices true -f dshow -i dummy 2>&1

# Parse device list
$mics = @()
foreach ($line in $raw) {
    if ($line -match '"([^"]+)"\s*\(audio\)') {
        $mics += $Matches[1].Trim()
    }
}

# Show menu
Write-Host "=========================================="
Write-Host "      Select Recording Device" -ForegroundColor Cyan
Write-Host "=========================================="
if ($mics.Count -eq 0) {
    Write-Host "Error: No recording device found!" -ForegroundColor Red
    pause
    exit
}

$count = 1
foreach ($m in $mics) {
    Write-Host " [$count] : $m" -ForegroundColor Green
    $count++
}
Write-Host " [Q] : Quit" -ForegroundColor Yellow
Write-Host "=========================================="

$choice = Read-Host "Your choice"
if ($choice -eq "q" -or $choice -eq "Q") {
    exit
}

# Convert to integer and validate
$val = [int]$choice
if ($val -lt 1 -or $val -gt $mics.Count) {
    Write-Host "Invalid selection, exiting." -ForegroundColor Red
    pause
    exit
}

# Get the selected device - array is 0-indexed, menu is 1-indexed
$selectedIndex = $val - 1
$selected = $mics[$selectedIndex]

# Set output filename based on format
$time = Get-Date -Format "MMdd_HHmm"
$extension = $audioConfig.format
$file = "Record_$time.$extension"

# Start recording
Clear-Host
Write-Host "------------------------------------------"
Write-Host " Recording: $selected" -ForegroundColor Yellow
Write-Host "Filename: $file"
Write-Host " Press [Q] to stop recording" -ForegroundColor Red
Write-Host "------------------------------------------"

# Run FFmpeg with configured audio filters
$ErrorActionPreference = "Continue"
$ffmpegCmd = ".\FFmpeg\ffmpeg -f dshow -i audio=""$selected"""
if ($afString) {
    $ffmpegCmd += " -af ""$afString"""
}

# Handle different output formats
if ($audioConfig.format -eq "mp3") {
    $ffmpegCmd += " -c:a libmp3lame -q:a $($audioConfig.mp3Quality) -y ""$file"" -loglevel quiet"
} elseif ($audioConfig.format -eq "m4a") {
    $ffmpegCmd += " -c:a aac -b:a $($audioConfig.m4aQuality)k -y ""$file"" -loglevel quiet"
}

Invoke-Expression $ffmpegCmd

# Check if recording was successful
if ($LASTEXITCODE -ne 0) {
    Write-Host "Recording failed with error code: $LASTEXITCODE" -ForegroundColor Red
    pause
    exit
}

# Check file size to ensure audio was captured
$fileSize = (Get-Item $file).Length
if ($fileSize -lt 1000) {
    Write-Host "Warning: Recording file is very small ($fileSize bytes). No audio may have been captured." -ForegroundColor Yellow
}

Write-Host "`nRecording saved: $file" -ForegroundColor Green
pause
