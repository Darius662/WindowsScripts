# Changelog

All notable changes to the Shared Folder Migration Scripts will be documented in this file.

## [1.0.0] - Initial Release

### Added
- Export-SharedFolders.ps1 script for exporting shared folders configuration to CSV
- Import-SharedFolders.ps1 script for importing shared folders configuration from CSV
- Support for all major shared folder properties:
  - Share name and path
  - Share description
  - Share permissions (Full Control, Change, Read)
  - NTFS permissions
  - Maximum allowed connections
  - Caching settings
  - Access-based enumeration settings
- Automatic folder creation if target folders don't exist
- Backup creation before modifying existing shares
- Filtering options for administrative shares
- WhatIf mode for testing imports without applying changes
- Detailed logging and error handling
- Comprehensive README with usage instructions and examples
