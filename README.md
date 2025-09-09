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
- `-WhatIf` (optional): If specified, shows what would happen without actually applying the permissions

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
   
   # Then apply the permissions
   .\Import-FolderPermissions.ps1 -CsvFile "E:\permissions.csv" -TargetBasePath "E:\Projects"
   ```

## Notes

- The scripts handle permissions at the folder level only, not for files
- The export script captures the parent folder and its immediate subfolders only (not recursive)
- The import script maps permissions based on folder names, so the folder structure should be similar between source and target
