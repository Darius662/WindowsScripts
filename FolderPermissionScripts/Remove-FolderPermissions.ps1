# Remove-FolderPermissions.ps1
# This script removes all non-inherited folder permissions
# Usage: .\Remove-FolderPermissions.ps1 -FolderPath "C:\Path\To\Folder" [-Recursive] [-WhatIf] [-SkipSIDs] [-SkipUsers]

param (
    [Parameter(Mandatory=$true)]
    [string]$FolderPath,
    
    [Parameter(Mandatory=$false)]
    [switch]$Recursive,
    
    [Parameter(Mandatory=$false)]
    [switch]$WhatIf,
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipSIDs,
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipUsers
)

# Set default values for switch parameters
if (-not $PSBoundParameters.ContainsKey('SkipSIDs')) {
    $SkipSIDs = $true
}

if (-not $PSBoundParameters.ContainsKey('SkipUsers')) {
    $SkipUsers = $true
}

# Check if the folder path exists
if (-not (Test-Path -Path $FolderPath)) {
    Write-Error "The specified folder path does not exist: $FolderPath"
    exit 1
}

# Function to check if a string is a SID
function Test-IsSID {
    param (
        [string]$IdentityReference
    )
    
    # SID pattern: S-1-5-... (Security Identifier pattern)
    return $IdentityReference -match '^S-\d+-\d+(-\d+)*$'
}

# Function to check if an identity reference is a user account (not a group)
function Test-IsUserAccount {
    param (
        [string]$IdentityReference
    )
    
    # Skip if it's a SID
    if (Test-IsSID -IdentityReference $IdentityReference) {
        return $false
    }
    
    # Extract account name
    $accountName = Get-AccountNameFromIdentityReference -IdentityReference $IdentityReference
    
    # Well-known groups that should not be skipped
    $wellKnownGroups = @('Everyone', 'SYSTEM', 'Administrators', 'Users', 'Authenticated Users', 'Domain Users', 'Domain Admins')
    
    # If it's a well-known group, it's not a user account
    if ($wellKnownGroups -contains $accountName) {
        return $false
    }
    
    # Check for common group prefixes and patterns
    if ($accountName -match '^(GRP_|G_|Role_|Group_|Team_|Dept_|Department_|Admin_|Admins_)') {
        return $false  # Likely a group
    }
    
    # Check for common group patterns with Users in the name
    if ($accountName -match '(Users|Groups|Admins|Roles|Teams|Access|Permissions)') {
        return $false  # Likely a group
    }
    
    # Check for patterns with multiple underscores
    if (($accountName.Split('_').Count -gt 2) -and ($accountName -notmatch '\.')) {
        return $false  # Likely a group
    }
    
    # If it contains a dot, it's likely a user (firstname.lastname pattern)
    if ($accountName -match '\.') {
        return $true
    }
    
    return $true
}

# Function to extract account name from identity reference
function Get-AccountNameFromIdentityReference {
    param (
        [string]$IdentityReference
    )
    
    if (Test-IsSID -IdentityReference $IdentityReference) {
        return $IdentityReference
    }
    
    if ($IdentityReference -match '\\') {
        return $IdentityReference.Split('\\')[-1]
    }
    
    return $IdentityReference
}


# Function to remove all non-inherited permissions
function Remove-NonInheritedPermissions {
    param (
        [string]$FolderPath,
        [bool]$WhatIf,
        [bool]$SkipSIDs,
        [bool]$SkipUsers
    )
    
    try {
        # Get the current ACL
        $acl = Get-Acl -Path $FolderPath
        
        # Create a list to store rules to remove
        $rulesToRemove = @()
        
        # Check each access rule
        foreach ($rule in $acl.Access) {
            # Skip inherited permissions (always keep them)
            if ($rule.IsInherited) {
                continue
            }
            
            # Skip SIDs if requested
            if ($SkipSIDs -and (Test-IsSID -IdentityReference $rule.IdentityReference.Value)) {
                Write-Host "Skipping SID: $($rule.IdentityReference.Value) for folder: $FolderPath" -ForegroundColor Yellow
                continue
            }
            
            # Skip users if requested
            if ($SkipUsers -and (Test-IsUserAccount -IdentityReference $rule.IdentityReference.Value)) {
                Write-Host "Skipping user account: $($rule.IdentityReference.Value) for folder: $FolderPath" -ForegroundColor Yellow
                continue
            }
            
            # Add to removal list (we're removing all non-inherited permissions)
            $rulesToRemove += $rule
        }
        
        # Remove unauthorized rules
        if ($rulesToRemove.Count -gt 0) {
            if ($WhatIf) {
                Write-Host "WhatIf: Would remove $($rulesToRemove.Count) permissions from $FolderPath"
                foreach ($rule in $rulesToRemove) {
                    Write-Host "  - $($rule.IdentityReference.Value): $($rule.FileSystemRights)"
                }
            } else {
                foreach ($rule in $rulesToRemove) {
                    $acl.RemoveAccessRule($rule) | Out-Null
                    Write-Host "Removed permission from $FolderPath for $($rule.IdentityReference.Value): $($rule.FileSystemRights)"
                }
                
                # Apply the modified ACL
                Set-Acl -Path $FolderPath -AclObject $acl
            }
        }
    }
    catch {
        Write-Error "Error processing permissions for $FolderPath : $_"
    }
}

try {
    Write-Host "Starting permission removal for: $FolderPath"
    
    # Process the specified folder
    Remove-NonInheritedPermissions `
        -FolderPath $FolderPath `
        -WhatIf $WhatIf `
        -SkipSIDs $SkipSIDs `
        -SkipUsers $SkipUsers
    
    # If recursive option is selected, process all subfolders
    if ($Recursive) {
        Write-Host "Processing subfolders recursively..."
        $subFolders = Get-ChildItem -Path $FolderPath -Directory -Recurse
        
        foreach ($folder in $subFolders) {
            Write-Host "Processing permissions for subfolder: $($folder.FullName)"
            
            Remove-NonInheritedPermissions `
                -FolderPath $folder.FullName `
                -WhatIf $WhatIf `
                -SkipSIDs $SkipSIDs `
                -SkipUsers $SkipUsers
        }
    }
    
    Write-Host "Permission removal completed."
}
catch {
    Write-Error "An error occurred: $_"
    exit 1
}
