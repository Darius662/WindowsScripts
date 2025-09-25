#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Imports local users, groups, and their memberships from a CSV file.

.DESCRIPTION
    This script reads a CSV file created by Export-UsersAndGroups.ps1 and recreates
    the users, groups, and group memberships on the target computer.

.PARAMETER InputPath
    The path to the CSV file containing the exported user and group data.

.PARAMETER DefaultPassword
    The default password to assign to imported users as a SecureString. If not provided, a random password will be generated.

.PARAMETER SkipExisting
    If specified, existing users and groups will be skipped instead of updated.

.PARAMETER GroupsOnly
    If specified, only groups will be created without creating any users or adding users to groups.
    This is useful when you only want to create the group structure without user accounts.

.PARAMETER LogPath
    Path for the import log file. Default is "ImportLog.txt" in the current directory.

.NOTES
    This script supports adding both local and domain users to local groups.
    For domain users, the script will attempt to resolve the correct format automatically.
    Domain users can be specified as either 'username' or 'DOMAIN\username' format.

.EXAMPLE
    $SecurePass = ConvertTo-SecureString "TempPass123!" -AsPlainText -Force
    .\Import-UsersAndGroups.ps1 -InputPath "C:\Backup\users.csv" -DefaultPassword $SecurePass

.EXAMPLE
    .\Import-UsersAndGroups.ps1 -InputPath "users.csv" -SkipExisting

.EXAMPLE
    # Import only groups without any users
    .\Import-UsersAndGroups.ps1 -InputPath "users.csv" -GroupsOnly

.EXAMPLE
    # Import with domain users in group memberships
    .\Import-UsersAndGroups.ps1 -InputPath "users.csv"
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$InputPath,
    
    [SecureString]$DefaultPassword,
    
    [switch]$SkipExisting,
    
    [switch]$GroupsOnly,
    
    [string]$LogPath = ".\ImportLog.txt"
)

# Function to generate a random password
function New-RandomPassword {
    param([int]$Length = 12)
    
    $Characters = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#$%^&*"
    $Random = 1..$Length | ForEach-Object { Get-Random -Maximum $Characters.Length }
    return -join ($Random | ForEach-Object { $Characters[$_] })
}

# Function to write log entries
function Write-Log {
    param($Message, $Level = "INFO")
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "[$Timestamp] [$Level] $Message"
    Write-Host $LogEntry
    Add-Content -Path $LogPath -Value $LogEntry
}

# Function to safely create or update user
function Import-User {
    param($UserData, [SecureString]$Password)
    
    try {
        $ExistingUser = Get-LocalUser -Name $UserData.Name -ErrorAction SilentlyContinue
        
        if ($ExistingUser -and $SkipExisting) {
            Write-Log "User '$($UserData.Name)' already exists, skipping due to -SkipExisting flag" "WARNING"
            return $false
        }
        
        if ($ExistingUser) {
            # Update existing user
            Write-Log "Updating existing user: $($UserData.Name)"
            
            $UpdateParams = @{}
            if ($UserData.FullName) { $UpdateParams.FullName = $UserData.FullName }
            if ($UserData.Description) { $UpdateParams.Description = $UserData.Description }
            
            if ($UpdateParams.Count -gt 0) {
                Set-LocalUser -Name $UserData.Name @UpdateParams
            }
            
            # Set user enabled/disabled state
            if ($UserData.Enabled -eq $true) {
                Enable-LocalUser -Name $UserData.Name
            } elseif ($UserData.Enabled -eq $false) {
                Disable-LocalUser -Name $UserData.Name
            }
            
            Write-Log "User '$($UserData.Name)' updated successfully"
        }
        else {
            # Create new user
            Write-Log "Creating new user: $($UserData.Name)"
            
            $CreateParams = @{
                Name = $UserData.Name
                Password = $Password
                PasswordNeverExpires = $true
            }
            
            if ($UserData.FullName) { $CreateParams.FullName = $UserData.FullName }
            if ($UserData.Description) { $CreateParams.Description = $UserData.Description }
            
            New-LocalUser @CreateParams
            
            # Set user enabled/disabled state
            if ($UserData.Enabled -eq $false) {
                Disable-LocalUser -Name $UserData.Name
            }
            
            Write-Log "User '$($UserData.Name)' created successfully"
        }
        
        return $true
    }
    catch {
        Write-Log "Failed to import user '$($UserData.Name)': $($_.Exception.Message)" "ERROR"
        return $false
    }
}

# Function to safely create or update group
function Import-Group {
    param($GroupData)
    
    try {
        $ExistingGroup = Get-LocalGroup -Name $GroupData.Name -ErrorAction SilentlyContinue
        
        if ($ExistingGroup -and $SkipExisting) {
            Write-Log "Group '$($GroupData.Name)' already exists, skipping due to -SkipExisting flag" "WARNING"
            return $false
        }
        
        if ($ExistingGroup) {
            # Update existing group
            Write-Log "Updating existing group: $($GroupData.Name)"
            
            if ($GroupData.Description) {
                Set-LocalGroup -Name $GroupData.Name -Description $GroupData.Description
            }
            
            Write-Log "Group '$($GroupData.Name)' updated successfully"
        }
        else {
            # Create new group
            Write-Log "Creating new group: $($GroupData.Name)"
            
            $CreateParams = @{
                Name = $GroupData.Name
            }
            
            if ($GroupData.Description) { $CreateParams.Description = $GroupData.Description }
            
            New-LocalGroup @CreateParams
            Write-Log "Group '$($GroupData.Name)' created successfully"
        }
        
        return $true
    }
    catch {
        Write-Log "Failed to import group '$($GroupData.Name)': $($_.Exception.Message)" "ERROR"
        return $false
    }
}

