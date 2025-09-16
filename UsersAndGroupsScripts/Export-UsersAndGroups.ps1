#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Exports local users, groups, and their memberships to a CSV file.

.DESCRIPTION
    This script extracts all local users, groups, and group memberships from the current computer
    and exports them to a CSV file that can be used for migration to another computer.

.PARAMETER OutputPath
    The path where the CSV file will be saved. Default is "UserGroupExport.csv" in the current directory.

.EXAMPLE
    .\Export-UsersAndGroups.ps1 -OutputPath "C:\Backup\users.csv"
#>

param(
    [string]$OutputPath = ".\UserGroupExport.csv"
)

# Function to get user properties safely
function Get-SafeUserProperty {
    param($User, $PropertyName)
    try {
        return $User.$PropertyName
    }
    catch {
        return $null
    }
}

# Function to convert SecureString to plain text (for password age, etc.)
function ConvertFrom-SecureStringToPlainText {
    param($SecureString)
    try {
        if ($SecureString) {
            $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureString)
            return [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
        }
        return $null
    }
    catch {
        return $null
    }
}

Write-Host "Starting export of users, groups, and memberships..." -ForegroundColor Green

# Initialize arrays to store data
$ExportData = @()

try {
    # Get all local users
    Write-Host "Collecting local users..." -ForegroundColor Yellow
    $LocalUsers = Get-LocalUser -ErrorAction SilentlyContinue
    
    foreach ($User in $LocalUsers) {
        $UserData = [PSCustomObject]@{
            Type = "User"
            Name = $User.Name
            FullName = Get-SafeUserProperty $User "FullName"
            Description = Get-SafeUserProperty $User "Description"
            Enabled = $User.Enabled
            PasswordRequired = Get-SafeUserProperty $User "PasswordRequired"
            PasswordChangeableDate = Get-SafeUserProperty $User "PasswordChangeableDate"
            PasswordExpires = Get-SafeUserProperty $User "PasswordExpires"
            UserMayChangePassword = Get-SafeUserProperty $User "UserMayChangePassword"
            PasswordLastSet = Get-SafeUserProperty $User "PasswordLastSet"
            LastLogon = Get-SafeUserProperty $User "LastLogon"
            GroupMembership = ""
            GroupDescription = ""
            GroupMembers = ""
        }
        $ExportData += $UserData
    }

    # Get all local groups
    Write-Host "Collecting local groups..." -ForegroundColor Yellow
    $LocalGroups = Get-LocalGroup -ErrorAction SilentlyContinue
    
    foreach ($Group in $LocalGroups) {
        # Get group members
        $GroupMembers = @()
        try {
            $Members = Get-LocalGroupMember -Group $Group.Name -ErrorAction SilentlyContinue
            $GroupMembers = $Members | ForEach-Object { $_.Name }
        }
        catch {
            Write-Warning "Could not retrieve members for group: $($Group.Name)"
        }
        
        $GroupData = [PSCustomObject]@{
            Type = "Group"
            Name = $Group.Name
            FullName = ""
            Description = $Group.Description
            Enabled = $true
            PasswordRequired = $null
            PasswordChangeableDate = $null
            PasswordExpires = $null
            UserMayChangePassword = $null
            PasswordLastSet = $null
            LastLogon = $null
            GroupMembership = ""
            GroupDescription = $Group.Description
            GroupMembers = ($GroupMembers -join ";")
        }
        $ExportData += $GroupData
    }

    # Get group memberships for each user
    Write-Host "Collecting group memberships..." -ForegroundColor Yellow
    foreach ($User in $LocalUsers) {
        $UserGroups = @()
        foreach ($Group in $LocalGroups) {
            try {
                $Members = Get-LocalGroupMember -Group $Group.Name -ErrorAction SilentlyContinue
                if ($Members | Where-Object { $_.Name -eq $User.Name -or $_.Name -eq "$env:COMPUTERNAME\$($User.Name)" }) {
                    $UserGroups += $Group.Name
                }
            }
            catch {
                # Skip groups we can't access
            }
        }
        
        # Update the user record with group memberships
        $UserRecord = $ExportData | Where-Object { $_.Type -eq "User" -and $_.Name -eq $User.Name }
        if ($UserRecord) {
            $UserRecord.GroupMembership = ($UserGroups -join ";")
        }
    }

    # Export to CSV
    Write-Host "Exporting data to CSV: $OutputPath" -ForegroundColor Yellow
    $ExportData | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8

    Write-Host "Export completed successfully!" -ForegroundColor Green
    Write-Host "Total records exported: $($ExportData.Count)" -ForegroundColor Cyan
    Write-Host "Users exported: $(($ExportData | Where-Object {$_.Type -eq 'User'}).Count)" -ForegroundColor Cyan
    Write-Host "Groups exported: $(($ExportData | Where-Object {$_.Type -eq 'Group'}).Count)" -ForegroundColor Cyan
    Write-Host "CSV file saved to: $OutputPath" -ForegroundColor Cyan

}
catch {
    Write-Error "An error occurred during export: $($_.Exception.Message)"
    exit 1
}
