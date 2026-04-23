# uty1_manage-files.ps1
# Manage grouped media and transcript files

$OutputEncoding = [System.Text.UTF8Encoding]::new($false)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if ([string]::IsNullOrEmpty($scriptDir)) { $scriptDir = "." }

chcp 65001 | Out-Null
[Console]::InputEncoding = [System.Text.UTF8Encoding]::new($false)
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)

$mediaExtensions = @(".mp3", ".m4a", ".wav", ".wma", ".ogg", ".flac", ".aac", ".mp4", ".mkv")
$textExtensions = @(".txt", ".srt")
$managedExtensions = $mediaExtensions + $textExtensions
$ffplayPath = Join-Path $scriptDir "FFmpeg\ffplay.exe"
$ffmpegPath = Join-Path $scriptDir "FFmpeg\ffmpeg.exe"

function Pause-Continue {
    Read-Host "Press Enter to continue" | Out-Null
}

function Try-ParseMenuIndex {
    param(
        [string]$InputText,
        [int]$Min,
        [int]$Max
    )

    $trimmed = if ($null -eq $InputText) { "" } else { $InputText.Trim() }
    $trimmed = $trimmed.Normalize([System.Text.NormalizationForm]::FormKC).Trim()
    if ([string]::IsNullOrWhiteSpace($trimmed)) {
        return [PSCustomObject]@{
            IsValid = $false
            Value = $null
            Normalized = $trimmed
            Reason = "empty"
        }
    }

    if ($trimmed -notmatch '^\d+$') {
        return [PSCustomObject]@{
            IsValid = $false
            Value = $null
            Normalized = $trimmed
            Reason = "not_numeric"
        }
    }

    [int]$parsedValue = 0
    $parsed = [int]::TryParse($trimmed, [ref]$parsedValue)
    if (-not $parsed) {
        return [PSCustomObject]@{
            IsValid = $false
            Value = $null
            Normalized = $trimmed
            Reason = "tryparse_failed"
        }
    }
    if ($parsedValue -lt $Min -or $parsedValue -gt $Max) {
        return [PSCustomObject]@{
            IsValid = $false
            Value = $null
            Normalized = $trimmed
            Reason = "out_of_range"
        }
    }

    return [PSCustomObject]@{
        IsValid = $true
        Value = $parsedValue
        Normalized = $trimmed
        Reason = "ok"
    }
}

function Format-FileSize {
    param([long]$Bytes)

    if ($Bytes -lt 1KB) { return "$Bytes B" }
    if ($Bytes -lt 1MB) { return "{0:N1} KB" -f ($Bytes / 1KB) }
    if ($Bytes -lt 1GB) { return "{0:N1} MB" -f ($Bytes / 1MB) }
    return "{0:N1} GB" -f ($Bytes / 1GB)
}

function Get-MediaDuration {
    param([string]$FilePath)

    if (-not (Test-Path $ffmpegPath)) { return "N/A" }

    $result = & $ffmpegPath -i $FilePath 2>&1
    $durationLine = $result | Where-Object { $_ -match "Duration:\s*(\d{2}):(\d{2}):(\d{2})\.(\d{2})" } | Select-Object -First 1
    if (-not $durationLine) { return "N/A" }

    $hours = [int]$Matches[1]
    $minutes = [int]$Matches[2]
    $seconds = [int]$Matches[3]

    if ($hours -gt 0) {
        return "{0:D2}:{1:D2}:{2:D2}" -f $hours, $minutes, $seconds
    }
    return "{0:D2}:{1:D2}" -f $minutes, $seconds
}

function Get-ManagedFiles {
    $files = Get-ChildItem -Path $scriptDir -File | Where-Object {
        $managedExtensions -contains $_.Extension.ToLowerInvariant()
    }

    return @($files | Sort-Object -Property LastWriteTime, Name -Descending)
}

