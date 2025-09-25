# Folder Permissions Management Scripts

This project contains two PowerShell scripts for exporting and importing folder permissions:

1. `Export-FolderPermissions.ps1` - Exports permissions from folders to a CSV file
2. `Import-FolderPermissions.ps1` - Imports permissions from a CSV file and applies them to folders

## Export-FolderPermissions.ps1

This script exports the permissions of a specified folder and its immediate subfolders (not recursive) to a CSV file.

### Usage

```powershell
.\Export-FolderPermissions.ps1 -FolderPath "C:\Path\To\Folders" -OutputFile "C:\Path\To\Output.csv"
```

### Parameters

- `-FolderPath`: The path to the parent folder containing the folders whose permissions you want to export
- `-OutputFile`: The path where the CSV file will be saved

## Import-FolderPermissions.ps1

This script imports permissions from a CSV file (created by the export script) and applies them to folders at a specified target location.

### Usage

```powershell
.\Import-FolderPermissions.ps1 -CsvFile "C:\Path\To\Permissions.csv" -TargetBasePath "C:\Target\Path"
```

### Parameters

- `-CsvFile`: The path to the CSV file containing the permissions
- `-TargetBasePath`: The base path where the folders are located on the target system
- `-WhatIf`: If specified, shows what would happen without actually applying the permissions
- `-UseLocalPrincipals`: If specified, the script will use local security principals on the target computer instead of trying to use the exact security principals from the source computer (enabled by default)
- `-SkipSIDs`: If specified, the script will skip any permissions with SIDs (Security Identifiers) that typically come from deleted or legacy accounts (enabled by default)
- `-SkipUsers`: If specified, the script will skip individual user accounts and only apply group permissions (enabled by default)
- `-SkipInheritedPermissions`: If specified, the script will skip applying permissions that already exist through inheritance from parent folders (enabled by default)

## Example Workflow

1. On the source computer:
   ```powershell
   .\Export-FolderPermissions.ps1 -FolderPath "D:\Projects" -OutputFile "D:\permissions.csv"
   ```

2. Transfer the CSV file to the target computer

3. On the target computer:
   ```powershell
   # First, test with WhatIf to see what would happen
   .\Import-FolderPermissions.ps1 -CsvFile "E:\permissions.csv" -TargetBasePath "E:\Projects" -WhatIf
   
   # Then apply the permissions (skips SIDs, user accounts, and inherited permissions by default)
   .\Import-FolderPermissions.ps1 -CsvFile "E:\permissions.csv" -TargetBasePath "E:\Projects"
   
   # If you want to include SIDs (not recommended for legacy SIDs)
   .\Import-FolderPermissions.ps1 -CsvFile "E:\permissions.csv" -TargetBasePath "E:\Projects" -SkipSIDs:$false
   
   # If you want to include individual user accounts
   .\Import-FolderPermissions.ps1 -CsvFile "E:\permissions.csv" -TargetBasePath "E:\Projects" -SkipUsers:$false
   
   # If you want to apply permissions even if they already exist through inheritance
   .\Import-FolderPermissions.ps1 -CsvFile "E:\permissions.csv" -TargetBasePath "E:\Projects" -SkipInheritedPermissions:$false
   
   # If you want to include both SIDs and user accounts
   .\Import-FolderPermissions.ps1 -CsvFile "E:\permissions.csv" -TargetBasePath "E:\Projects" -SkipSIDs:$false -SkipUsers:$false
   ```

## Notes

- The scripts handle permissions at the folder level only, not for files
- The export script captures the parent folder and its immediate subfolders only (not recursive)
- The import script maps permissions based on folder names, so the folder structure should be similar between source and target
- Security principals (users/groups) are handled as follows:
  - By default, the import script uses local security principals on the target computer
  - For example, if the source has "DOMAIN1\Group1", the script will apply "TARGETCOMPUTER\Group1" on the target
  - Well-known accounts like "Everyone", "SYSTEM", "Administrators", etc. are preserved as-is
  - You can disable this behavior with `-UseLocalPrincipals:$false` to attempt using the exact security principals from the source
- SID handling:
  - Security Identifiers (SIDs) from old/deleted accounts are skipped by default
  - These typically appear when accounts or groups that previously had permissions no longer exist
  - The script will display a yellow message when skipping a SID
  - If you need to include these legacy SIDs for some reason, use `-SkipSIDs:$false`
- User account handling:
  - Individual user accounts are skipped by default, focusing only on group permissions
  - This helps maintain a cleaner permission structure on the target system
  - The script uses heuristics to identify user accounts vs. groups based on naming patterns:
    - Groups with common prefixes (GRP_, G_, Role_, etc.)
    - Groups containing keywords like "Users", "Groups", "Admins", etc. (e.g., "PD_Users_Technical")
    - Groups with multiple underscore segments in their names
    - Well-known built-in groups
  - User accounts are typically identified by dot notation (firstname.lastname)
  - If you need to include individual user permissions, use `-SkipUsers:$false`
- Inherited permissions handling:
  - The script automatically detects and skips applying permissions that already exist through inheritance
  - This prevents duplicate permissions and maintains a cleaner permission structure
  - When a permission already exists through inheritance, the script will display a cyan message and skip applying it
  - This is particularly useful for subfolders that inherit permissions from parent folders
- Error handling:
  - The script gracefully handles unmappable identity references (accounts/groups that don't exist on the target system)
  - When an identity can't be mapped, the script will display a yellow warning message and continue processing other permissions
  - This prevents the script from failing when encountering invalid or non-existent accounts
