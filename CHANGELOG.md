# Changelog

All notable changes to the Windows Scripts Collection will be documented in this file.

## [1.3.1] - 2025-10-14

### Added
- **FolderPermissionScripts**:
  - Added automatic local group creation to `Import-FolderPermissions.ps1` when missing groups are encountered
  - Added `-CreateMissingGroups` parameter to control group creation behavior (enabled by default)

### Changed
- **FolderPermissionScripts**:
  - Updated `Remove-FolderPermissions.ps1` to remove all non-inherited permissions without requiring a CSV file
  - Added `-Recursive` parameter to process subfolders
  - Simplified parameters and improved usability
  
### Fixed
- **FolderPermissionScripts**:
  - Fixed `Import-FolderPermissions.ps1` to properly handle empty paths in CSV files
  - Added better validation and error handling for CSV import
  - Improved path validation to prevent "empty string" errors

## [1.3.0] - 2025-10-06

### Added
- **FolderPermissionScripts**:
  - Added `Remove-FolderPermissions.ps1` script to remove permissions not listed in a CSV file

## [1.2.0] - 2025-09-25

### Added
- **FolderPermissionScripts**:
  - Added `-SkipInheritedPermissions` parameter to control whether to skip permissions that already exist through inheritance
  - Improved group detection for names containing keywords like "Users", "Groups", "Admins", etc.
  - Added detection for group names with multiple underscore segments (e.g., "PD_Users_Technical")

- **UsersAndGroupsScripts**:
  - Added `-GroupsOnly` parameter to create only groups without any users or group memberships

### Fixed
- **FolderPermissionScripts**:
  - Fixed issue where groups like "PD_Users_Technical" were incorrectly identified as user accounts
  - Prevented duplicate permissions by skipping those already inherited from parent folders

## [1.1.0] - 2025-08-15

### Added
- **SharedFolderScripts**:
  - Added comprehensive scripts for shared folder migration
  - Support for both share and NTFS permissions
  - Automatic backup creation before import

- **TaskSchedulerScripts**:
  - Added scripts for migrating scheduled tasks between computers
  - Support for all task triggers, actions, and settings

## [1.0.0] - Initial Release

### Added
- **FolderPermissionScripts**:
  - Export-FolderPermissions.ps1 for exporting folder permissions to CSV
  - Import-FolderPermissions.ps1 for importing folder permissions from CSV

- **UsersAndGroupsScripts**:
  - Export-UsersAndGroups.ps1 for exporting local users, groups, and memberships to CSV
  - Import-UsersAndGroups.ps1 for importing users, groups, and memberships from CSV

- **FirewallRulesScripts**:
  - Export-FirewallRules.ps1 for exporting Windows Firewall rules to CSV
  - Import-FirewallRules.ps1 for importing firewall rules from CSV

- **RegistryScripts**:
  - Export-RegistrySettings.ps1 for exporting registry keys and values to CSV
  - Import-RegistrySettings.ps1 for importing registry settings from CSV

- **ServicesScripts**:
  - Export-WindowsServices.ps1 for exporting Windows services configuration to CSV
  - Import-WindowsServices.ps1 for importing services configuration from CSV
