# Import-FolderPermissions.ps1
# This script imports folder permissions from a CSV file and applies them to specified folders
# Usage: .\Import-FolderPermissions.ps1 -CsvFile "C:\Path\To\Permissions.csv" -TargetBasePath "C:\Target\Path"

param (
    [Parameter(Mandatory=$true)]
    [string]$CsvFile,
    
    [Parameter(Mandatory=$true)]
    [string]$TargetBasePath,
    
    [Parameter(Mandatory=$false)]
    [switch]$WhatIf = $false
)

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
        [bool]$WhatIf
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
    
    try {
        # Create a new FileSystemAccessRule
        $accessControlType = [System.Security.AccessControl.AccessControlType]::$AccessControlType
        $fileSystemRights = [System.Security.AccessControl.FileSystemRights]$FileSystemRights
        $inheritanceFlags = [System.Security.AccessControl.InheritanceFlags]$InheritanceFlags
        $propagationFlags = [System.Security.AccessControl.PropagationFlags]$PropagationFlags
        
        $accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
            $IdentityReference,
            $fileSystemRights,
            $inheritanceFlags,
            $propagationFlags,
            $accessControlType
        )
        
        if ($WhatIf) {
            Write-Host "WhatIf: Would apply permission to $targetPath for $IdentityReference"
        } else {
            # Get the current ACL
            $acl = Get-Acl -Path $targetPath
            
            # Add the new rule
            $acl.AddAccessRule($accessRule)
            
            # Apply the ACL to the folder
            Set-Acl -Path $targetPath -AclObject $acl
            
            Write-Host "Applied permission to $targetPath for $IdentityReference"
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
            -WhatIf $WhatIf
    }
    
    Write-Host "Permission import completed."
}
catch {
    Write-Error "An error occurred: $_"
    exit 1
}