function Get-GroupedItems {
    $files = Get-ManagedFiles
    $groups = @{}

    foreach ($file in $files) {
        $baseName = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
        if (-not $groups.ContainsKey($baseName)) {
            $groups[$baseName] = [ordered]@{
                BaseName = $baseName
                Files = New-Object System.Collections.ArrayList
                LatestWriteTime = $file.LastWriteTime
            }
        }

        [void]$groups[$baseName].Files.Add($file)
        if ($file.LastWriteTime -gt $groups[$baseName].LatestWriteTime) {
            $groups[$baseName].LatestWriteTime = $file.LastWriteTime
        }
    }

    $items = foreach ($entry in $groups.GetEnumerator()) {
        $filesInGroup = @($entry.Value.Files | Sort-Object Extension, Name)
        $mediaFiles = @($filesInGroup | Where-Object { $mediaExtensions -contains $_.Extension.ToLowerInvariant() })
        $textFiles = @($filesInGroup | Where-Object { $textExtensions -contains $_.Extension.ToLowerInvariant() })
        $primaryMedia = $mediaFiles | Select-Object -First 1

        [PSCustomObject]@{
            BaseName = $entry.Value.BaseName
            Files = $filesInGroup
            MediaFiles = $mediaFiles
            TextFiles = $textFiles
            LatestWriteTime = $entry.Value.LatestWriteTime
            TotalSize = ($filesInGroup | Measure-Object -Property Length -Sum).Sum
            PrimaryMedia = $primaryMedia
            Duration = if ($primaryMedia) { Get-MediaDuration -FilePath $primaryMedia.FullName } else { "N/A" }
        }
    }

    return @($items | Sort-Object -Property LatestWriteTime, BaseName -Descending)
}

function Write-GroupList {
    param([object[]]$Items)

    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  Media File Manager" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""

    if ($Items.Count -eq 0) {
        Write-Host "No media or transcript files were found in the project root." -ForegroundColor Yellow
        Write-Host "Supported types: $($managedExtensions -join ', ')" -ForegroundColor DarkGray
        Write-Host ""
        return
    }

    Write-Host "Grouped items: $($Items.Count)" -ForegroundColor Gray
    Write-Host "Supported types: $($managedExtensions -join ', ')" -ForegroundColor DarkGray
    Write-Host ""

    for ($i = 0; $i -lt $Items.Count; $i++) {
        $item = $Items[$i]
        $index = ($i + 1).ToString()
        $mediaLabel = if ($item.MediaFiles.Count -gt 0) {
            ($item.MediaFiles | ForEach-Object { $_.Extension.TrimStart(".").ToLowerInvariant() }) -join ","
        }
        else {
            "none"
        }
        $textLabel = if ($item.TextFiles.Count -gt 0) {
            ($item.TextFiles | ForEach-Object { $_.Extension.TrimStart(".").ToLowerInvariant() }) -join ","
        }
        else {
            "none"
        }

        Write-Host "  [$index] $($item.BaseName)" -ForegroundColor White
        Write-Host ("       Media: {0} | Text: {1} | Size: {2} | Duration: {3}" -f $mediaLabel, $textLabel, (Format-FileSize $item.TotalSize), $item.Duration) -ForegroundColor DarkGray
        Write-Host ("       Modified: {0}" -f $item.LatestWriteTime.ToString("yyyy-MM-dd HH:mm")) -ForegroundColor DarkGray
    }

    Write-Host ""
    Write-Host "Select an item number to manage it." -ForegroundColor Gray
    Write-Host "[Enter] Exit" -ForegroundColor Gray
    Write-Host ""
}

function Show-ItemDetails {
    param([object]$Item)

    Clear-Host
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  Item Details" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Base name : $($Item.BaseName)" -ForegroundColor White
    Write-Host "Files     : $($Item.Files.Count)" -ForegroundColor White
    Write-Host "Total size: $(Format-FileSize $Item.TotalSize)" -ForegroundColor White
    Write-Host ""

    for ($i = 0; $i -lt $Item.Files.Count; $i++) {
        $file = $Item.Files[$i]
        $index = ($i + 1).ToString()
        $kind = if ($mediaExtensions -contains $file.Extension.ToLowerInvariant()) { "media" } else { "text" }
        Write-Host "  [$index] $($file.Name)" -ForegroundColor White
        Write-Host ("       Type: {0} | Size: {1} | Modified: {2}" -f $kind, (Format-FileSize $file.Length), $file.LastWriteTime.ToString("yyyy-MM-dd HH:mm")) -ForegroundColor DarkGray
    }

    Write-Host ""
}

