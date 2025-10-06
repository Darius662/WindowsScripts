# Changelog

All notable changes to the Folder Permission Scripts will be documented in this file.

## [1.3.0] - 2025-10-06

### Added
- Added `Remove-FolderPermissions.ps1` script to remove permissions not listed in a CSV file

## [1.2.0] - 2025-09-25

### Added
- Added `-SkipInheritedPermissions` parameter to control whether to skip permissions that already exist through inheritance (enabled by default)

## [1.1.0] - 2025-09-25

### Added
- Improved group detection for names containing keywords like "Users", "Groups", "Admins", etc.
- Added detection for group names with multiple underscore segments (e.g., "PD_Users_Technical")
- Added functionality to skip applying permissions that already exist through inheritance
- Added clear visual feedback (cyan-colored messages) when skipping inherited permissions

### Fixed
- Fixed issue where groups like "PD_Users_Technical" were incorrectly identified as user accounts
- Prevented duplicate permissions by skipping those already inherited from parent folders

## [1.0.0] - Initial Release

### Added
- Export-FolderPermissions.ps1 script for exporting folder permissions to CSV
- Import-FolderPermissions.ps1 script for importing folder permissions from CSV
- Support for handling SIDs, user accounts, and local principals
- Comprehensive README with usage instructions and examples
