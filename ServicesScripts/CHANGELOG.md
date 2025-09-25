# Changelog

All notable changes to the Windows Services Migration Scripts will be documented in this file.

## [1.0.0] - Initial Release

### Added
- Export-WindowsServices.ps1 script for exporting Windows services configuration to CSV
- Import-WindowsServices.ps1 script for importing services configuration from CSV
- Support for all major service properties:
  - Service name and display name
  - Description and binary path
  - Startup type (automatic, manual, disabled)
  - Logon account and credentials
  - Service dependencies
  - Recovery options (restart, run program, reboot)
  - Failure actions and delay
- Support for creating new services or updating existing ones
- Filtering options for service types during export and import
- Secure credential handling for service logon accounts
- WhatIf mode for testing imports without applying changes
- Detailed logging and error handling
- Comprehensive README with usage instructions and examples
