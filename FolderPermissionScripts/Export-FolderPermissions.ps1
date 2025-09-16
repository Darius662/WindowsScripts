# Export-FolderPermissions.ps1
# This script exports folder permissions to a CSV file
# Usage: .\Export-FolderPermissions.ps1 -FolderPath "C:\Path\To\Folders" -OutputFile "C:\Path\To\Output.csv"

param (
    [Parameter(Mandatory=$true)]
    [string]$FolderPath,
    
    [Parameter(Mandatory=$true)]
    [string]$OutputFile
)

# Check if the folder path exists
if (-not (Test-Path -Path $FolderPath)) {
    Write-Error "The specified folder path does not exist: $FolderPath"
    exit 1
}

# Function to get folder permissions
function Get-FolderPermissions {
    param (
        [string]$Path
    )
    
    try {
        # Get the ACL for the folder
        $acl = Get-Acl -Path $Path
        
        # Get all access rules
        $accessRules = $acl.Access
        
        $permissions = @()
        
        foreach ($rule in $accessRules) {
            $permissions += [PSCustomObject]@{
                FolderPath = $Path
                IdentityReference = $rule.IdentityReference.Value
                AccessControlType = $rule.AccessControlType.ToString()
                FileSystemRights = $rule.FileSystemRights.ToString()
                IsInherited = $rule.IsInherited
                InheritanceFlags = $rule.InheritanceFlags.ToString()
                PropagationFlags = $rule.PropagationFlags.ToString()
            }
        }
        
        return $permissions
    }
    catch {
        Write-Error "Error getting permissions for $Path : $_"
        return $null
    }
}

# Get all folders in the specified path (only top-level, not subfolders)
try {
    $folders = Get-ChildItem -Path $FolderPath -Directory | Select-Object -ExpandProperty FullName
    
    # Add the root folder itself
    $folders = @($FolderPath) + $folders
    
    Write-Host "Found $($folders.Count) folders to process."
    
    # Process each folder and collect permissions
    $allPermissions = @()
    
    foreach ($folder in $folders) {
        Write-Host "Processing folder: $folder"
        $folderPermissions = Get-FolderPermissions -Path $folder
        if ($folderPermissions) {
            $allPermissions += $folderPermissions
        }
    }
    
    # Export to CSV
    $allPermissions | Export-Csv -Path $OutputFile -NoTypeInformation
    
    Write-Host "Permissions exported successfully to $OutputFile"
}
catch {
    Write-Error "An error occurred: $_"
    exit 1
}
