# Import-FolderPermissions.ps1
# This script imports folder permissions from a CSV file and applies them to specified folders
# Usage: .\Import-FolderPermissions.ps1 -CsvFile "C:\Path\To\Permissions.csv" -TargetBasePath "C:\Target\Path"

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
    [switch]$SkipSIDs
)

# Set default values for switch parameters
if (-not $PSBoundParameters.ContainsKey('UseLocalPrincipals')) {
    $UseLocalPrincipals = $true
}

if (-not $PSBoundParameters.ContainsKey('SkipSIDs')) {
    $SkipSIDs = $true
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

# Function to extract account name from identity reference
function Get-AccountNameFromIdentityReference {
    param (
        [string]$IdentityReference
    )
    
    # Check if the identity reference is a SID
    if (Test-IsSID -IdentityReference $IdentityReference) {
        return $IdentityReference
    }
    
    # Check if the identity reference contains a domain or computer name
    if ($IdentityReference -match '\\') {
        # Extract just the account name (after the backslash)
        return $IdentityReference.Split('\\')[-1]
    }
    
    # If no domain/computer prefix, return as is
    return $IdentityReference
}

# Function to apply permissions to a folder
function Set-FolderPermission {
    param (
        [string]$OriginalPath,
        [string]$TargetBasePath,
        [string]$IdentityReference,
        [string]$AccessControlType,
        [string]$FileSystemRights,
        [bool]$IsInherited,
        [string]$InheritanceFlags,
        [string]$PropagationFlags,
        [bool]$WhatIf,
        [bool]$UseLocalPrincipals,
        [bool]$SkipSIDs
    )
    
    # Determine the relative path from the original base path
    $originalBasePath = Split-Path -Path $OriginalPath -Parent
    $folderName = Split-Path -Path $OriginalPath -Leaf
    
    # If it's a root folder (no parent), use the folder name directly
    if ([string]::IsNullOrEmpty($folderName)) {
        $folderName = $originalBasePath
    }
    
    # Construct the new target path
    $targetPath = Join-Path -Path $TargetBasePath -ChildPath $folderName
    
    # Check if the target folder exists
    if (-not (Test-Path -Path $targetPath)) {
        Write-Warning "Target folder does not exist: $targetPath"
        return
    }
    
    # Check if the identity reference is a SID and skip if requested
    if ($SkipSIDs -and (Test-IsSID -IdentityReference $IdentityReference)) {
        Write-Host "Skipping SID: $IdentityReference for folder: $targetPath" -ForegroundColor Yellow
        return
    }
    
    try {
        # Create a new FileSystemAccessRule
        $accessControlType = [System.Security.AccessControl.AccessControlType]::$AccessControlType
        $fileSystemRights = [System.Security.AccessControl.FileSystemRights]$FileSystemRights
        $inheritanceFlags = [System.Security.AccessControl.InheritanceFlags]$InheritanceFlags
        $propagationFlags = [System.Security.AccessControl.PropagationFlags]$PropagationFlags
        
        # Determine the identity reference to use
        $identityToUse = $IdentityReference
        
        if ($UseLocalPrincipals) {
            # Extract just the account name without domain
            $accountName = Get-AccountNameFromIdentityReference -IdentityReference $IdentityReference
            
            # For well-known SIDs like 'Everyone', 'SYSTEM', etc., use them as is
            $wellKnownAccounts = @('Everyone', 'SYSTEM', 'Administrators', 'Users', 'Authenticated Users')
            
            if ($wellKnownAccounts -contains $accountName) {
                # Use the account name directly for well-known accounts
                $identityToUse = $accountName
            } else {
                # For other accounts, use the local computer name with the account
                $computerName = $env:COMPUTERNAME
                $identityToUse = "$computerName\$accountName"
            }
        }
        
        # Create the access rule with the appropriate identity
        $accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
            $identityToUse,
            $fileSystemRights,
            $inheritanceFlags,
            $propagationFlags,
            $accessControlType
        )
        
        if ($WhatIf) {
            if ($UseLocalPrincipals -and ($identityToUse -ne $IdentityReference)) {
                Write-Host "WhatIf: Would apply permission to $targetPath for $identityToUse (original: $IdentityReference)"
            } else {
                Write-Host "WhatIf: Would apply permission to $targetPath for $identityToUse"
            }
        } else {
            # Get the current ACL
            $acl = Get-Acl -Path $targetPath
            
            # Add the new rule
            $acl.AddAccessRule($accessRule)
            
            # Apply the ACL to the folder
            Set-Acl -Path $targetPath -AclObject $acl
            
            if ($UseLocalPrincipals -and ($identityToUse -ne $IdentityReference)) {
                Write-Host "Applied permission to $targetPath for $identityToUse (original: $IdentityReference)"
            } else {
                Write-Host "Applied permission to $targetPath for $identityToUse"
            }
        }
    }
    catch {
        Write-Error "Error applying permission to $targetPath : $_"
    }
}

try {
    # Import the CSV file
    $permissions = Import-Csv -Path $CsvFile
    
    Write-Host "Imported $($permissions.Count) permission entries from $CsvFile"
    
    # Process each permission entry
    foreach ($permission in $permissions) {
        Write-Host "Processing permission for folder: $($permission.FolderPath)"
        
        Set-FolderPermission `
            -OriginalPath $permission.FolderPath `
            -TargetBasePath $TargetBasePath `
            -IdentityReference $permission.IdentityReference `
            -AccessControlType $permission.AccessControlType `
            -FileSystemRights $permission.FileSystemRights `
            -IsInherited ([System.Convert]::ToBoolean($permission.IsInherited)) `
            -InheritanceFlags $permission.InheritanceFlags `
            -PropagationFlags $permission.PropagationFlags `
            -WhatIf $WhatIf `
            -UseLocalPrincipals $UseLocalPrincipals `
            -SkipSIDs $SkipSIDs
    }
    
    Write-Host "Permission import completed."
}
catch {
    Write-Error "An error occurred: $_"
    exit 1
}
