# Windows Firewall Rules Migration Scripts

This directory contains two PowerShell scripts for exporting and importing Windows Firewall rules between computers.

## Scripts Overview

### 1. Export-FirewallRules.ps1
Exports Windows Firewall rules from the source computer to a CSV file, capturing all relevant rule properties.

### 2. Import-FirewallRules.ps1
Imports firewall rules from the CSV file to recreate them on the target computer with all their original properties.

## Prerequisites

- **Administrator privileges** required on both source and target computers
- PowerShell 5.1 or later
- Windows 10/11 or Windows Server 2016+
- Windows Advanced Firewall enabled

## Usage

### Step 1: Export from Source Computer

```powershell
# Run as Administrator
.\Export-FirewallRules.ps1 -OutputPath "C:\Migration\firewall_rules.csv"
```

**Parameters:**
- `-OutputPath` (optional): Path where the CSV file will be saved. Default: `.\FirewallRulesExport.csv`
- `-IncludeDisabledRules` (optional): Include disabled firewall rules in the export
- `-FilterByDisplayName` (optional): Filter rules by display name (supports wildcards)
- `-FilterByProfile` (optional): Filter rules by profile (Domain, Private, Public, Any)
- `-FilterByDirection` (optional): Filter rules by direction (Inbound, Outbound)

**Examples:**
```powershell
# Export all enabled rules to default location
.\Export-FirewallRules.ps1

# Export to specific location
.\Export-FirewallRules.ps1 -OutputPath "D:\Backup\firewall.csv"

# Export including disabled rules
.\Export-FirewallRules.ps1 -IncludeDisabledRules

# Export only Remote Desktop related rules
.\Export-FirewallRules.ps1 -FilterByDisplayName "Remote Desktop*"

# Export only public profile inbound rules
.\Export-FirewallRules.ps1 -FilterByProfile "Public" -FilterByDirection "Inbound"
```

### Step 2: Transfer CSV File
Copy the generated CSV file to the target computer.

### Step 3: Import to Target Computer

```powershell
# Run as Administrator
.\Import-FirewallRules.ps1 -InputPath "C:\Migration\firewall_rules.csv"
```

**Parameters:**
- `-InputPath` (required): Path to the CSV file created by the export script
- `-BackupPath` (optional): Path to save a backup of existing rules before importing
- `-SkipExisting` (optional): Skip existing rules instead of replacing them
- `-LogPath` (optional): Path for the import log file. Default: `.\FirewallRulesImport.log`

**Examples:**
```powershell
# Basic import
.\Import-FirewallRules.ps1 -InputPath "firewall_rules.csv"

# Import with backup of existing rules
.\Import-FirewallRules.ps1 -InputPath "firewall_rules.csv" -BackupPath "existing_rules_backup.csv"

# Skip existing rules
.\Import-FirewallRules.ps1 -InputPath "firewall_rules.csv" -SkipExisting

# Custom log file location
.\Import-FirewallRules.ps1 -InputPath "firewall_rules.csv" -LogPath "C:\Logs\firewall_import.log"
```

## What Gets Migrated

The scripts capture and recreate the following firewall rule properties:

### Basic Properties
- Rule name and display name
- Description and group
- Enabled/disabled status
- Direction (inbound/outbound)
- Action (allow/block)
- Edge traversal policy

### Filtering Properties
- Profiles (Domain, Private, Public, Any)
- Local and remote addresses
- Protocol information
- Local and remote ports
- ICMP types
- Program paths and packages
- Service names
- Interface types and aliases

### Security Properties
- Authentication requirements
- Encryption requirements
- User and machine restrictions

## Important Notes

### Limitations
- Some system rules may have special properties that cannot be fully recreated
- Rules referencing specific programs must have those programs in the same path on the target computer
- UWP app rules (Package) may need the same app installed on the target computer
- Some advanced security settings might require additional configuration

### Best Practices
1. **Test first**: Run on a test system before production migration
2. **Backup**: Always use the `-BackupPath` parameter when importing to create a backup
3. **Verify**: Check all imported rules after migration
4. **Filter**: Use filter parameters to migrate only specific rule sets if needed
5. **Documentation**: Keep logs of the migration process

## Troubleshooting

### Common Issues

**"Access Denied" errors:**
- Ensure you're running PowerShell as Administrator
- Some built-in Windows rules may be protected

**"Rule already exists" warnings:**
- Use `-SkipExisting` to skip existing rules
- Or allow the script to replace existing rules (default behavior)

**Program path issues:**
- Ensure referenced programs exist in the same paths on the target computer
- Update program paths manually if necessary after import

**Profile-specific issues:**
- Ensure the target computer has the same network profiles configured

### Log Files
The import script creates detailed logs at the specified location (default: `FirewallRulesImport.log`). Check this file for detailed information about any issues.

### Verification Steps
After import, verify:
1. Rules are present: `Get-NetFirewallRule`
2. Rules have correct properties: `Get-NetFirewallRule -DisplayName "Rule Name" | Format-List *`
3. Test functionality by ensuring applications work as expected with the imported rules

## Example Workflow

```powershell
# On source computer (as Administrator)
.\Export-FirewallRules.ps1 -OutputPath "C:\Migration\company_firewall.csv" -IncludeDisabledRules

# Transfer file to target computer
# Copy company_firewall.csv to target computer

# On target computer (as Administrator)
.\Import-FirewallRules.ps1 -InputPath "C:\Migration\company_firewall.csv" -BackupPath "C:\Backup\original_rules.csv"

# Verify import
Get-NetFirewallRule | Where-Object { $_.DisplayName -like "*imported*" }
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
- Support for all standard firewall rule properties
- Filtering options for targeted exports
