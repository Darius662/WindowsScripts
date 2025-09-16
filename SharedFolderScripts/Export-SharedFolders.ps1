#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Exports all shared folders and their configurations to a CSV file.

.DESCRIPTION
    This script extracts all shared folders, their paths, permissions, and configurations from the current computer
    and exports them to a CSV file that can be used for migration to another computer.

.PARAMETER OutputPath
    The path where the CSV file will be saved. Default is "SharedFolderExport.csv" in the current directory.

.EXAMPLE
    .\Export-SharedFolders.ps1 -OutputPath "C:\Backup\shares.csv"
#>

param(
    [string]$OutputPath = ".\SharedFolderExport.csv"
)

# Function to get share permissions safely
function Get-SharePermissions {
    param($ShareName)
    try {
        $Permissions = Get-SmbShareAccess -Name $ShareName -ErrorAction SilentlyContinue
        if ($Permissions) {
            $PermissionList = @()
            foreach ($Permission in $Permissions) {
                $PermissionList += "$($Permission.AccountName):$($Permission.AccessControlType):$($Permission.AccessRight)"
            }
            return ($PermissionList -join ";")
        }
        return ""
    }
    catch {
        Write-Warning "Could not retrieve permissions for share: $ShareName"
        return ""
    }
}

# Function to get folder permissions safely
function Get-FolderPermissions {
    param($FolderPath)
    try {
        if (Test-Path $FolderPath) {
            $Acl = Get-Acl -Path $FolderPath -ErrorAction SilentlyContinue
            if ($Acl) {
                $PermissionList = @()
                foreach ($Access in $Acl.Access) {
                    $PermissionList += "$($Access.IdentityReference):$($Access.AccessControlType):$($Access.FileSystemRights):$($Access.InheritanceFlags):$($Access.PropagationFlags)"
                }
                return ($PermissionList -join "||")
            }
        }
        return ""
    }
    catch {
        Write-Warning "Could not retrieve folder permissions for: $FolderPath"
        return ""
    }
}

Write-Host "Starting export of shared folders..." -ForegroundColor Green

# Initialize array to store data
$ExportData = @()

try {
    # Get all SMB shares (excluding administrative shares)
    Write-Host "Collecting shared folders..." -ForegroundColor Yellow
    $Shares = Get-SmbShare -ErrorAction SilentlyContinue | Where-Object { 
        $_.ShareType -eq "FileSystemDirectory" -and 
        $_.Name -notmatch '^[A-Z]\$$' -and 
        $_.Name -ne "ADMIN$" -and 
        $_.Name -ne "IPC$" -and
        $_.Name -ne "print$"
    }
    
    if (-not $Shares) {
        Write-Host "No user-defined shared folders found." -ForegroundColor Yellow
        $ExportData = @()
    }
    else {
        foreach ($Share in $Shares) {
            Write-Host "Processing share: $($Share.Name)" -ForegroundColor Cyan
            
            # Get share permissions
            $SharePermissions = Get-SharePermissions -ShareName $Share.Name
            
            # Get folder permissions
            $FolderPermissions = Get-FolderPermissions -FolderPath $Share.Path
            
            # Check if folder exists
            $FolderExists = Test-Path $Share.Path
            
            $ShareData = [PSCustomObject]@{
                ShareName = $Share.Name
                Path = $Share.Path
                Description = $Share.Description
                FolderTarget = $Share.FolderEnumerationMode
                CachingMode = $Share.CachingMode
                ConcurrentUserLimit = $Share.ConcurrentUserLimit
                CATimeout = $Share.CATimeout
                EncryptData = $Share.EncryptData
                CompressData = $Share.CompressData
                ContinuouslyAvailable = $Share.ContinuouslyAvailable
                ShareState = $Share.ShareState
                ShareType = $Share.ShareType
                ScopeName = $Share.ScopeName
                FolderExists = $FolderExists
                SharePermissions = $SharePermissions
                FolderPermissions = $FolderPermissions
                ExportDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                SourceComputer = $env:COMPUTERNAME
            }
            $ExportData += $ShareData
        }
    }

    # Export to CSV
    Write-Host "Exporting data to CSV: $OutputPath" -ForegroundColor Yellow
    $ExportData | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8

    Write-Host "Export completed successfully!" -ForegroundColor Green
    Write-Host "Total shared folders exported: $($ExportData.Count)" -ForegroundColor Cyan
    Write-Host "CSV file saved to: $OutputPath" -ForegroundColor Cyan
    
    if ($ExportData.Count -gt 0) {
        Write-Host "`nExported shares:" -ForegroundColor Yellow
        foreach ($Share in $ExportData) {
            Write-Host "  - $($Share.ShareName) -> $($Share.Path)" -ForegroundColor White
        }
    }

}
catch {
    Write-Error "An error occurred during export: $($_.Exception.Message)"
    exit 1
}
