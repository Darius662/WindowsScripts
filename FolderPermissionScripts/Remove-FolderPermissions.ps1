# Remove-FolderPermissions.ps1
# This script removes folder permissions that are not listed in the specified CSV file
# Usage: .\Remove-FolderPermissions.ps1 -CsvFile "C:\Path\To\Permissions.csv" -TargetBasePath "C:\Target\Path"

param (
    [Parameter(Mandatory=$true)]
    [string]$CsvFile,
    
    [Parameter(Mandatory=$true)]
    [string]$TargetBasePath,
    
    [Parameter(Mandatory=$false)]
    [switch]$WhatIf,
    
    [Parameter(Mandatory=$false)]
    [switch]$UseLocalPrincipals,
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipSIDs,
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipUsers,
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipInheritedPermissions
)

# Set default values for switch parameters
if (-not $PSBoundParameters.ContainsKey('UseLocalPrincipals')) {
    $UseLocalPrincipals = $true
}

if (-not $PSBoundParameters.ContainsKey('SkipSIDs')) {
    $SkipSIDs = $true
}

if (-not $PSBoundParameters.ContainsKey('SkipUsers')) {
    $SkipUsers = $true
}

if (-not $PSBoundParameters.ContainsKey('SkipInheritedPermissions')) {
    $SkipInheritedPermissions = $true
}

# Check if the CSV file exists
if (-not (Test-Path -Path $CsvFile)) {
    Write-Error "The specified CSV file does not exist: $CsvFile"
    exit 1
}

# Check if the target base path exists
if (-not (Test-Path -Path $TargetBasePath)) {
    Write-Error "The specified target base path does not exist: $TargetBasePath"
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

# Function to check if a permission is in the allowed list
function Test-PermissionInList {
    param (
        [array]$AllowedPermissions,
        [string]$FolderPath,
        [string]$IdentityReference,
        [System.Security.AccessControl.AccessControlType]$AccessControlType,
        [System.Security.AccessControl.FileSystemRights]$FileSystemRights,
        [System.Security.AccessControl.InheritanceFlags]$InheritanceFlags,
        [System.Security.AccessControl.PropagationFlags]$PropagationFlags
    )
    
    foreach ($perm in $AllowedPermissions) {
        $permAccountName = Get-AccountNameFromIdentityReference -IdentityReference $perm.IdentityReference
        $currentAccountName = Get-AccountNameFromIdentityReference -IdentityReference $IdentityReference
        
        if ($perm.FolderPath -eq $FolderPath -and 
            $permAccountName -eq $currentAccountName -and 
            $perm.AccessControlType -eq $AccessControlType.ToString() -and 
            $perm.FileSystemRights -eq $FileSystemRights.ToString() -and 
            $perm.InheritanceFlags -eq $InheritanceFlags.ToString() -and 
            $perm.PropagationFlags -eq $PropagationFlags.ToString()) {
            return $true
        }
    }
    
    return $false
}

# Function to remove permissions not in the allowed list
function Remove-UnauthorizedPermissions {
    param (
        [string]$FolderPath,
        [array]$AllowedPermissions,
        [bool]$WhatIf,
        [bool]$UseLocalPrincipals,
        [bool]$SkipSIDs,
        [bool]$SkipUsers,
        [bool]$SkipInheritedPermissions
    )
    
    try {
        # Get the current ACL
        $acl = Get-Acl -Path $FolderPath
        
        # Create a list to store rules to remove
        $rulesToRemove = @()
        
        # Check each access rule
        foreach ($rule in $acl.Access) {
            # Skip inherited permissions if requested
            if ($SkipInheritedPermissions -and $rule.IsInherited) {
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
            
            # Check if this permission is in the allowed list
            $isAllowed = Test-PermissionInList -AllowedPermissions $AllowedPermissions `
                -FolderPath $FolderPath `
                -IdentityReference $rule.IdentityReference.Value `
                -AccessControlType $rule.AccessControlType `
                -FileSystemRights $rule.FileSystemRights `
                -InheritanceFlags $rule.InheritanceFlags `
                -PropagationFlags $rule.PropagationFlags
            
            if (-not $isAllowed) {
                $rulesToRemove += $rule
            }
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
    # Import the CSV file with allowed permissions
    $allowedPermissions = Import-Csv -Path $CsvFile
    
    Write-Host "Imported $($allowedPermissions.Count) allowed permission entries from $CsvFile"
    
    # Get all unique folder paths from the CSV
    $uniqueFolders = $allowedPermissions | Select-Object -ExpandProperty FolderPath -Unique
    
    # Process each folder
    foreach ($folder in $uniqueFolders) {
        # Construct the target path
        $folderName = Split-Path -Path $folder -Leaf
        $targetPath = Join-Path -Path $TargetBasePath -ChildPath $folderName
        
        # Check if the target folder exists
        if (-not (Test-Path -Path $targetPath)) {
            Write-Warning "Target folder does not exist: $targetPath"
            continue
        }
        
        Write-Host "Processing permissions for folder: $targetPath"
        
        # Remove unauthorized permissions
        Remove-UnauthorizedPermissions `
            -FolderPath $targetPath `
            -AllowedPermissions $allowedPermissions `
            -WhatIf $WhatIf `
            -UseLocalPrincipals $UseLocalPrincipals `
            -SkipSIDs $SkipSIDs `
            -SkipUsers $SkipUsers `
            -SkipInheritedPermissions $SkipInheritedPermissions
    }
    
    Write-Host "Permission removal completed."
}
catch {
    Write-Error "An error occurred: $_"
    exit 1
}
