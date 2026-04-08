# uty1_manage-files.ps1
# Manage audio files: list, delete, rename

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if ([string]::IsNullOrEmpty($scriptDir)) { $scriptDir = "." }

chcp 65001 | Out-Null
[Console]::InputEncoding = [System.Text.UTF8Encoding]::new($false)
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)

function Get-AudioFiles {
    $allFiles = Get-ChildItem -Path "$scriptDir\*" -Include *.mp3, *.wav, *.m4a, *.wma, *.ogg, *.flac -File | Where-Object {
        $_.Name -notmatch "^(WhisperDesktop|FFmpeg|temp|_level_test)"
    }
    return @($allFiles)
}

function Format-FileSize {
    param([long]$bytes)
    if ($bytes -lt 1KB) { return "$bytes B" }
    elseif ($bytes -lt 1MB) { return "{0:N1} KB" -f ($bytes / 1KB) }
    else { return "{0:N1} MB" -f ($bytes / 1MB) }
}

function Get-AudioDuration {
    param([string]$filePath)
    $ffmpegPath = Join-Path $scriptDir "FFmpeg\ffmpeg.exe"
    if (-not (Test-Path $ffmpegPath)) { return "N/A" }

    $result = & "$ffmpegPath" -i "$filePath" 2>&1
    $durationLine = $result | Where-Object { $_ -match "Duration:\s*(\d{2}:\d{2}:\d{2}\.\d{2})" }
    if ($durationLine) {
        $dur = $Matches[1]
        $parts = $dur -split ":"
        $mins = [int]$parts[0] * 60 + [int]$parts[1]
        $secs = [int]($parts[2] -split "\.")[0]
        $totalSecs = $mins + $secs
        if ($totalSecs -ge 3600) {
            return "{0:N0} min" -f ($totalSecs / 60)
        }
        else {
            return "{0:N0} sec" -f $totalSecs
        }
    }
    return "N/A"
}

while ($true) {
    Clear-Host
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  Audio File Manager" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""

    $audioFiles = Get-AudioFiles

    if ($audioFiles.Count -eq 0) {
        Write-Host "No audio files found." -ForegroundColor Yellow
        Write-Host ""
        Read-Host "Press Enter to exit"
        exit 0
    }

    Write-Host "Found $($audioFiles.Count) file(s):" -ForegroundColor Gray
    Write-Host ""

    for ($i = 0; $i -lt $audioFiles.Count; $i++) {
        $f = $audioFiles[$i]
        $dur = Get-AudioDuration $f.FullName
        $size = Format-FileSize $f.Length
        $num = ($i + 1).ToString().PadLeft(2)
        Write-Host "  [$num] $($f.Name)" -ForegroundColor White
        Write-Host "       Size: $size | Duration: $dur | Modified: $($f.LastWriteTime.ToString('yyyy-MM-dd HH:mm'))" -ForegroundColor DarkGray
    }

    Write-Host ""
    Write-Host "  [R] Rename a file" -ForegroundColor Yellow
    Write-Host "  [D] Delete a file" -ForegroundColor Red
    Write-Host "  [Enter] Exit" -ForegroundColor Gray
    Write-Host ""

    $choice = Read-Host "Select file number, [R], [D], or [Enter] to exit"

    if ([string]::IsNullOrEmpty($choice)) { exit 0 }

    if ($choice -eq "R" -or $choice -eq "r") {
        $fileNum = Read-Host "Enter file number to rename"
        $userVal = 0
        if ([int]::TryParse($fileNum, [ref]$userVal) -and $userVal -ge 1 -and $userVal -le $audioFiles.Count) {
            $oldFile = $audioFiles[$userVal - 1]
            Write-Host ""
            Write-Host "Current name: $($oldFile.Name)" -ForegroundColor Yellow
            $newName = Read-Host "Enter new name (with extension)"
            if (-not [string]::IsNullOrEmpty($newName)) {
                $newPath = Join-Path $scriptDir $newName
                if (Test-Path $newPath) {
                    Write-Host "A file with that name already exists." -ForegroundColor Red
                }
                else {
                    Rename-Item $oldFile.FullName -NewName $newName -Force
                    Write-Host "Renamed to: $newName" -ForegroundColor Green
                }
            }
        }
        else {
            Write-Host "Invalid number." -ForegroundColor Red
        }
        Read-Host "Press Enter to continue"
        continue
    }

    if ($choice -eq "D" -or $choice -eq "d") {
        $fileNum = Read-Host "Enter file number to delete"
        $userVal = 0
        if ([int]::TryParse($fileNum, [ref]$userVal) -and $userVal -ge 1 -and $userVal -le $audioFiles.Count) {
            $delFile = $audioFiles[$userVal - 1]
            Write-Host ""
            Write-Host "Delete: $($delFile.Name)?" -ForegroundColor Red
            $confirm = Read-Host "Confirm? [y/N]"
            if ($confirm -eq "y" -or $confirm -eq "Y") {
                # Also delete associated .txt and .srt files
                $baseName = [System.IO.Path]::GetFileNameWithoutExtension($delFile.Name)
                $txtPath = Join-Path $scriptDir "$baseName.txt"
                $srtPath = Join-Path $scriptDir "$baseName.srt"

                Remove-Item $delFile.FullName -Force
                Write-Host "Deleted: $($delFile.Name)" -ForegroundColor Green
                if (Test-Path $txtPath) {
                    Remove-Item $txtPath -Force
                    Write-Host "Deleted: $baseName.txt" -ForegroundColor Green
                }
                if (Test-Path $srtPath) {
                    Remove-Item $srtPath -Force
                    Write-Host "Deleted: $baseName.srt" -ForegroundColor Green
                }
            }
            else {
                Write-Host "Cancelled." -ForegroundColor Gray
            }
        }
        else {
            Write-Host "Invalid number." -ForegroundColor Red
        }
        Read-Host "Press Enter to continue"
        continue
    }

    # Try to play selected file
    $userVal = 0
    if ([int]::TryParse($choice, [ref]$userVal) -and $userVal -ge 1 -and $userVal -le $audioFiles.Count) {
        $selectedFile = $audioFiles[$userVal - 1]
        $ffplayPath = Join-Path $scriptDir "FFmpeg\ffplay.exe"
        if (Test-Path $ffplayPath) {
            Write-Host ""
            Write-Host "Playing: $($selectedFile.Name)" -ForegroundColor Green
            & "$ffplayPath" -nodisp -autoexit -hide_banner -loglevel warning "$($selectedFile.FullName)"
        }
        else {
            Write-Host "ffplay.exe not found. Run Step 1 first." -ForegroundColor Red
        }
        Read-Host "Press Enter to continue"
    }
    else {
        Write-Host "Invalid choice." -ForegroundColor Red
        Read-Host "Press Enter to continue"
    }
}
