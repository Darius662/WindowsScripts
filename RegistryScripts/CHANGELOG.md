# Changelog

All notable changes to the Registry Settings Migration Scripts will be documented in this file.

## [1.0.0] - Initial Release

### Added
- Export-RegistrySettings.ps1 script for exporting registry keys and values to CSV
- Import-RegistrySettings.ps1 script for importing registry settings from CSV
- Support for all registry value types:
  - String (REG_SZ)
  - Expandable String (REG_EXPAND_SZ)
  - Binary (REG_BINARY)
  - DWORD (REG_DWORD)
  - QWORD (REG_QWORD)
  - Multi-String (REG_MULTI_SZ)
- Recursive registry key export with configurable depth
- Support for registry path wildcards and exclusions
- Backup creation before modifying registry
- WhatIf mode for testing imports without applying changes
- Detailed logging and error handling
- Comprehensive README with usage instructions and examples
