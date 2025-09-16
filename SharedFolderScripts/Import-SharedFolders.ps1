#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Imports shared folders and their configurations from a CSV file.

.DESCRIPTION
    This script reads a CSV file created by Export-SharedFolders.ps1 and recreates
    the shared folders, their paths, permissions, and configurations on the target computer.

.PARAMETER InputPath
    The path to the CSV file containing the exported shared folder data.

.PARAMETER CreateMissingFolders
    If specified, missing folders will be created automatically.

.PARAMETER SkipExisting
    If specified, existing shares will be skipped instead of updated.

.PARAMETER LogPath
    Path for the import log file. Default is "ImportLog.txt" in the current directory.

.PARAMETER BackupPath
    Path to backup existing share configurations before making changes. Default is "ShareBackup.csv".

.EXAMPLE
    .\Import-SharedFolders.ps1 -InputPath "C:\Backup\shares.csv" -CreateMissingFolders

.EXAMPLE
    .\Import-SharedFolders.ps1 -InputPath "shares.csv" -SkipExisting -LogPath "C:\Logs\import.log"
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$InputPath,
    
    [switch]$CreateMissingFolders,
    
    [switch]$SkipExisting,
    
    [string]$LogPath = ".\ImportLog.txt",
    
    [string]$BackupPath = ".\ShareBackup.csv"
)

# Function to write log entries
function Write-Log {
    param($Message, $Level = "INFO")
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "[$Timestamp] [$Level] $Message"
    Write-Host $LogEntry
    Add-Content -Path $LogPath -Value $LogEntry
}

# Function to backup existing shares
function Backup-ExistingShares {
    try {
        Write-Log "Creating backup of existing shares..."
        $ExistingShares = Get-SmbShare -ErrorAction SilentlyContinue | Where-Object { 
            $_.ShareType -eq "FileSystemDirectory" -and 
            $_.Name -notmatch '^[A-Z]\$$' -and 
            $_.Name -ne "ADMIN$" -and 
            $_.Name -ne "IPC$" -and
            $_.Name -ne "print$"
        }
        
        if ($ExistingShares) {
            $BackupData = @()
            foreach ($Share in $ExistingShares) {
                $BackupData += [PSCustomObject]@{
                    ShareName = $Share.Name
                    Path = $Share.Path
                    Description = $Share.Description
                    BackupDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                }
            }
            $BackupData | Export-Csv -Path $BackupPath -NoTypeInformation -Encoding UTF8
            Write-Log "Backup saved to: $BackupPath"
        } else {
            Write-Log "No existing shares to backup"
        }
    }
    catch {
        Write-Log "Failed to create backup: $($_.Exception.Message)" "WARNING"
    }
}

# Function to create folder if it doesn't exist
function Test-AndCreateFolder {
    param($FolderPath)
    
    try {
        if (-not (Test-Path $FolderPath)) {
            if ($CreateMissingFolders) {
                Write-Log "Creating missing folder: $FolderPath"
                New-Item -Path $FolderPath -ItemType Directory -Force | Out-Null
                return $true
            } else {
                Write-Log "Folder does not exist and -CreateMissingFolders not specified: $FolderPath" "WARNING"
                return $false
            }
        }
        return $true
    }
    catch {
        Write-Log "Failed to create folder '$FolderPath': $($_.Exception.Message)" "ERROR"
        return $false
    }
}

# Function to check if identity is a SID
function Test-IsSID {
    param($Identity)
    # SIDs start with S- and follow the pattern S-R-I-S...
    return $Identity -match '^S-\d+-\d+'
}

