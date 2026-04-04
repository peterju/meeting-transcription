# step2_record-audio.ps1
# Record audio from microphone using FFmpeg

# Maintenance: This file uses English comments to avoid PowerShell 5.1 parser errors.

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
$audioConfig = $settings.audio

$ffmpegPath = Join-Path $scriptDir "FFmpeg\ffmpeg.exe"
if (-not (Test-Path "$ffmpegPath")) {
    Write-Host "Error: ffmpeg.exe not found at $ffmpegPath" -ForegroundColor Red
    pause; exit 1
}

# FIX: menu.cmd sets 'chcp 950' (Big5) before launching this script.
# We must override it with UTF-8 (65001) so that Chinese device names
# and menu text are displayed correctly in the console.
chcp 65001 | Out-Null
[Console]::InputEncoding  = [System.Text.UTF8Encoding]::new($false)
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)

# --- Robust Device Discovery ---
Write-Host "Searching for audio devices..." -ForegroundColor Gray

$raw = & "$ffmpegPath" -list_devices true -f dshow -i dummy 2>&1

$mics = @()
foreach ($line in $raw) {
    if ($line -match '"([^"]+)"\s*\(audio\)') {
        $mics += $Matches[1].Trim()
    }
}

if ($mics.Count -eq 0) {
    Write-Host "Error: No audio devices found!" -ForegroundColor Red
    pause; exit 1
}

# --- Menu Display ---
$defaultDevice = if ($audioConfig.PSObject.Properties.Name -contains "defaultDevice") { $audioConfig.defaultDevice } else { "" }
$defaultIndex = -1
if (-not [string]::IsNullOrEmpty($defaultDevice)) {
    for ($i = 0; $i -lt $mics.Count; $i++) {
        if ($mics[$i] -eq $defaultDevice) {
            $defaultIndex = $i + 1
            break
        }
    }
}

Write-Host "=========================================="
Write-Host "      Select Recording Device" -ForegroundColor Cyan
Write-Host "=========================================="
for ($i = 0; $i -lt $mics.Count; $i++) {
    $marker = ""
    if ($i + 1 -eq $defaultIndex) {
        $marker = " [DEFAULT]"
        Write-Host " [$($i+1)] : $($mics[$i])$marker" -ForegroundColor Yellow
    } else {
        Write-Host " [$($i+1)] : $($mics[$i])" -ForegroundColor Green
    }
}
Write-Host " [Enter] : Quit" -ForegroundColor Yellow
Write-Host "=========================================="

if ($defaultIndex -gt 0) {
    Write-Host ""
    Write-Host "Using default device: $defaultDevice" -ForegroundColor Gray
    Write-Host "Press Enter in 3 seconds to skip, or type a number to change." -ForegroundColor Gray
    Write-Host ""

    $skip = $false
    for ($countdown = 3; $countdown -gt 0; $countdown--) {
        Write-Host "  Starting in $countdown... " -NoNewline -ForegroundColor DarkGray
        Start-Sleep -Milliseconds 800
        # Check if user already typed something
        if ([Console]::KeyAvailable) {
            $key = [Console]::ReadKey($true)
            if ($key.Key -eq "Enter") {
                $skip = $false
                break
            } elseif ($key.KeyChar -match "\d") {
                $choice = $key.KeyChar.ToString()
                $skip = $true
                break
            }
        }
    }
    Write-Host ""

    if (-not $skip) {
        if ([string]::IsNullOrEmpty($choice)) {
            $choice = $defaultIndex.ToString()
        }
    }
}

if ([string]::IsNullOrEmpty($choice)) {
    $choice = Read-Host "Choice"
}
if ([string]::IsNullOrEmpty($choice)) { exit 0 }

# FIX: Always initialize $userVal before passing it as [ref] to TryParse.
# Without this, PowerShell reuses the stale value from a previous run in the
# same session, causing the wrong device to be selected.
$userVal = 0
if (-not [int]::TryParse($choice, [ref]$userVal) -or $userVal -lt 1 -or $userVal -gt $mics.Count) {
    Write-Host "Invalid choice." -ForegroundColor Red
    pause; exit 1
}

$selectedDevice = $mics[$userVal - 1]

# Save selected device as default
if ($selectedDevice -ne $defaultDevice) {
    $settings.audio.defaultDevice = $selectedDevice
    $jsonOut = $settings | ConvertTo-Json -Depth 10
    [System.IO.File]::WriteAllText($settingsPath, $jsonOut, [System.Text.Encoding]::UTF8)
    Write-Host "Device saved as default: $selectedDevice" -ForegroundColor Gray
    Write-Host ""
}

