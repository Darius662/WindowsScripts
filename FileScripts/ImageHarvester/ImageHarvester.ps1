<#
.SYNOPSIS
    ImageHarvester - Recursively copies all image files from source to destination

.DESCRIPTION
    This script searches through all folders and subfolders for image files and copies them to a specified destination location with detailed logging.

.PARAMETER SourcePath
    The source directory to search for image files

.PARAMETER DestinationPath
    The destination directory where image files will be copied

.PARAMETER LogPath
    Optional: Custom path for the log file (defaults to destination directory)

.EXAMPLE
    .\ImageHarvester.ps1 -SourcePath "C:\Photos" -DestinationPath "D:\Backup\Images"

.EXAMPLE
    .\ImageHarvester.ps1 -SourcePath "C:\Users\John\Pictures" -DestinationPath "E:\ImageCollection" -LogPath "C:\Logs"
#>

param(
    [Parameter(Mandatory=$true, HelpMessage="Enter the source directory path")]
    [string]$SourcePath,
    
    [Parameter(Mandatory=$true, HelpMessage="Enter the destination directory path")]
    [string]$DestinationPath,
    
    [Parameter(Mandatory=$false)]
    [string]$LogPath
)

# Script information
$ScriptVersion = "1.0"
$ScriptName = "ImageHarvester"

# Common image file extensions
$imageExtensions = @("*.jpg", "*.jpeg", "*.png", "*.gif", "*.bmp", "*.tiff", "*.tif", "*.webp", "*.heic", "*.raw", "*.cr2", "*.nef", "*.arw", "*.svg", "*.ico")

# Set default log path if not provided
if (-not $LogPath) {
    $LogPath = Join-Path $DestinationPath "ImageHarvester_log_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
}

# Initialize counters and timing
$totalFiles = 0
$copiedFiles = 0
$errorFiles = 0
$startTime = Get-Date

function Write-Log {
    param([string]$Message, [string]$Color = "White")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] $Message"
    Write-Host $logMessage -ForegroundColor $Color
    $logMessage | Out-File -FilePath $LogPath -Append -Encoding UTF8
}

function Show-ScriptHeader {
    Write-Host "`n" + "="*60 -ForegroundColor Cyan
    Write-Host "IMAGE HARVESTER v$ScriptVersion" -ForegroundColor Cyan
    Write-Host "Image File Collection Script" -ForegroundColor Cyan
    Write-Host "="*60 -ForegroundColor Cyan
    Write-Host "Start Time: $startTime" -ForegroundColor Yellow
    Write-Host "Source: $SourcePath" -ForegroundColor Yellow
    Write-Host "Destination: $DestinationPath" -ForegroundColor Yellow
    Write-Host "Log File: $LogPath" -ForegroundColor Yellow
    Write-Host "="*60 -ForegroundColor Cyan
}

function Test-Paths {
    # Test source path
    if (-not (Test-Path $SourcePath)) {
        Write-Log "ERROR: Source path does not exist: $SourcePath" "Red"
        return $false
    }
    
    # Create destination path if it doesn't exist
    if (-not (Test-Path $DestinationPath)) {
        try {
            New-Item -ItemType Directory -Path $DestinationPath -Force | Out-Null
            Write-Log "Created destination directory: $DestinationPath" "Green"
        }
        catch {
            Write-Log "ERROR: Could not create destination directory: $DestinationPath" "Red"
            return $false
        }
    }
    
    return $true
}

# Main execution
Show-ScriptHeader

# Validate paths
if (-not (Test-Paths)) {
    Write-Log "Script execution aborted due to path errors." "Red"
    exit 1
}

Write-Log "Searching for image files in $SourcePath..." "Green"

try {
    # Get all image files recursively
    $allImageFiles = Get-ChildItem -Path $SourcePath -Recurse -Include $imageExtensions -ErrorAction SilentlyContinue
    $totalFiles = $allImageFiles.Count
    
    if ($totalFiles -eq 0) {
        Write-Log "No image files found in the specified source path." "Yellow"
        exit 0
    }
    
    Write-Log "Found $totalFiles image files to process" "Green"
    Write-Log "Starting copy operation..." "Green"
    
    # Process each file
    $currentFile = 0
    foreach ($file in $allImageFiles) {
        $currentFile++
        $fileSize = "{0:N2} MB" -f ($file.Length / 1MB)
        
        # Update progress
        $percentComplete = [math]::Round(($currentFile / $totalFiles) * 100, 2)
        Write-Progress -Activity "ImageHarvester - Copying Files" `
                      -Status "Processing: $($file.Name)" `
                      -PercentComplete $percentComplete `
                      -CurrentOperation "File $currentFile of $totalFiles ($fileSize)"
        
        try {
            $destinationFile = Join-Path $DestinationPath $file.Name
            
            # Handle duplicate file names
            $originalDest = $destinationFile
            $wasRenamed = $false
            if (Test-Path $destinationFile) {
                $baseName = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
                $fileExtension = [System.IO.Path]::GetExtension($file.Name)
                $counter = 1
                
                do {
                    $newFileName = "${baseName}_${counter}${fileExtension}"
                    $destinationFile = Join-Path $DestinationPath $newFileName
                    $counter++
                } while (Test-Path $destinationFile)
                $wasRenamed = $true
            }
            
            # Copy the file
            $copyStart = Get-Date
            Copy-Item -Path $file.FullName -Destination $destinationFile -Force
            $copyTime = (Get-Date) - $copyStart
            
            # Log success
            $status = if ($wasRenamed) { "COPIED (renamed)" } else { "COPIED" }
            $logMessage = "[$currentFile/$totalFiles] $status`: $($file.Name) -> $(Split-Path $destinationFile -Leaf) ($fileSize, $($copyTime.TotalSeconds.ToString('0.00'))s)"
            Write-Log $logMessage "Green"
            
            $copiedFiles++
        }
        catch {
            $errorFiles++
            $errorMessage = "[$currentFile/$totalFiles] ERROR: $($file.Name) - $($_.Exception.Message)"
            Write-Log $errorMessage "Red"
        }
    }
    
    Write-Progress -Activity "ImageHarvester - Copying Files" -Completed
}
catch {
    Write-Log "Fatal error during execution: $($_.Exception.Message)" "Red"
    exit 1
}

# Generate summary
$endTime = Get-Date
$duration = $endTime - $startTime

$summary = @"

=== COPY SUMMARY ===
Operation started: $startTime
Operation ended: $endTime
Total duration: $($duration.ToString('hh\:mm\:ss'))

Total files found: $totalFiles
Successfully copied: $copiedFiles
Files with errors: $errorFiles

Source: $SourcePath
Destination: $DestinationPath
Log file: $LogPath
"@

Write-Host $summary -ForegroundColor Cyan
$summary | Out-File -FilePath $LogPath -Append -Encoding UTF8

# Final status
if ($errorFiles -eq 0) {
    Write-Log "Operation completed successfully! All $copiedFiles files copied." "Cyan"
} else {
    Write-Log "Operation completed with $errorFiles errors. $copiedFiles files copied successfully." "Yellow"
}

Write-Log "Log file saved to: $LogPath" "Yellow"