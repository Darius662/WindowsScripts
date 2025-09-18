# Registry Settings Migration Scripts

This directory contains two PowerShell scripts for exporting and importing registry settings between Windows computers.

## Scripts Overview

### 1. Export-RegistrySettings.ps1
Exports registry keys and values from specified paths to a CSV file, capturing all relevant properties including key paths, value names, types, and data.

### 2. Import-RegistrySettings.ps1
Imports registry settings from the CSV file to recreate them on the target computer with all their original properties.

## Prerequisites

- **Administrator privileges** required on both source and target computers
- PowerShell 5.1 or later
- Windows 10/11 or Windows Server 2016+

## Usage

### Step 1: Export from Source Computer

```powershell
# Run as Administrator
.\Export-RegistrySettings.ps1 -RegistryPaths "HKCU:\Software\Microsoft\Office" -OutputPath "C:\Backup\registry.csv" -Recurse
```

**Parameters:**
- `-RegistryPaths` (required): Array of registry paths to export (supports HKLM, HKCU, HKCR, HKU, HKCC)
- `-OutputPath` (optional): Path where the CSV file will be saved. Default: `.\RegistryExport.csv`
- `-Recurse` (optional): Export registry keys recursively (including all subkeys)
- `-ExcludePaths` (optional): Array of registry paths to exclude from the export
- `-IncludeEmptyValues` (optional): Include registry keys with no values in the export

**Examples:**
```powershell
# Export a single registry key
.\Export-RegistrySettings.ps1 -RegistryPaths "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" -OutputPath "startup.csv"

# Export multiple registry paths
.\Export-RegistrySettings.ps1 -RegistryPaths @("HKCU:\Software\Microsoft\Office", "HKLM:\SOFTWARE\Policies\Microsoft\Windows") -OutputPath "settings.csv"

# Export recursively with exclusions
.\Export-RegistrySettings.ps1 -RegistryPaths "HKLM:\SOFTWARE\Microsoft" -Recurse -ExcludePaths "HKLM:\SOFTWARE\Microsoft\Windows NT" -OutputPath "microsoft_settings.csv"

# Include empty registry keys
.\Export-RegistrySettings.ps1 -RegistryPaths "HKCU:\Software\Microsoft\Office" -Recurse -IncludeEmptyValues
```

### Step 2: Transfer CSV File
Copy the generated CSV file to the target computer.

### Step 3: Import to Target Computer

```powershell
# Run as Administrator
.\Import-RegistrySettings.ps1 -InputPath "C:\Backup\registry.csv"
```

**Parameters:**
- `-InputPath` (required): Path to the CSV file created by the export script
- `-BackupPath` (optional): Path to save a backup of existing registry keys before importing
- `-SkipExisting` (optional): Skip existing registry values instead of replacing them
- `-FilterKeyPath` (optional): Import only registry keys that match the specified path pattern
- `-LogPath` (optional): Path for the import log file. Default: `.\RegistryImport.log`

**Examples:**
```powershell
# Basic import
.\Import-RegistrySettings.ps1 -InputPath "registry.csv"

# Import with backup of existing keys
.\Import-RegistrySettings.ps1 -InputPath "registry.csv" -BackupPath "registry_backup.csv"

# Skip existing registry values
.\Import-RegistrySettings.ps1 -InputPath "registry.csv" -SkipExisting

# Import only specific registry keys
.\Import-RegistrySettings.ps1 -InputPath "registry.csv" -FilterKeyPath "HKCU:\Software\Microsoft\Office"

# Custom log file location
.\Import-RegistrySettings.ps1 -InputPath "registry.csv" -LogPath "C:\Logs\registry_import.log"
```

## What Gets Migrated

The scripts capture and recreate the following registry properties:

### Registry Keys
- Full registry key paths
- Key structure (parent-child relationships)

### Registry Values
- Value names
- Value types (String, DWord, QWord, Binary, MultiString, ExpandString)
- Value data (properly converted based on type)

## Important Notes

### Security Considerations
- Some registry keys require elevated permissions to access
- Be careful when modifying system registry keys as it can affect system stability
- Always test imports on non-critical systems first
- Create backups before making changes to the registry

### Limitations
- Some registry keys may be locked by the system or applications
- Binary data with special formats may need additional processing
- Very large registry exports may require significant memory
- Some registry values may contain system-specific data that doesn't transfer well between computers

### Best Practices
1. **Test first**: Run on a test system before production migration
2. **Backup**: Always use the `-BackupPath` parameter when importing
3. **Be specific**: Export only the registry keys you need rather than large sections
4. **Verify**: Check all imported registry settings after migration
5. **Documentation**: Keep logs of the migration process

## Troubleshooting

### Common Issues

**"Access Denied" errors:**
- Ensure you're running PowerShell as Administrator
- Some registry keys are protected by the system and cannot be modified
- Check if the key is being used by another process

**"Registry key not found" warnings:**
- The target registry key structure may not exist on the target computer
- The script will attempt to create missing keys automatically

**Value type conversion issues:**
- If a value cannot be properly converted, check the CSV file for correct format
- Binary and MultiString values have special formatting requirements

### Log Files
The import script creates detailed logs at the specified location (default: `RegistryImport.log`). Check this file for detailed information about any issues.

### Verification Steps
After import, verify:
1. Registry keys exist: `Test-Path "HKCU:\Software\ImportedKey"`
2. Registry values are correct: `Get-ItemProperty -Path "HKCU:\Software\ImportedKey" -Name "ValueName"`
3. Applications using the imported settings work as expected

## Example Workflow

```powershell
# On source computer (as Administrator)
.\Export-RegistrySettings.ps1 -RegistryPaths "HKCU:\Software\MyApp" -Recurse -OutputPath "C:\Migration\myapp_settings.csv"

# Transfer file to target computer
# Copy myapp_settings.csv to target computer

# On target computer (as Administrator)
.\Import-RegistrySettings.ps1 -InputPath "C:\Migration\myapp_settings.csv" -BackupPath "C:\Backup\original_settings.csv"

# Verify import
Get-ChildItem -Path "HKCU:\Software\MyApp" -Recurse
```

## Support

For issues or questions:
1. Check the import log file for detailed error messages
2. Verify administrator privileges
3. Ensure PowerShell execution policy allows script execution:
   ```powershell
   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
   ```

## Version History

- **v1.0**: Initial release with basic export/import functionality
- Comprehensive error handling and logging
- Support for all standard registry value types
- Recursive registry key export/import
- Filtering and exclusion options
