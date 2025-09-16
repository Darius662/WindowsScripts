# Shared Folder Migration Scripts

This repository contains two PowerShell scripts for migrating shared folders and their configurations between Windows computers.

## Scripts Overview

### 1. Export-SharedFolders.ps1
Exports all shared folders, their paths, permissions, and configurations from the source computer to a CSV file.

### 2. Import-SharedFolders.ps1
Imports shared folders and their configurations from the CSV file to recreate them on the target computer.

## Prerequisites

- **Administrator privileges** required on both source and target computers
- PowerShell 5.1 or later
- Windows 10/11 or Windows Server 2016+
- SMB feature enabled on both computers

## Usage

### Step 1: Export from Source Computer

```powershell
# Run as Administrator
.\Export-SharedFolders.ps1 -OutputPath "C:\Migration\shares.csv"
```

**Parameters:**
- `-OutputPath` (optional): Path where the CSV file will be saved. Default: `.\SharedFolderExport.csv`

**Example:**
```powershell
# Export to specific location
.\Export-SharedFolders.ps1 -OutputPath "D:\Backup\MyShares.csv"

# Export to current directory (default)
.\Export-SharedFolders.ps1
```

### Step 2: Transfer CSV File
Copy the generated CSV file to the target computer.

### Step 3: Import to Target Computer

```powershell
# Run as Administrator
.\Import-SharedFolders.ps1 -InputPath "C:\Migration\shares.csv" -CreateMissingFolders
```

**Parameters:**
- `-InputPath` (required): Path to the CSV file created by the export script
- `-CreateMissingFolders` (optional): Automatically create missing folders if they don't exist
- `-SkipExisting` (optional): Skip existing shares instead of updating them
- `-LogPath` (optional): Path for the import log file. Default: `.\ImportLog.txt`
- `-BackupPath` (optional): Path to backup existing shares before import. Default: `.\ShareBackup.csv`

**Examples:**
```powershell
# Basic import with automatic folder creation
.\Import-SharedFolders.ps1 -InputPath "shares.csv" -CreateMissingFolders

# Skip existing shares
.\Import-SharedFolders.ps1 -InputPath "shares.csv" -SkipExisting

# Custom log and backup paths
.\Import-SharedFolders.ps1 -InputPath "shares.csv" -LogPath "C:\Logs\import.log" -BackupPath "C:\Backup\existing-shares.csv"

# Import without creating missing folders (folders must exist)
.\Import-SharedFolders.ps1 -InputPath "shares.csv"
```

## What Gets Migrated

### Share Configuration
- Share name
- Folder path
- Description
- Folder enumeration mode
- Caching mode
- Concurrent user limit
- Continuous availability timeout
- Encryption settings
- Compression settings
- Continuous availability settings

### Permissions
- **Share-level permissions**: User/group access rights (Read, Change, Full Control)
- **Folder-level permissions**: NTFS permissions with inheritance settings
- **Access control types**: Allow/Deny permissions

### Metadata
- Export date and source computer information
- Folder existence validation
- Share state and type information

## Important Notes

### Security Considerations
- **Review all permissions** after import to ensure they're appropriate for the target environment
- **Verify user and group accounts** exist on the target system before import
- **Test access** from client computers after migration
- **Backup existing shares** automatically created before import

### Limitations
- Administrative shares (C$, ADMIN$, IPC$) are excluded from export/import
- Print shares are not included
- Some advanced share features may require manual configuration
- Domain user accounts must exist and be accessible on the target system
- **SIDs are automatically skipped** during import as they are system-specific and cannot be transferred

### Best Practices
1. **Test first**: Run on a test system before production migration
2. **Backup**: Automatic backup is created, but consider additional system backups
3. **Verify**: Check all shares and permissions after import
4. **Network**: Ensure proper network connectivity and DNS resolution
5. **Documentation**: Keep logs of the migration process

## Troubleshooting

### Common Issues

**"Access Denied" errors:**
- Ensure you're running PowerShell as Administrator
- Verify you have permission to access the source folders
- Check if antivirus software is blocking access

**"Path not found" errors:**
- Use `-CreateMissingFolders` to automatically create missing directories
- Verify drive letters and paths exist on target system
- Check for UNC path vs local path differences

**Permission errors:**
- Verify user and group accounts exist on target system
- Check domain connectivity for domain accounts
- Review NTFS permissions on parent directories
- **SID-based permissions are automatically skipped** (logged as INFO messages)

**Share already exists:**
- Use `-SkipExisting` to skip existing shares
- Or allow the script to update existing shares (default behavior)
- Check the backup file for original configurations

### Log Files
The import script creates detailed logs at the specified location (default: `ImportLog.txt`). Check this file for detailed information about any issues.

### Verification Steps
After import, verify:
1. All expected shares are present: `Get-SmbShare`
2. Share permissions are correct: `Get-SmbShareAccess -Name "ShareName"`
3. Folder permissions are correct: `Get-Acl -Path "C:\Path\To\Folder"`
4. Client access works: Test from client computers
5. Network discovery: Ensure shares are visible on the network

## Example Workflow

```powershell
# On source computer (as Administrator)
.\Export-SharedFolders.ps1 -OutputPath "C:\Migration\company-shares.csv"

# Transfer file to target computer
# Copy company-shares.csv to target computer

# On target computer (as Administrator)
.\Import-SharedFolders.ps1 -InputPath "C:\Migration\company-shares.csv" -CreateMissingFolders

# Verify import
Get-SmbShare
Get-SmbShareAccess -Name "ShareName"

# Test client access
# Connect from client computers to verify functionality
```

## Advanced Usage

### Selective Import
You can modify the CSV file before import to:
- Remove shares you don't want to recreate
- Change paths to different locations
- Modify descriptions or settings
- Update permissions

### Batch Operations
```powershell
# Export multiple servers
$Servers = @("Server1", "Server2", "Server3")
foreach ($Server in $Servers) {
    Invoke-Command -ComputerName $Server -ScriptBlock {
        .\Export-SharedFolders.ps1 -OutputPath "C:\Migration\$env:COMPUTERNAME-shares.csv"
    }
}
```

## Support

For issues or questions:
1. Check the import log file for detailed error messages
2. Verify administrator privileges
3. Ensure PowerShell execution policy allows script execution:
   ```powershell
   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
   ```
4. Verify SMB services are running:
   ```powershell
   Get-Service -Name "LanmanServer"
   Get-Service -Name "LanmanWorkstation"
   ```

## Version History

- **v1.0**: Initial release with comprehensive export/import functionality
- Full permission migration (share and NTFS)
- Automatic backup creation
- Detailed logging and error handling
- Support for missing folder creation
