# File Operations Scripts

This directory contains PowerShell scripts for automating common file operations across multiple directories.

## Scripts Overview

### 1. Update-PluginFiles.ps1
Automates the process of updating plugin files across multiple directories with backup creation and file extraction.

## Prerequisites

- PowerShell 5.1 or later
- Appropriate permissions to access all directories involved
- Network access if working with remote directories

## Usage

### Update-PluginFiles.ps1

```powershell
.\Update-PluginFiles.ps1 -RemoteDirectory1 "\\server\plugins\main" -RemoteDirectory2 "\\server\plugins\backup"
```

**Parameters:**
- `-DownloadsPath` (optional): Path to the downloads directory. Default is user's Downloads folder.
- `-SourceFilePattern` (optional): Pattern to match the source ZIP file. Default is "rac_plugins-*.zip".
- `-DestinationFileName` (optional): Name to rename the source file to. Default is "tcmpapsPlugins.zip".
- `-RemoteDirectory1` (required): First remote directory where files will be updated and ZIP extracted.
- `-RemoteDirectory2` (required): Second remote directory where files will be updated.
- `-CreateBackup` (optional): Creates backup of existing files. Default is $true.
- `-Force` (optional): Forces the operation without prompting for confirmation.

**Examples:**
```powershell
# Basic usage with required parameters
.\Update-PluginFiles.ps1 -RemoteDirectory1 "\\server\plugins\main" -RemoteDirectory2 "\\server\plugins\backup"

# Specify custom downloads path and source file pattern
.\Update-PluginFiles.ps1 -DownloadsPath "D:\Downloads" -SourceFilePattern "plugins-v2.1.zip" -RemoteDirectory1 "E:\Plugins" -RemoteDirectory2 "F:\Backup"

# Force operation without prompts
.\Update-PluginFiles.ps1 -RemoteDirectory1 "\\server\plugins" -RemoteDirectory2 "\\server\backup" -Force
```

## What the Script Does

### Update-PluginFiles.ps1

1. **In Downloads Directory:**
   - Finds a file matching the specified pattern (default: "rac_plugins-*.zip")
   - Renames it to the destination filename (default: "tcmpapsPlugins.zip")

2. **In First Remote Directory:**
   - Removes all files except ZIP archives
   - Removes any existing backup file (tcmpapsPlugins.bk.zip)
   - Renames existing tcmpapsPlugins.zip to tcmpapsPlugins.bk.zip
   - Copies the new tcmpapsPlugins.zip from downloads
   - Extracts the ZIP file contents

3. **In Second Remote Directory:**
   - Removes any existing backup file (tcmpapsPlugins.bk.zip)
   - Renames existing tcmpapsPlugins.zip to tcmpapsPlugins.bk.zip
   - Copies the new tcmpapsPlugins.zip from downloads

## Important Notes

- The script validates all paths before performing operations
- Detailed logging is provided for all operations
- Error handling is implemented for each step
- Confirmation prompts are shown when overwriting files (unless -Force is used)

## Troubleshooting

### Common Issues

**"Access Denied" errors:**
- Ensure you have appropriate permissions for all directories
- Run PowerShell with elevated privileges if necessary
- Check if files are locked by other processes

**"Path not found" errors:**
- Verify all paths exist and are accessible
- Check network connectivity for remote paths
- Ensure UNC paths are correctly formatted

**File not found errors:**
- Verify the source file pattern matches files in the downloads directory
- Check if antivirus software is blocking access

## Support

For issues or questions:
1. Check the console output for detailed error messages
2. Verify permissions and path accessibility
3. Ensure PowerShell execution policy allows script execution:
   ```powershell
   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
   ```

## Version History

- **v1.0**: Initial release with comprehensive file operations functionality
  - Support for file renaming, copying, and extraction
  - Automatic backup creation
  - Detailed logging and error handling