function Show-TextPreview {
    param([System.IO.FileInfo]$File)

    Clear-Host
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  Text Preview" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "File: $($File.Name)" -ForegroundColor White
    Write-Host ""

    try {
        $lines = Get-Content -LiteralPath $File.FullName -Encoding UTF8 -TotalCount 20
        if (-not $lines -or $lines.Count -eq 0) {
            Write-Host "(File is empty)" -ForegroundColor DarkGray
        }
        else {
            foreach ($line in $lines) {
                Write-Host $line
            }
        }
    }
    catch {
        Write-Host "Unable to read file preview." -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor DarkGray
    }

    Write-Host ""
    Pause-Continue
}

function Select-FileFromGroup {
    param(
        [object]$Item,
        [string]$Prompt,
        [string[]]$AllowedExtensions = $managedExtensions
    )

    $candidateFiles = @($Item.Files | Where-Object { $AllowedExtensions -contains $_.Extension.ToLowerInvariant() })
    if ($candidateFiles.Count -eq 0) {
        Write-Host "No matching files in this item." -ForegroundColor Yellow
        Pause-Continue
        return $null
    }

    Write-Host $Prompt -ForegroundColor Gray
    for ($i = 0; $i -lt $candidateFiles.Count; $i++) {
        $file = $candidateFiles[$i]
        $index = ($i + 1).ToString()
        Write-Host "  [$index] $($file.Name)" -ForegroundColor White
    }
    Write-Host "  [Enter] Cancel" -ForegroundColor Gray
    Write-Host ""

    $choice = Read-Host "Choose a file"
    $parseResult = Try-ParseMenuIndex -InputText $choice -Min 1 -Max $candidateFiles.Count
    if ($parseResult.IsValid) { return $candidateFiles[$parseResult.Value - 1] }

    Write-Host "Invalid selection." -ForegroundColor Red
    Pause-Continue
    return $null
}

function Invoke-PlayMedia {
    param([object]$Item)

    if (-not (Test-Path $ffplayPath)) {
        Write-Host "ffplay.exe not found. Run Step 1 first." -ForegroundColor Red
        Pause-Continue
        return
    }

    if ($Item.MediaFiles.Count -eq 0) {
        Write-Host "This item has no media file to play." -ForegroundColor Yellow
        Pause-Continue
        return
    }

    $mediaFile = if ($Item.MediaFiles.Count -eq 1) {
        $Item.MediaFiles[0]
    }
    else {
        Select-FileFromGroup -Item $Item -Prompt "Select a media file to play:" -AllowedExtensions $mediaExtensions
    }

    if (-not $mediaFile) { return }

    Write-Host ""
    Write-Host "Playing: $($mediaFile.Name)" -ForegroundColor Green
    & $ffplayPath -autoexit -hide_banner -loglevel warning $mediaFile.FullName
    Write-Host ""
    Pause-Continue
}

function Invoke-ViewFile {
    param([object]$Item)

    $file = Select-FileFromGroup -Item $Item -Prompt "Select a file to view:"
    if (-not $file) { return }

    $extension = $file.Extension.ToLowerInvariant()
    if ($textExtensions -contains $extension) {
        Show-TextPreview -File $file
        return
    }

    Clear-Host
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  File Information" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Name    : $($file.Name)" -ForegroundColor White
    Write-Host "Path    : $($file.FullName)" -ForegroundColor White
    Write-Host "Type    : media" -ForegroundColor White
    Write-Host "Size    : $(Format-FileSize $file.Length)" -ForegroundColor White
    Write-Host "Modified: $($file.LastWriteTime.ToString('yyyy-MM-dd HH:mm'))" -ForegroundColor White
    Write-Host "Duration: $(Get-MediaDuration -FilePath $file.FullName)" -ForegroundColor White
    Write-Host ""
    Pause-Continue
}

function Invoke-DeleteGroup {
    param([object]$Item)

    Clear-Host
    Write-Host "========================================" -ForegroundColor Red
    Write-Host "  Delete Group" -ForegroundColor Red
    Write-Host "========================================" -ForegroundColor Red
    Write-Host ""
    Write-Host "The following files will be deleted:" -ForegroundColor Yellow
    foreach ($file in $Item.Files) {
        Write-Host "  - $($file.Name)" -ForegroundColor White
    }
    Write-Host ""

    $confirm = Read-Host "Confirm delete? [Y/N]"
    if ([string]::IsNullOrWhiteSpace($confirm) -or $confirm.Trim().ToUpperInvariant() -ne "Y") {
        Write-Host "Cancelled." -ForegroundColor Gray
        Pause-Continue
        return [PSCustomObject]@{
            Deleted = $false
        }
    }

    foreach ($file in $Item.Files) {
        Remove-Item -LiteralPath $file.FullName -Force
        Write-Host "Deleted: $($file.Name)" -ForegroundColor Green
    }

    Write-Host ""
    Pause-Continue
    return [PSCustomObject]@{
        Deleted = $true
    }
}