# Function to add user to groups (supports both local and domain users)
function Set-UserGroupMemberships {
    param($UserData)
    
    if (-not $UserData.GroupMembership) {
        return
    }
    
    $Groups = $UserData.GroupMembership -split ";"
    
    foreach ($GroupName in $Groups) {
        if ([string]::IsNullOrWhiteSpace($GroupName)) { continue }
        
        try {
            # Check if group exists
            $Group = Get-LocalGroup -Name $GroupName -ErrorAction SilentlyContinue
            if (-not $Group) {
                Write-Log "Group '$GroupName' does not exist, skipping membership for user '$($UserData.Name)'" "WARNING"
                continue
            }
            
            # Determine the correct user identifier for membership check
            $UserIdentifiers = @(
                $UserData.Name,
                "$env:COMPUTERNAME\$($UserData.Name)"
            )
            
            # If the username contains a domain (domain\username), also check for that format
            if ($UserData.Name -match '\\') {
                $UserIdentifiers += $UserData.Name
            } else {
                # Also check if it might be a domain user by trying domain\username format
                $UserIdentifiers += "$env:USERDOMAIN\$($UserData.Name)"
            }
            
            # Check if user is already a member using any of the possible identifiers
            $ExistingMember = Get-LocalGroupMember -Group $GroupName -ErrorAction SilentlyContinue | 
                Where-Object { $UserIdentifiers -contains $_.Name }
            
            if (-not $ExistingMember) {
                # Try to add the user - let PowerShell resolve the correct format
                try {
                    Add-LocalGroupMember -Group $GroupName -Member $UserData.Name
                    Write-Log "Added user '$($UserData.Name)' to group '$GroupName'"
                } catch {
                    # If direct add fails and it's not a domain\username format, try with domain prefix
                    if (-not ($UserData.Name -match '\\')) {
                        try {
                            $DomainUser = "$env:USERDOMAIN\$($UserData.Name)"
                            Add-LocalGroupMember -Group $GroupName -Member $DomainUser
                            Write-Log "Added domain user '$DomainUser' to group '$GroupName'"
                        } catch {
                            Write-Log "Failed to add user '$($UserData.Name)' or '$DomainUser' to group '$GroupName': $($_.Exception.Message)" "ERROR"
                        }
                    } else {
                        Write-Log "Failed to add user '$($UserData.Name)' to group '$GroupName': $($_.Exception.Message)" "ERROR"
                    }
                }
            }
            else {
                Write-Log "User '$($UserData.Name)' is already a member of group '$GroupName'"
            }
        }
        catch {
            Write-Log "Failed to process group membership for user '$($UserData.Name)' in group '$GroupName': $($_.Exception.Message)" "ERROR"
        }
    }
}

# Main script execution
Write-Log "Starting import of users and groups from: $InputPath"

# Validate input file
if (-not (Test-Path $InputPath)) {
    Write-Log "Input file not found: $InputPath" "ERROR"
    exit 1
}

# Set default password if not provided
if (-not $DefaultPassword) {
    $PlainPassword = New-RandomPassword
    $DefaultPassword = ConvertTo-SecureString -String $PlainPassword -AsPlainText -Force
    Write-Log "Generated random default password for new users"
} else {
    # Convert SecureString back to plain text for logging (only for display)
    $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($DefaultPassword)
    $PlainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
    [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)
}

try {
    # Import CSV data
    Write-Log "Reading CSV data..."
    $ImportData = Import-Csv -Path $InputPath
    
    if (-not $ImportData) {
        Write-Log "No data found in CSV file" "ERROR"
        exit 1
    }
    
    Write-Log "Found $($ImportData.Count) records in CSV file"
    
    # Separate users and groups
    $Users = $ImportData | Where-Object { $_.Type -eq "User" }
    $Groups = $ImportData | Where-Object { $_.Type -eq "Group" }
    
    Write-Log "Users to import: $($Users.Count)"
    Write-Log "Groups to import: $($Groups.Count)"
    
    # Import groups first
    Write-Log "Importing groups..."
    $GroupsImported = 0
    foreach ($Group in $Groups) {
        if (Import-Group -GroupData $Group) {
            $GroupsImported++
        }
    }
    
    # Import users (unless GroupsOnly is specified)
    $UsersImported = 0
    if (-not $GroupsOnly) {
        Write-Log "Importing users..."
        foreach ($User in $Users) {
            if (Import-User -UserData $User -Password $DefaultPassword) {
                $UsersImported++
            }
        }
    } else {
        Write-Log "Skipping user creation (GroupsOnly parameter specified)" "INFO"
    }
    
    # Set group memberships (unless GroupsOnly is specified)
    if (-not $GroupsOnly) {
        Write-Log "Setting group memberships..."
        foreach ($User in $Users) {
            Set-UserGroupMemberships -UserData $User
        }
    } else {
        Write-Log "Skipping group membership assignments (GroupsOnly parameter specified)" "INFO"
    }
    
    # Final summary
    Write-Log "Import completed!" "SUCCESS"
    Write-Log "Groups imported/updated: $GroupsImported of $($Groups.Count)"
    
    if (-not $GroupsOnly) {
        Write-Log "Users imported/updated: $UsersImported of $($Users.Count)"
        Write-Log "Default password used for new users: [SecureString - length $($PlainPassword.Length) characters]"
        
        Write-Host "`nIMPORTANT: Please change the default passwords for imported users!" -ForegroundColor Red -BackgroundColor Yellow
        Write-Host "Default password used: $PlainPassword" -ForegroundColor Yellow
    } else {
        Write-Log "Users skipped (GroupsOnly parameter specified)"
    }
    
    Write-Log "Log file saved to: $LogPath"
    
}
catch {
    Write-Log "Critical error during import: $($_.Exception.Message)" "ERROR"
    exit 1
}
