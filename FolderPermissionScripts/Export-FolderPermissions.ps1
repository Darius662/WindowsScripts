# Export-FolderPermissions.ps1
# This script exports folder permissions to a CSV file
# Usage: .\Export-FolderPermissions.ps1 -FolderPath "C:\Path\To\Folders" -OutputFile "C:\Path\To\Output.csv" [-Depth <int>]

param (
    [Parameter(Mandatory=$true)]
    [string]$FolderPath,
    
    [Parameter(Mandatory=$true)]
    [string]$OutputFile,
    
    [Parameter(Mandatory=$false)]
    [int]$Depth = 0
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

# Function to get all folders recursively
function Get-AllFolders {
    param (
        [string]$Path,
        [int]$CurrentDepth,
        [int]$MaxDepth
    )
    
    $folders = @($Path)
    
    if ($MaxDepth -eq 0 -or $CurrentDepth -lt $MaxDepth) {
        $subfolders = Get-ChildItem -Path $Path -Directory -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName
        foreach ($subfolder in $subfolders) {
            $folders += Get-AllFolders -Path $subfolder -CurrentDepth ($CurrentDepth + 1) -MaxDepth $MaxDepth
        }
    }
    
    return $folders
}

# Main script execution
try {
    # Get all folders with depth control
    $folders = Get-AllFolders -Path $FolderPath -CurrentDepth 1 -MaxDepth $Depth
    Write-Host "Found $($folders.Count) folders to process (Depth: $(if ($Depth -eq 0) {'unlimited'} else {$Depth}))"
    
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