function Invoke-DeleteSingleFile {
    param([object]$Item)

    $file = Select-FileFromGroup -Item $Item -Prompt "Select a file to delete:"
    if (-not $file) {
        return [PSCustomObject]@{
            Deleted = $false
        }
    }

    Write-Host ""
    Write-Host "Delete file: $($file.Name)" -ForegroundColor Red
    $confirm = Read-Host "Confirm delete? [Y/N]"
    if ([string]::IsNullOrWhiteSpace($confirm) -or $confirm.Trim().ToUpperInvariant() -ne "Y") {
        Write-Host "Cancelled." -ForegroundColor Gray
        Pause-Continue
        return [PSCustomObject]@{
            Deleted = $false
        }
    }

    Remove-Item -LiteralPath $file.FullName -Force
    Write-Host "Deleted: $($file.Name)" -ForegroundColor Green
    Write-Host ""
    Pause-Continue
    return [PSCustomObject]@{
        Deleted = $true
    }
}

function Get-ItemByBaseName {
    param([string]$BaseName)

    return @(
        Get-GroupedItems | Where-Object { $_.BaseName -eq $BaseName } | Select-Object -First 1
    ) | Select-Object -First 1
}

while ($true) {
    Clear-Host
    $items = @(Get-GroupedItems)
    Write-GroupList -Items $items

    if ($items.Count -eq 0) {
        Pause-Continue
        exit 0
    }

    $choice = Read-Host "Choose an item number"
    if ([string]::IsNullOrWhiteSpace($choice)) { exit 0 }

    $parseResult = Try-ParseMenuIndex -InputText $choice -Min 1 -Max $items.Count
    $selectedIndex = if ($parseResult.IsValid) { $parseResult.Value } else { $null }
    if ($null -eq $selectedIndex) {
        Write-Host "Invalid selection." -ForegroundColor Red
        Pause-Continue
        continue
    }

    $selectedItem = $items[$selectedIndex - 1]
    $leaveItemMenu = $false

    while (-not $leaveItemMenu) {
        if (-not $selectedItem) {
            $leaveItemMenu = $true
            continue
        }

        Show-ItemDetails -Item $selectedItem
        Write-Host "[V] View file details or text preview" -ForegroundColor Yellow
        Write-Host "[P] Play a media file" -ForegroundColor Green
        Write-Host "[D] Delete the whole group" -ForegroundColor Red
        Write-Host "[X] Delete a single file" -ForegroundColor Magenta
        Write-Host "[Enter] Back to list" -ForegroundColor Gray
        Write-Host ""

        $action = Read-Host "Choose action"
        if ([string]::IsNullOrWhiteSpace($action)) {
            $leaveItemMenu = $true
            continue
        }

        switch ($action.ToUpperInvariant()) {
            "V" {
                Invoke-ViewFile -Item $selectedItem
                $selectedItem = Get-ItemByBaseName -BaseName $selectedItem.BaseName
                if (-not $selectedItem) {
                    $leaveItemMenu = $true
                    continue
                }
            }
            "P" {
                Invoke-PlayMedia -Item $selectedItem
                $selectedItem = Get-ItemByBaseName -BaseName $selectedItem.BaseName
                if (-not $selectedItem) {
                    $leaveItemMenu = $true
                    continue
                }
            }
            "D" {
                $deleteResult = Invoke-DeleteGroup -Item $selectedItem
                if ($deleteResult.Deleted) {
                    $selectedItem = $null
                    $leaveItemMenu = $true
                    continue
                }
            }
            "X" {
                $deleteResult = Invoke-DeleteSingleFile -Item $selectedItem
                $selectedItem = Get-ItemByBaseName -BaseName $selectedItem.BaseName
                if (-not $selectedItem) {
                    $leaveItemMenu = $true
                    continue
                }
            }
            default {
                Write-Host "Invalid action." -ForegroundColor Red
                Pause-Continue
            }
        }
    }
}
