## Remove-FolderPermissions.ps1

This script removes permissions not listed in a CSV file from folders at a specified target location.

### Usage

```powershell
.\Remove-FolderPermissions.ps1 -CsvFile "C:\Path\To\Permissions.csv" -TargetBasePath "C:\Target\Path"
```

### Parameters

- `-CsvFile`: The path to the CSV file containing the permissions
- `-TargetBasePath`: The base path where the folders are located on the target system
- `-WhatIf`: If specified, shows what would happen without actually removing permissions
- `-UseLocalPrincipals`: If specified, the script will use local security principals on the target computer (enabled by default)
- `-SkipSIDs`: If specified, the script will skip any permissions with SIDs (enabled by default)
- `-SkipUsers`: If specified, the script will skip individual user accounts (enabled by default)
- `-SkipInheritedPermissions`: If specified, the script will skip inherited permissions (enabled by default)