# Function to set folder permissions
function Set-FolderPermissions {
    param($FolderPath, $PermissionsString)
    
    if ([string]::IsNullOrWhiteSpace($PermissionsString)) {
        return
    }
    
    try {
        $Permissions = $PermissionsString -split "\|\|"
        $Acl = Get-Acl -Path $FolderPath
        
        foreach ($Permission in $Permissions) {
            if ([string]::IsNullOrWhiteSpace($Permission)) { continue }
            
            $Parts = $Permission -split ":"
            if ($Parts.Count -ge 3) {
                $Identity = $Parts[0]
                
                # Skip SIDs as they are system-specific
                if (Test-IsSID -Identity $Identity) {
                    Write-Log "Skipping SID-based permission: $Identity (SIDs are system-specific)" "INFO"
                    continue
                }
                
                $AccessControlType = $Parts[1]
                $FileSystemRights = $Parts[2]
                $InheritanceFlags = if ($Parts.Count -gt 3) { $Parts[3] } else { "ContainerInherit,ObjectInherit" }
                $PropagationFlags = if ($Parts.Count -gt 4) { $Parts[4] } else { "None" }
                
                try {
                    $AccessRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
                        $Identity, 
                        $FileSystemRights, 
                        $InheritanceFlags, 
                        $PropagationFlags, 
                        $AccessControlType
                    )
                    $Acl.SetAccessRule($AccessRule)
                    Write-Log "Added folder permission: $Identity -> $FileSystemRights ($AccessControlType)"
                }
                catch {
                    Write-Log "Failed to add folder permission for '$Identity': $($_.Exception.Message)" "WARNING"
                }
            }
        }
        
        Set-Acl -Path $FolderPath -AclObject $Acl
        Write-Log "Folder permissions applied to: $FolderPath"
    }
    catch {
        Write-Log "Failed to set folder permissions for '$FolderPath': $($_.Exception.Message)" "ERROR"
    }
}

# Function to set share permissions
function Set-SharePermissions {
    param($ShareName, $PermissionsString)
    
    if ([string]::IsNullOrWhiteSpace($PermissionsString)) {
        return
    }
    
    try {
        # Remove all existing permissions first
        $ExistingPermissions = Get-SmbShareAccess -Name $ShareName -ErrorAction SilentlyContinue
        foreach ($Permission in $ExistingPermissions) {
            try {
                Revoke-SmbShareAccess -Name $ShareName -AccountName $Permission.AccountName -Force -ErrorAction SilentlyContinue
            }
            catch {
                # Some permissions might not be removable
            }
        }
        
        # Add new permissions
        $Permissions = $PermissionsString -split ";"
        foreach ($Permission in $Permissions) {
            if ([string]::IsNullOrWhiteSpace($Permission)) { continue }
            
            $Parts = $Permission -split ":"
            if ($Parts.Count -eq 3) {
                $AccountName = $Parts[0]
                
                # Skip SIDs as they are system-specific
                if (Test-IsSID -Identity $AccountName) {
                    Write-Log "Skipping SID-based share permission: $AccountName (SIDs are system-specific)" "INFO"
                    continue
                }
                
                $AccessControlType = $Parts[1]
                $AccessRight = $Parts[2]
                
                try {
                    Grant-SmbShareAccess -Name $ShareName -AccountName $AccountName -AccessRight $AccessRight -Force
                    Write-Log "Added share permission: $AccountName -> $AccessRight ($AccessControlType)"
                }
                catch {
                    Write-Log "Failed to add share permission for '$AccountName': $($_.Exception.Message)" "WARNING"
                }
            }
        }
    }
    catch {
        Write-Log "Failed to set share permissions for '$ShareName': $($_.Exception.Message)" "ERROR"
    }
}

