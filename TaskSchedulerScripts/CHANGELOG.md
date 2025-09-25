# Changelog

All notable changes to the Task Scheduler Migration Scripts will be documented in this file.

## [1.0.0] - Initial Release

### Added
- Export-ScheduledTasks.ps1 script for exporting scheduled tasks configuration to CSV
- Import-ScheduledTasks.ps1 script for importing scheduled tasks configuration from CSV
- Support for all major scheduled task properties:
  - Task name and path
  - Description and author
  - Triggers (daily, weekly, monthly, event-based, etc.)
  - Actions (run program, send email, display message)
  - Settings (run level, wake to run, idle settings)
  - Security principals and credentials
  - Conditions (idle, power, network)
- XML backup of original task definitions
- Filtering options for system tasks
- Secure credential handling for task principals
- WhatIf mode for testing imports without applying changes
- Detailed logging and error handling
- Comprehensive README with usage instructions and examples
