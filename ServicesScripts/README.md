# Windows Services Migration Scripts

This directory contains two PowerShell scripts for exporting and importing Windows services configuration between computers.

## Scripts Overview

### 1. Export-WindowsServices.ps1
Exports Windows services configuration from the source computer to a CSV file, capturing all relevant service properties including name, display name, description, path, startup type, logon account, dependencies, and recovery options.

### 2. Import-WindowsServices.ps1
Imports services configuration from the CSV file to update existing services or create new services on the target computer with all their original properties.

## Prerequisites

- **Administrator privileges** required on both source and target computers
- PowerShell 5.1 or later
- Windows 10/11 or Windows Server 2016+

## Usage

### Step 1: Export from Source Computer

```powershell
# Run as Administrator
.\Export-WindowsServices.ps1 -OutputPath "C:\Migration\services.csv"
```

**Parameters:**
- `-OutputPath` (optional): Path where the CSV file will be saved. Default: `.\ServicesExport.csv`
- `-IncludeSystemServices` (optional): Include system services in the export (by default, only non-system services are exported)
- `-IncludeDisabledServices` (optional): Include disabled services in the export (by default, only non-disabled services are exported)
- `-FilterByName` (optional): Filter services by name or display name (supports wildcards)
- `-FilterByStartupType` (optional): Filter services by startup type (Automatic, AutomaticDelayedStart, Manual, Disabled)

**Examples:**
```powershell
# Export all non-system services to default location
.\Export-WindowsServices.ps1

# Export to specific location
.\Export-WindowsServices.ps1 -OutputPath "D:\Backup\services.csv"

# Export including system services
.\Export-WindowsServices.ps1 -IncludeSystemServices

# Export only SQL Server related services
.\Export-WindowsServices.ps1 -FilterByName "SQL*"

# Export only automatic services
.\Export-WindowsServices.ps1 -FilterByStartupType "Automatic"

# Export only automatic delayed start services
.\Export-WindowsServices.ps1 -FilterByStartupType "AutomaticDelayedStart"
```

### Step 2: Transfer CSV File
Copy the generated CSV file to the target computer.

### Step 3: Import to Target Computer

```powershell
# Run as Administrator
.\Import-WindowsServices.ps1 -InputPath "C:\Migration\services.csv"
```

**Parameters:**
- `-InputPath` (required): Path to the CSV file created by the export script
- `-BackupPath` (optional): Path to save a backup of existing services before importing
- `-SkipExisting` (optional): Skip existing services instead of updating them
- `-CreateMissing` (optional): Create services that don't exist on the target computer
- `-ServicePassword` (optional): SecureString password for service accounts when creating or updating services
- `-LogPath` (optional): Path for the import log file. Default: `.\ServicesImport.log`

**Examples:**
```powershell
# Basic import (updates existing services only)
.\Import-WindowsServices.ps1 -InputPath "services.csv"

# Import with backup of existing services
.\Import-WindowsServices.ps1 -InputPath "services.csv" -BackupPath "services_backup.csv"

# Skip existing services
.\Import-WindowsServices.ps1 -InputPath "services.csv" -SkipExisting

# Create missing services with password for service accounts
$SecurePass = ConvertTo-SecureString "ServicePassword" -AsPlainText -Force
.\Import-WindowsServices.ps1 -InputPath "services.csv" -CreateMissing -ServicePassword $SecurePass

# Custom log file location
.\Import-WindowsServices.ps1 -InputPath "services.csv" -LogPath "C:\Logs\services_import.log"
```

## What Gets Migrated

The scripts capture and recreate the following service properties:

### Basic Properties
- Service name and display name
- Description
- Binary path (executable path)
- Startup type (Automatic, Manual, Disabled)
- Delayed auto-start setting
- Logon account

### Advanced Properties
- Service dependencies
- Recovery options (actions on failure)
- Service type
- Error control settings
- Load order group
- Desktop interaction settings

## Important Notes

### Security Considerations
- Service account passwords are not exported for security reasons
- When importing services with custom accounts, you must provide a password
- Some services may require specific permissions to be configured correctly
- System services should generally not be modified

### Limitations
- Some Windows system services cannot be fully recreated or modified
- Services that depend on hardware-specific drivers may not work properly when migrated
- Binary paths must be valid on the target computer
- Service account domains must be accessible on the target computer
- Recovery command paths must exist on the target computer

### Best Practices
1. **Test first**: Run on a test system before production migration
2. **Backup**: Always use the `-BackupPath` parameter when importing
3. **Filter**: Use filter parameters to export only the services you need
4. **Verify**: Check all imported services after migration
5. **Security**: Ensure service accounts have appropriate permissions

## Troubleshooting

### Common Issues

**"Access Denied" errors:**
- Ensure you're running PowerShell as Administrator
- Some Windows services are protected and cannot be modified
- Check if the service is currently running and cannot be stopped

**"Service already exists" warnings:**
- Use `-SkipExisting` to skip existing services
- Or allow the script to update existing services (default behavior)

**Service account issues:**
- Ensure the specified account exists on the target computer
- Provide a valid password using the `-ServicePassword` parameter
- Domain accounts require the domain to be accessible

**Binary path issues:**
- Ensure the executable path exists on the target computer
- Update paths manually if necessary after import

### Log Files
The import script creates detailed logs at the specified location (default: `ServicesImport.log`). Check this file for detailed information about any issues.

### Verification Steps
After import, verify:
1. Services exist: `Get-Service -Name "ServiceName"`
2. Services have correct properties: `Get-WmiObject -Class Win32_Service -Filter "Name='ServiceName'" | Format-List *`
3. Services start correctly: `Start-Service -Name "ServiceName"`
4. Services function as expected

## Example Workflow

```powershell
# On source computer (as Administrator)
.\Export-WindowsServices.ps1 -OutputPath "C:\Migration\app_services.csv" -FilterByName "App*" -IncludeDisabledServices

# Transfer file to target computer
# Copy app_services.csv to target computer

# On target computer (as Administrator)
$SecurePass = ConvertTo-SecureString "ServicePassword123!" -AsPlainText -Force
.\Import-WindowsServices.ps1 -InputPath "C:\Migration\app_services.csv" -BackupPath "C:\Backup\original_services.csv" -CreateMissing -ServicePassword $SecurePass

# Verify import
Get-Service -Name "App*" | Format-Table Name, DisplayName, Status, StartType
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
- Support for service recovery options
- Support for delayed auto-start services
- Service creation capabilities
