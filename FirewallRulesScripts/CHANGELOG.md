# Changelog

All notable changes to the Windows Firewall Rules Migration Scripts will be documented in this file.

## [1.0.0] - Initial Release

### Added
- Export-FirewallRules.ps1 script for exporting Windows Firewall rules to CSV
- Import-FirewallRules.ps1 script for importing firewall rules from CSV
- Support for all major firewall rule properties including:
  - Rule name, description, and group
  - Direction (inbound/outbound)
  - Action (allow/block)
  - Protocol, local/remote ports, and addresses
  - Program and service settings
  - Interface types and security settings
- Comprehensive filtering options during import
- Detailed logging and error handling
- WhatIf mode for testing imports without applying changes
- Comprehensive README with usage instructions and examples
