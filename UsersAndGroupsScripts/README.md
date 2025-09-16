# User and Group Migration Scripts

This repository contains two PowerShell scripts for migrating local users, groups, and their memberships between Windows computers.

## Scripts Overview

### 1. Export-UsersAndGroups.ps1
Exports all local users, groups, and their memberships from the source computer to a CSV file.

### 2. Import-UsersAndGroups.ps1
Imports users, groups, and memberships from the CSV file to recreate them on the target computer.

## Prerequisites

- **Administrator privileges** required on both source and target computers
- PowerShell 5.1 or later
- Windows 10/11 or Windows Server 2016+

## Usage

### Step 1: Export from Source Computer

```powershell
# Run as Administrator
.\Export-UsersAndGroups.ps1 -OutputPath "C:\Migration\users.csv"
```

**Parameters:**
- `-OutputPath` (optional): Path where the CSV file will be saved. Default: `.\UserGroupExport.csv`

**Example:**
```powershell
# Export to specific location
.\Export-UsersAndGroups.ps1 -OutputPath "D:\Backup\MyUsers.csv"

# Export to current directory (default)
.\Export-UsersAndGroups.ps1
```

### Step 2: Transfer CSV File
Copy the generated CSV file to the target computer.

### Step 3: Import to Target Computer

```powershell
# Run as Administrator
.\Import-UsersAndGroups.ps1 -InputPath "C:\Migration\users.csv" -DefaultPassword "TempPass123!"
```

**Parameters:**
- `-InputPath` (required): Path to the CSV file created by the export script
- `-DefaultPassword` (optional): Password for imported users. If not specified, a random password is generated
- `-SkipExisting` (optional): Skip existing users/groups instead of updating them
- `-LogPath` (optional): Path for the import log file. Default: `.\ImportLog.txt`

**Examples:**
```powershell
# Basic import with custom password
.\Import-UsersAndGroups.ps1 -InputPath "users.csv" -DefaultPassword "SecurePass2024!"

# Import with random password generation
.\Import-UsersAndGroups.ps1 -InputPath "users.csv"

# Skip existing users and groups
.\Import-UsersAndGroups.ps1 -InputPath "users.csv" -SkipExisting

# Custom log file location
.\Import-UsersAndGroups.ps1 -InputPath "users.csv" -LogPath "C:\Logs\import.log"
```

## What Gets Migrated

### Users
- Username
- Full name
- Description
- Enabled/disabled status
- Password settings (structure, not actual passwords)
- Group memberships

### Groups
- Group name
- Description
- Group members

### Group Memberships
- All user-to-group relationships are preserved

## Important Notes

### Security Considerations
- **Passwords are NOT migrated** for security reasons
- All imported users receive the same default password or a randomly generated one
- **Change default passwords immediately** after import
- Review and verify all imported accounts before production use

### Limitations
- Only works with local users and groups (not domain accounts)
- Built-in Windows accounts may have restrictions
- Some system groups may not be modifiable
- Password history and advanced security settings are not migrated

### Best Practices
1. **Test first**: Run on a test system before production migration
2. **Backup**: Create system backups before running import
3. **Verify**: Check all accounts and permissions after import
4. **Security**: Change all default passwords immediately
5. **Documentation**: Keep logs of the migration process

## Troubleshooting

### Common Issues

**"Access Denied" errors:**
- Ensure you're running PowerShell as Administrator
- Some built-in accounts cannot be modified

**"User already exists" warnings:**
- Use `-SkipExisting` to skip existing accounts
- Or allow the script to update existing accounts (default behavior)

**Group membership errors:**
- Verify the group exists before adding members
- Some system groups have restrictions on membership

### Log Files
The import script creates detailed logs at the specified location (default: `ImportLog.txt`). Check this file for detailed information about any issues.

### Verification Steps
After import, verify:
1. All expected users are present: `Get-LocalUser`
2. All expected groups are present: `Get-LocalGroup`
3. Group memberships are correct: `Get-LocalGroupMember -Group "GroupName"`

## Example Workflow

```powershell
# On source computer (as Administrator)
.\Export-UsersAndGroups.ps1 -OutputPath "C:\Migration\company-users.csv"

# Transfer file to target computer
# Copy company-users.csv to target computer

# On target computer (as Administrator)
.\Import-UsersAndGroups.ps1 -InputPath "C:\Migration\company-users.csv" -DefaultPassword "TempPass2024!"

# Verify import
Get-LocalUser
Get-LocalGroup

# Change passwords for all imported users
# (This should be done immediately for security)
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
- Support for existing account updates
- Random password generation option
