<#
.SYNOPSIS
    Updates plugin files across multiple directories.

.DESCRIPTION
    This script performs a series of file operations to update plugin files:
    1. Renames a plugin ZIP file in the downloads directory
    2. Updates plugin files in two remote directories with backup creation
    3. Extracts the ZIP file in the first remote directory

.PARAMETER DownloadsPath
    Path to the downloads directory where the source ZIP file is located.
    Default is the user's Downloads folder.

.PARAMETER SourceFilePattern
    Pattern to match the source ZIP file in the downloads directory.
    Default is "rac_plugins-*.zip".

.PARAMETER DestinationFileName
    Name to rename the source file to.
    Default is "tcmpapsPlugins.zip".

.PARAMETER RemoteDirectory1
    First remote directory where files will be updated and ZIP extracted.

.PARAMETER RemoteDirectory2
    Second remote directory where files will be updated.

.PARAMETER CreateBackup
    If specified, creates backup of existing files before replacing them.
    Default is $true.

.PARAMETER Force
    If specified, forces the operation without prompting for confirmation.

.EXAMPLE
    .\Update-PluginFiles.ps1 -RemoteDirectory1 "\\server\plugins\main" -RemoteDirectory2 "\\server\plugins\backup"

.EXAMPLE
    .\Update-PluginFiles.ps1 -DownloadsPath "D:\Downloads" -SourceFilePattern "plugins-v2.1.zip" -RemoteDirectory1 "E:\Plugins"

.EXAMPLE
    .\Update-PluginFiles.ps1 -RemoteDirectory1 "\\server\plugins" -RemoteDirectory2 "\\server\backup" -Force
#>

param(
    [string]$DownloadsPath = [System.IO.Path]::Combine($env:USERPROFILE, "Downloads"),
    [string]$SourceFilePattern = "rac_plugins-*.zip",
    [string]$DestinationFileName = "tcmpapsPlugins.zip",
    [Parameter(Mandatory=$true)]
    [string]$RemoteDirectory1,
    [Parameter(Mandatory=$true)]
    [string]$RemoteDirectory2,
    [bool]$CreateBackup = $true,
    [switch]$Force
)

# Function to write to log with timestamp
function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("INFO", "WARNING", "ERROR", "SUCCESS")]
        [string]$Level = "INFO"
    )
    
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogMessage = "[$Timestamp] [$Level] $Message"
    
    # Output to console with color
    switch ($Level) {
        "INFO"    { Write-Host $LogMessage -ForegroundColor Gray }
        "WARNING" { Write-Host $LogMessage -ForegroundColor Yellow }
        "ERROR"   { Write-Host $LogMessage -ForegroundColor Red }
        "SUCCESS" { Write-Host $LogMessage -ForegroundColor Green }
    }
}

