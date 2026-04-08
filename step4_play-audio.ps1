# step4_play-audio.ps1
# Select an audio file and play it using ffplay

# Maintenance: This file uses English comments to avoid PowerShell 5.1 parser errors.
$OutputEncoding = [System.Text.UTF8Encoding]::new($false)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if ([string]::IsNullOrEmpty($scriptDir)) { $scriptDir = "." }

chcp 65001 | Out-Null
[Console]::InputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$ffplayPath = Join-Path $scriptDir "FFmpeg\ffplay.exe"
if (-not (Test-Path "$ffplayPath")) {
    Write-Host "Error: ffplay.exe not found. Please run Step 1." -ForegroundColor Red
    Read-Host "Press Enter to exit"; exit 1
}

# Search audio
Write-Host "Searching for audio files..." -ForegroundColor Gray
# FIX: Use "$scriptDir\*" (not "$scriptDir") with -Include.
# When -Path points to a directory, PowerShell's -Include filter matches against
# the directory name itself and never reaches the files inside it.
# Appending \* makes -Include apply to the directory's contents as expected.
$audioFiles = @(Get-ChildItem -Path "$scriptDir\*" -Include *.mp3, *.wav, *.m4a, *.wma, *.ogg, *.flac -File | Where-Object {
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

Write-Host "Enter index to play:"
$selection = Read-Host "Choice"

if ([string]::IsNullOrEmpty($selection)) { exit 0 }
elseif ($selection -match "^\d+$") {
    $index = [int]$selection - 1
    if ($index -ge 0 -and $index -lt $audioFiles.Count) {
        $selectedFile = $audioFiles[$index]
        Write-Host ""
        Write-Host "Playing: $($selectedFile.Name)" -ForegroundColor Green
        Write-Host "Window will close when audio ends." -ForegroundColor Yellow
        Write-Host ""
        & "$ffplayPath" -nodisp -autoexit -hide_banner -loglevel warning "$($selectedFile.FullName)"
    }
    else {
        Write-Host "Invalid index."; Read-Host
    }
}
else {
    Write-Host "Invalid input."; Read-Host
}
