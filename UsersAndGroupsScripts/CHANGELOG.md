# Changelog

All notable changes to the Users and Groups Migration Scripts will be documented in this file.

## [1.1.0] - 2025-09-25

### Added
- Added `-GroupsOnly` parameter to Import-UsersAndGroups.ps1 to create only groups without any users
- When `-GroupsOnly` is specified, the script will:
  - Skip user creation entirely
  - Skip group membership assignments
  - Only create the group structure from the CSV file

## [1.0.0] - Initial Release

### Added
- Export-UsersAndGroups.ps1 script for exporting local users, groups, and their memberships to CSV
- Import-UsersAndGroups.ps1 script for importing users, groups, and memberships from CSV
- Support for handling domain users in group memberships
- Random password generation option
- Comprehensive error handling and logging
- Support for existing account updates
