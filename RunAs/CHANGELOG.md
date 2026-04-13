# RunAs User Scripts Changelog

All notable changes to the RunAs project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.0.0] - 2025-04-13

### Added
- **Modern GUI Application** - Complete rewrite with graphical user interface
- **Modular Architecture** - Split into maintainable modules:
  - `Config.ps1` - Configuration and recent files management
  - `ProcessManager.ps1` - Process launching and elevation handling
  - `UIComponents.ps1` - Modern UI components and styling
- **Quick Tools Section** - One-click access to 10 Windows administrative tools:
  - PowerShell, Command Prompt, Registry Editor
  - Computer Management, Local/Current User Certificates
  - Services, Event Viewer, Task Manager, Group Policy
- **Process Tracking** - Real-time monitoring with auto-refresh every 5 seconds
- **Recent Files Management** - Automatic tracking of last 10 files
- **Smart Elevation Handling** - Two-tier approach:
  - Direct launch for non-admin scenarios
  - PowerShell wrapper fallback for elevation requirements
- **Modern Dark Theme UI** - Contemporary design with:
  - Dark color scheme (#2D2D30, #3E3E42, #252526)
  - Segoe UI font family
  - Flat button design with hover effects
  - Proper spacing and visual hierarchy
- **Enhanced File Selection** - Multi-file support with drag-and-drop capability
- **Keyboard Shortcuts** - Ctrl+O (Browse), F5 (Refresh), Alt+F4 (Exit)
- **Security Improvements** - SecureString usage for password handling
- **Launcher Script** - `LaunchGUI.bat` for easy application access

### Changed
- **Complete Rewrite** - From simple command-line script to full GUI application
- **Elevation Handling** - Intelligent UAC management vs. forced elevation
- **User Experience** - From command-line to intuitive graphical interface
- **Code Organization** - Modular structure vs. monolithic script
- **Error Handling** - Comprehensive error messages and graceful failures

### Fixed
- **Directory Name Errors** - Proper working directory resolution for all tools
- **Parameter Conflicts** - Removed `-Verb RunAs` when using `-Credential`
- **ArgumentList Issues** - Conditional use only when arguments exist
- **UAC Prompts** - Smart handling for admin vs. non-admin target users
- **Timer Errors** - Null parameter checks in process list updates
- **MMC Snap-in Launch** - Proper `mmc.exe` wrapper for management consoles
- **Process Tracking** - Automatic cleanup of dead processes

### Security
- **SecureString Implementation** - Proper password handling in memory
- **No Credential Storage** - Passwords cleared immediately after use
- **Working Directory Security** - Validated directory paths
- **Elevation Respect** - Doesn't force elevation unnecessarily

### Performance
- **Modular Loading** - Only loads required components
- **Efficient Process Tracking** - Optimized process monitoring
- **Smart Refresh** - Only updates when processes change
- **Background Operations** - Non-blocking UI operations

## [1.0.0] - 2025-04-13

### Added
- **Basic RunAsUser Script** - Simple command-line tool for running files as different users
- **Credential Management** - Single credential prompt for multiple files
- **File Validation** - Basic file existence checking
- **Error Handling** - Simple error messages for invalid files
- **Batch Processing** - Support for multiple file arguments

### Features
- Command-line interface with mandatory file path parameters
- Single credential prompt for multiple file execution
- Basic error handling and file validation
- Support for any executable file type

### Limitations
- Command-line only interface
- No process tracking
- No elevation handling
- Basic error messages
- No recent files functionality
- No quick tools access

---

## Version History Summary

### Version 1.0.0 (Original)
- Simple command-line script
- Basic functionality only
- Limited error handling
- No user interface

### Version 2.0.0 (Current)
- Complete GUI application
- Modern design and user experience
- Advanced features and functionality
- Modular architecture
- Smart elevation handling
- Process tracking and monitoring
- Security improvements
- Comprehensive tool integration

## Migration Guide

### From 1.0.0 to 2.0.0

The 2.0.0 version is a complete rewrite with a new interface. Migration is straightforward:

1. **New Interface** - Use the GUI instead of command-line arguments
2. **Enhanced Features** - All original functionality plus new capabilities
3. **Better Security** - Improved credential handling
4. **Process Tracking** - New monitoring capabilities
5. **Quick Tools** - Built-in access to common administrative tools

### Breaking Changes

- **Interface Change** - From command-line to GUI (original script still available as reference)
- **Parameter Changes** - No longer uses command-line parameters
- **Configuration** - New configuration file format and location

### Compatibility

- **Windows Versions** - Supports Windows 10/11 and Server 2016+
- **PowerShell Versions** - Works with PowerShell 5.1+ and PowerShell 7.x
- **Permissions** - Requires appropriate user rights for target operations

## Technical Debt

### Resolved in 2.0.0
- Monolithic script structure
- Limited error handling
- No user interface
- Basic functionality only
- Poor elevation handling

### Future Considerations
- Additional tool integrations
- Theme customization options
- Plugin architecture for extensibility
- Advanced process management features
- Network/remote execution capabilities

## Support

For issues, questions, or feature requests, please refer to the main project documentation or create an issue in the repository.