# Function to check if path exists and is accessible
function Test-PathAccess {
    param(
        [string]$Path,
        [string]$PathType
    )
    
    if (-not (Test-Path -Path $Path)) {
        Write-Log "$PathType path does not exist: $Path" -Level "ERROR"
        return $false
    }
    
    try {
        $null = Get-ChildItem -Path $Path -ErrorAction Stop -Force
        return $true
    }
    catch {
        Write-Log "Cannot access $PathType path: $Path. Error: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

# Function to remove all files except ZIP archives
function Remove-NonZipFiles {
    param(
        [string]$Directory
    )
    
    try {
        $filesToRemove = Get-ChildItem -Path $Directory -File -Recurse | Where-Object { $_.Extension -ne ".zip" }
        $fileCount = $filesToRemove.Count
        
        if ($fileCount -gt 0) {
            Write-Log "Removing $fileCount non-ZIP files from $Directory" -Level "INFO"
            $filesToRemove | Remove-Item -Force -ErrorAction Stop
            Write-Log "Successfully removed $fileCount non-ZIP files" -Level "SUCCESS"
        }
        else {
            Write-Log "No non-ZIP files found in $Directory" -Level "INFO"
        }
    }
    catch {
        Write-Log "Error removing non-ZIP files: $($_.Exception.Message)" -Level "ERROR"
    }
}

# Main script execution
Write-Log "Starting plugin file update process" -Level "INFO"

# Validate paths
if (-not (Test-PathAccess -Path $DownloadsPath -PathType "Downloads")) {
    exit 1
}

if (-not (Test-PathAccess -Path $RemoteDirectory1 -PathType "First remote")) {
    exit 1
}

if (-not (Test-PathAccess -Path $RemoteDirectory2 -PathType "Second remote")) {
    exit 1
}

# Step 1: Find and rename file in downloads directory
try {
    $sourceFile = Get-ChildItem -Path $DownloadsPath -Filter $SourceFilePattern | Select-Object -First 1
    
    if ($null -eq $sourceFile) {
        Write-Log "Source file matching pattern '$SourceFilePattern' not found in $DownloadsPath" -Level "ERROR"
        exit 1
    }
    
    $destinationPath = Join-Path -Path $DownloadsPath -ChildPath $DestinationFileName
    
    # Check if destination file already exists
    if (Test-Path -Path $destinationPath) {
        if ($Force -or (Read-Host "File '$DestinationFileName' already exists in downloads directory. Overwrite? (Y/N)").ToUpper() -eq 'Y') {
            Remove-Item -Path $destinationPath -Force
            Write-Log "Removed existing file: $destinationPath" -Level "INFO"
        }
        else {
            Write-Log "Operation cancelled by user" -Level "WARNING"
            exit 0
        }
    }
    
    # Rename the file
    Copy-Item -Path $sourceFile.FullName -Destination $destinationPath -Force
    Write-Log "Renamed '$($sourceFile.Name)' to '$DestinationFileName' in downloads directory" -Level "SUCCESS"
}
catch {
    Write-Log "Error processing file in downloads directory: $($_.Exception.Message)" -Level "ERROR"
    exit 1
}

# Step 2: Process first remote directory
try {
    Write-Log "Processing first remote directory: $RemoteDirectory1" -Level "INFO"
    
    # Remove all files except ZIP archives
    Remove-NonZipFiles -Directory $RemoteDirectory1
    
    # Check for backup file and remove it
    $backupFile = Join-Path -Path $RemoteDirectory1 -ChildPath "tcmpapsPlugins.bk.zip"
    if (Test-Path -Path $backupFile) {
        Remove-Item -Path $backupFile -Force
        Write-Log "Removed backup file: tcmpapsPlugins.bk.zip" -Level "INFO"
    }
    
    # Check for existing ZIP file and rename it to backup
    $existingZip = Join-Path -Path $RemoteDirectory1 -ChildPath "tcmpapsPlugins.zip"
    if (Test-Path -Path $existingZip) {
        Rename-Item -Path $existingZip -NewName "tcmpapsPlugins.bk.zip" -Force
        Write-Log "Renamed existing tcmpapsPlugins.zip to tcmpapsPlugins.bk.zip" -Level "SUCCESS"
    }
    
    # Copy new ZIP file from downloads
    Copy-Item -Path $destinationPath -Destination $RemoteDirectory1 -Force
    Write-Log "Copied new tcmpapsPlugins.zip to $RemoteDirectory1" -Level "SUCCESS"
    
    # Extract the ZIP file
    $zipFile = Join-Path -Path $RemoteDirectory1 -ChildPath "tcmpapsPlugins.zip"
    $extractPath = $RemoteDirectory1
    
    Write-Log "Extracting ZIP file to $extractPath" -Level "INFO"
    Expand-Archive -Path $zipFile -DestinationPath $extractPath -Force
    Write-Log "Successfully extracted ZIP file" -Level "SUCCESS"
}
catch {
    Write-Log "Error processing first remote directory: $($_.Exception.Message)" -Level "ERROR"
    exit 1
}

# Step 3: Process second remote directory
try {
    Write-Log "Processing second remote directory: $RemoteDirectory2" -Level "INFO"
    
    # Check for backup file and remove it
    $backupFile = Join-Path -Path $RemoteDirectory2 -ChildPath "tcmpapsPlugins.bk.zip"
    if (Test-Path -Path $backupFile) {
        Remove-Item -Path $backupFile -Force
        Write-Log "Removed backup file: tcmpapsPlugins.bk.zip" -Level "INFO"
    }
    
    # Check for existing ZIP file and rename it to backup
    $existingZip = Join-Path -Path $RemoteDirectory2 -ChildPath "tcmpapsPlugins.zip"
    if (Test-Path -Path $existingZip) {
        Rename-Item -Path $existingZip -NewName "tcmpapsPlugins.bk.zip" -Force
        Write-Log "Renamed existing tcmpapsPlugins.zip to tcmpapsPlugins.bk.zip" -Level "SUCCESS"
    }
    
    # Copy new ZIP file from downloads
    Copy-Item -Path $destinationPath -Destination $RemoteDirectory2 -Force
    Write-Log "Copied new tcmpapsPlugins.zip to $RemoteDirectory2" -Level "SUCCESS"
}
catch {
    Write-Log "Error processing second remote directory: $($_.Exception.Message)" -Level "ERROR"
    exit 1
}

Write-Log "Plugin file update process completed successfully" -Level "SUCCESS"