# Check available disk space (warn if less than 500 MB)
try {
    $driveLetter = (Split-Path $scriptDir -Qualifier).TrimEnd(':')
    $drive = (Get-PSDrive -Name $driveLetter -ErrorAction Stop)
    $freeMB = [math]::Round($drive.Free / 1MB, 0)
    $freeGB = [math]::Round($drive.Free / 1GB, 1)
    if ($freeMB -lt 500) {
        Write-Host "Warning: Only ${freeMB} MB ($([math]::Round($drive.Free / 1GB, 2)) GB) free on disk." -ForegroundColor Red
        Write-Host "Recording may fail due to insufficient space." -ForegroundColor Red
        $confirm = Read-Host "Continue anyway? [y/N]"
        if ($confirm -ne "y" -and $confirm -ne "Y") { exit 0 }
    } else {
        Write-Host "Disk space available: ${freeGB} GB" -ForegroundColor Gray
    }
} catch {
    Write-Host "Could not determine disk space." -ForegroundColor Yellow
}

# --- Level Test (Optional) ---
Write-Host ""
Write-Host "Would you like to run a quick level test first? (3 seconds)" -ForegroundColor Cyan
$doTest = Read-Host "Run level test? [Y/n]"

if ([string]::IsNullOrEmpty($doTest) -or $doTest -eq "Y" -or $doTest -eq "y") {
    Write-Host ""
    Write-Host "Testing microphone level (3 seconds)..." -ForegroundColor Yellow
    Write-Host "Please speak into the microphone now!" -ForegroundColor Red
    Write-Host ""

    $testFile = Join-Path $scriptDir "_level_test.wav"
    & "$ffmpegPath" -hide_banner -loglevel error -f dshow -t 3 -i "audio=$selectedDevice" -ar 16000 -ac 1 "$testFile"

    if (Test-Path "$testFile") {
        $testResult = & "$ffmpegPath" -hide_banner -i "$testFile" -af "volumedetect" -f null nul 2>&1
        $maxVol = $testResult | Where-Object { $_ -match "max_volume:\s*([-\d.]+)\s*dB" } | ForEach-Object { $Matches[1] }

        if ($null -ne $maxVol) {
            $maxVolNum = [double]$maxVol
            Write-Host "  Peak level: ${maxVol} dB" -ForegroundColor White

            if ($maxVolNum -lt -30) {
                Write-Host "  Status: TOO QUIET" -ForegroundColor Red
                Write-Host "  Suggestion: Move closer to mic or increase Windows mic gain." -ForegroundColor Yellow
            } elseif ($maxVolNum -lt -12) {
                Write-Host "  Status: GOOD" -ForegroundColor Green
                Write-Host "  Suggestion: Level is appropriate, ready to record." -ForegroundColor Green
            } elseif ($maxVolNum -lt -3) {
                Write-Host "  Status: STRONG" -ForegroundColor Cyan
                Write-Host "  Suggestion: Good level, watch for clipping." -ForegroundColor Yellow
            } else {
                Write-Host "  Status: CLIPPING RISK" -ForegroundColor Red
                Write-Host "  Suggestion: Reduce mic gain or move further away." -ForegroundColor Yellow
            }
        } else {
            Write-Host "  Could not detect audio level. The mic may be muted." -ForegroundColor Red
        }

        Remove-Item "$testFile" -Force -ErrorAction SilentlyContinue
    } else {
        Write-Host "  Level test failed. Check if the device is in use." -ForegroundColor Red
    }

    Write-Host ""
    Read-Host "Press Enter to continue to recording"
}

Clear-Host

$time = Get-Date -Format "MMdd_HHmm"
$fileName = "Record_$time.$($audioConfig.format)"
$filePath = Join-Path $scriptDir $fileName

# --- Start Recording ---
Clear-Host
Write-Host "------------------------------------------"
Write-Host " Selected Device: $selectedDevice" -ForegroundColor Yellow
Write-Host " Output File:     $fileName"
Write-Host " Press [Q] to stop recording" -ForegroundColor Red
Write-Host "------------------------------------------"

$ffmpegArgs = @("-hide_banner", "-loglevel", "warning", "-f", "dshow", "-i", "audio=$selectedDevice")

if ($audioConfig.format -eq "mp3") {
    $ffmpegArgs += @("-c:a", "libmp3lame", "-q:a", "$($audioConfig.mp3Quality)")
} else {
    $ffmpegArgs += @("-c:a", "aac", "-b:a", "$($audioConfig.m4aQuality)k")
}
$ffmpegArgs += @("-y", "$filePath")

# FIX: Use the call operator (&) with splatting (@ffmpegArgs) instead of
# Start-Process -ArgumentList. Start-Process joins the array with spaces and
# does not quote individual arguments, so device names containing spaces
# (e.g. "麥克風 (Logi C310 HD WebCam)") would be split and fail.
# Splatting passes each element as a separate argument, no quoting needed.
& "$ffmpegPath" @ffmpegArgs

Start-Sleep -Milliseconds 500

if (Test-Path "$filePath") {
    $size = (Get-Item "$filePath").Length
    if ($size -gt 1000) {
        Write-Host "`nSuccess! Saved to: $fileName" -ForegroundColor Green
        Write-Output "Recording saved: $fileName"
    } else {
        Write-Host "`nError: Captured file is empty. The device may be in use." -ForegroundColor Red
    }
} else {
    Write-Host "`nError: FFmpeg process failed to create a file." -ForegroundColor Red
}
pause
