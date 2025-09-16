# Windows Scripts Collection

A comprehensive collection of PowerShell scripts for Windows system administration and management tasks.

## Overview

This repository contains various PowerShell scripts designed to help with common Windows administration tasks, including user management, folder permissions, and system configuration.

## Scripts Categories

### 📁 [Folder Permission Scripts](./FolderPermissionScripts/)
Scripts for managing and migrating folder permissions across Windows systems.

- **Export-FolderPermissions.ps1** - Exports folder permissions to CSV format
- **Import-FolderPermissions.ps1** - Imports and applies folder permissions from CSV

### 👥 [Users and Groups Scripts](./UsersAndGroupsScripts/)
Scripts for managing local users, groups, and their memberships.

- **Export-UsersAndGroups.ps1** - Exports local users, groups, and memberships to CSV
- **Import-UsersAndGroups.ps1** - Imports and recreates users, groups, and memberships from CSV

## Prerequisites

- **Windows 10/11** or **Windows Server 2016+**
- **PowerShell 5.1** or later
- **Administrator privileges** required for most scripts
- Proper **execution policy** configured:
  ```powershell
  Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
  ```

## Quick Start

1. **Clone the repository:**
   ```powershell
   git clone https://github.com/yourusername/WindowsScripts.git
   cd WindowsScripts
   ```

2. **Choose the appropriate script category** and navigate to its folder

3. **Run PowerShell as Administrator**

4. **Execute the desired script** following the documentation in each folder

## Security Best Practices

All scripts in this collection follow PowerShell security best practices:

- ✅ Use `SecureString` for password parameters
- ✅ Require Administrator privileges where needed
- ✅ Include comprehensive error handling
- ✅ Provide detailed logging capabilities
- ✅ Validate input parameters and file paths

## Usage Examples

### Export and Import Users
```powershell
# On source computer
.\UsersAndGroupsScripts\Export-UsersAndGroups.ps1 -OutputPath "C:\Migration\users.csv"

# On target computer
$SecurePass = ConvertTo-SecureString "TempPass123!" -AsPlainText -Force
.\UsersAndGroupsScripts\Import-UsersAndGroups.ps1 -InputPath "C:\Migration\users.csv" -DefaultPassword $SecurePass
```

### Export and Import Folder Permissions
```powershell
# Export permissions
.\FolderPermissionScripts\Export-FolderPermissions.ps1 -FolderPath "C:\SharedData" -OutputPath "permissions.csv"

# Import permissions
.\FolderPermissionScripts\Import-FolderPermissions.ps1 -InputPath "permissions.csv"
```

## Features

- 🔒 **Secure**: Follows PowerShell security best practices
- 📝 **Well-documented**: Comprehensive help and examples for each script
- 🛡️ **Error handling**: Robust error handling and logging
- 🔄 **Migration-friendly**: Designed for easy system-to-system migrations
- 📊 **CSV-based**: Uses standard CSV format for data portability
- ⚡ **Efficient**: Optimized for performance with large datasets

## Script Structure

Each script category includes:
- **Export script** - Extracts data to CSV format
- **Import script** - Recreates configuration from CSV
- **README.md** - Detailed documentation and usage examples
- **Error handling** - Comprehensive logging and error reporting

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Follow PowerShell best practices
4. Include comprehensive documentation
5. Test thoroughly before submitting
6. Submit a pull request

## Testing

Before using scripts in production:

1. **Test on non-production systems** first
2. **Create system backups** before making changes
3. **Verify results** after script execution
4. **Review logs** for any warnings or errors

## Troubleshooting

### Common Issues

**"Execution Policy" errors:**
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

**"Access Denied" errors:**
- Ensure PowerShell is running as Administrator
- Verify user has appropriate permissions for target resources

**Script not found:**
- Verify file paths are correct
- Check that files weren't blocked by Windows security

### Getting Help

Each script includes built-in help:
```powershell
Get-Help .\ScriptName.ps1 -Full
```

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support

For issues, questions, or contributions:
- Create an issue in the GitHub repository
- Check existing documentation in script folders
- Review script logs for detailed error information

## Version History

- **v1.0** - Initial release with Users/Groups and Folder Permissions scripts
- Comprehensive error handling and logging
- SecureString implementation for password security
- CSV-based data format for portability

---

**⚠️ Important:** Always test scripts in a non-production environment first and ensure you have proper backups before making system changes.