# Function to safely create or update share
function Import-Share {
    param($ShareData)
    
    try {
        $ExistingShare = Get-SmbShare -Name $ShareData.ShareName -ErrorAction SilentlyContinue
        
        if ($ExistingShare -and $SkipExisting) {
            Write-Log "Share '$($ShareData.ShareName)' already exists, skipping due to -SkipExisting flag" "WARNING"
            return $false
        }
        
        # Ensure folder exists
        if (-not (Test-AndCreateFolder -FolderPath $ShareData.Path)) {
            Write-Log "Cannot create share '$($ShareData.ShareName)' - folder path is not available" "ERROR"
            return $false
        }
        
        if ($ExistingShare) {
            # Update existing share
            Write-Log "Updating existing share: $($ShareData.ShareName)"
            
            # Remove existing share and recreate with new settings
            Remove-SmbShare -Name $ShareData.ShareName -Force
            Write-Log "Removed existing share: $($ShareData.ShareName)"
        }
        
        # Create new share
        Write-Log "Creating share: $($ShareData.ShareName) -> $($ShareData.Path)"
        
        $ShareParams = @{
            Name = $ShareData.ShareName
            Path = $ShareData.Path
        }
        
        if ($ShareData.Description) { $ShareParams.Description = $ShareData.Description }
        if ($ShareData.FolderTarget) { $ShareParams.FolderEnumerationMode = $ShareData.FolderTarget }
        if ($ShareData.CachingMode) { $ShareParams.CachingMode = $ShareData.CachingMode }
        if ($ShareData.ConcurrentUserLimit -and $ShareData.ConcurrentUserLimit -ne 0) { 
            $ShareParams.ConcurrentUserLimit = [int]$ShareData.ConcurrentUserLimit 
        }
        if ($ShareData.CATimeout) { $ShareParams.CATimeout = [int]$ShareData.CATimeout }
        if ($ShareData.EncryptData -eq $true) { $ShareParams.EncryptData = $true }
        if ($ShareData.CompressData -eq $true) { $ShareParams.CompressData = $true }
        if ($ShareData.ContinuouslyAvailable -eq $true) { $ShareParams.ContinuouslyAvailable = $true }
        
        New-SmbShare @ShareParams
        Write-Log "Share '$($ShareData.ShareName)' created successfully"
        
        # Set folder permissions first
        if ($ShareData.FolderPermissions) {
            Set-FolderPermissions -FolderPath $ShareData.Path -PermissionsString $ShareData.FolderPermissions
        }
        
        # Set share permissions
        if ($ShareData.SharePermissions) {
            Set-SharePermissions -ShareName $ShareData.ShareName -PermissionsString $ShareData.SharePermissions
        }
        
        return $true
    }
    catch {
        Write-Log "Failed to import share '$($ShareData.ShareName)': $($_.Exception.Message)" "ERROR"
        return $false
    }
}

# Main script execution
Write-Log "Starting import of shared folders from: $InputPath"

# Validate input file
if (-not (Test-Path $InputPath)) {
    Write-Log "Input file not found: $InputPath" "ERROR"
    exit 1
}

try {
    # Create backup of existing shares
    Backup-ExistingShares
    
    # Import CSV data
    Write-Log "Reading CSV data..."
    $ImportData = Import-Csv -Path $InputPath
    
    if (-not $ImportData) {
        Write-Log "No data found in CSV file" "ERROR"
        exit 1
    }
    
    Write-Log "Found $($ImportData.Count) shared folders in CSV file"
    
    # Import shares
    Write-Log "Importing shared folders..."
    $SharesImported = 0
    foreach ($Share in $ImportData) {
        if (Import-Share -ShareData $Share) {
            $SharesImported++
        }
    }
    
    # Final summary
    Write-Log "Import completed!" "SUCCESS"
    Write-Log "Shared folders imported/updated: $SharesImported of $($ImportData.Count)"
    Write-Log "Log file saved to: $LogPath"
    if (Test-Path $BackupPath) {
        Write-Log "Backup file saved to: $BackupPath"
    }
    
    Write-Host "`nIMPORTANT: Please verify all share permissions and folder access!" -ForegroundColor Red -BackgroundColor Yellow
    Write-Host "Review the imported shares using: Get-SmbShare" -ForegroundColor Yellow
    
}
catch {
    Write-Log "Critical error during import: $($_.Exception.Message)" "ERROR"
    exit 1
}
