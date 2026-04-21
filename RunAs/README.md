# RunAs User Management Scripts

This project contains PowerShell scripts for running applications and tools as different users with a modern graphical user interface.

## Overview

The RunAs scripts provide a comprehensive solution for running applications as different users, featuring both command-line and GUI interfaces with advanced functionality including process tracking, recent files management, and quick access to common Windows administrative tools.

## Scripts

<!-- ### 1. `RunAsUser.ps1` - Enhanced GUI Application
A modern, feature-rich graphical application for running files and tools as different users. -->

#### Features
- **Modern Dark Theme UI** - Contemporary design with intuitive layout
- **File Selection** - Support for single and multiple file selection
- **Remote Computer Support** - Execute applications and tools on remote computers:
  - Enable remote execution with checkbox
  - Test remote connectivity before launching
  - Support for all quick tools on remote systems
  - PowerShell remoting-based implementation
- **Quick Tools** - One-click access to 10 common Windows administrative tools:
  - PowerShell
  - Command Prompt
  - Registry Editor
  - Computer Management
  - Local Certificates
  - Current User Certificates
  - Services
  - Event Viewer
  - Task Manager
  - Group Policy Editor
- **Process Tracking** - Real-time monitoring of running processes with automatic refresh
- **Recent Files** - Automatic tracking and quick access to last 10 files
- **Smart Elevation** - Intelligent UAC handling that works for both admin and non-admin users
- **Modular Architecture** - Clean, maintainable code structure

#### Usage

```powershell
# Launch the GUI application
.\RunAsUser.ps1

# Or use the launcher script
.\LaunchGUI.bat
```

#### GUI Components

1. **File Selection Section**
   - Multi-line text box for file paths
   - Browse button for file selection
   - Support for multiple files

2. **Remote Computer Section**
   - Checkbox to enable remote execution
   - Computer name input field
   - Test connection button for validation
   - Supports both local and remote execution

3. **Credentials Section**
   - Username and password input fields
   - Secure password handling
   - Main "Run as User" button

4. **Quick Tools Section**
   - 10 buttons for common Windows tools
   - Automatic elevation handling
   - One-click launch with credentials
   - Remote execution support for all tools

5. **Running Processes Section**
   - Real-time process list with details
   - Auto-refresh every 5 seconds
   - Shows process name, file path, user, start time, and PID

6. **Menu System**
   - File menu with browse and recent files
   - View menu with refresh option
   - Keyboard shortcuts (Ctrl+O, F5, Alt+F4)

#### Architecture

The application uses a modular architecture with separate modules:

- **`Modules/Config.ps1`** - Configuration and recent files management
- **`Modules/ProcessManager.ps1`** - Process launching and smart elevation handling
- **`Modules/UIComponents.ps1`** - Modern UI components and styling
- **`Modules/RemoteManager.ps1`** - Remote computer connectivity and process launching

#### Smart Elevation Handling

The application implements intelligent elevation handling:

1. **Direct Launch First** - Attempts to launch tools directly without elevation
2. **PowerShell Wrapper Fallback** - Uses PowerShell wrapper if elevation is required
3. **User-Respectful** - Works properly for both admin and non-admin target users
4. **Tool-Specific Logic** - Different handling for tools that inherently require elevation

#### Security Features

- SecureString usage for password handling
- Automatic password clearing after use
- No credential storage in memory longer than necessary
- Proper working directory resolution

### 2. `LaunchGUI.bat` - Simple Launcher
A batch file for easy launching of the GUI application.

#### Usage

```batch
# Double-click or run from command line
LaunchGUI.bat
```

## Requirements

- Windows PowerShell 5.1 or PowerShell 7.x
- Windows Forms assembly (automatically loaded)
- Administrative privileges (for some tools)
- .NET Framework support

### Remote Execution Requirements

For remote computer execution, you additionally need:

- **PowerShell Remoting Enabled** on target computers:
  ```powershell
  Enable-PSRemoting -Force
  ```
- **Network Connectivity** between computers
- **Valid Credentials** with administrative rights on remote computer
- **Firewall Rules** allowing WinRM traffic (default port 5985)
- **Same Domain** or appropriate trust relationships between computers

## Installation

1. Clone or download the repository
2. Navigate to the `RunAs` folder
3. Run `RunAsUser.ps1` or `LaunchGUI.bat`

## Configuration

The application automatically creates a configuration file in your user profile:
- `%USERPROFILE%\RunAsUserGUI_Config.json`

This file stores:
- Recent files list (last 10 files)
- User preferences

## Example Workflows

### Running Custom Applications

1. Launch the GUI application
2. Enter file paths manually or use Browse button
3. Enter username and password
4. Click "Run as User"

### Using Quick Tools

1. Enter credentials in the Credentials section
2. Click any tool button in the Quick Tools section
3. Tool launches with the specified credentials

### Process Monitoring

1. Launch applications using the GUI
2. Monitor running processes in the bottom section
3. Process list updates automatically every 5 seconds
4. Use F5 or View menu to refresh manually

### Remote Computer Execution

1. **Setup Remote Computer**:
   ```powershell
   # On the remote computer, enable PowerShell remoting
   Enable-PSRemoting -Force
   ```

2. **Launch Remote Tools**:
   - Check "Enable Remote Execution" checkbox
   - Enter the remote computer name or IP address
   - Click "Test Connection" to verify connectivity
   - Enter credentials (username and password)
   - Use any tool button or file path to launch remotely

3. **Example: Remote Registry Editor**:
   - Computer Name: `192.168.1.100` or `SERVER-01`
   - Username: `Administrator` (or domain admin)
   - Password: `[admin password]`
   - Click "Registry Editor" button
   - Registry Editor opens on the remote computer

4. **Example: Remote PowerShell**:
   - Enable remote execution
   - Enter remote computer details
   - Click "PowerShell" button
   - PowerShell session opens on remote system with specified credentials

## Troubleshooting

### Common Issues

1. **"The requested operation requires elevation"**
   - This is normal for tools that require admin rights
   - The application handles this automatically with smart elevation

2. **"Cannot validate argument on parameter 'ArgumentList'"**
   - Fixed in current version - tools without arguments launch directly

3. **Timer errors in console**
   - Fixed in current version - proper null parameter handling

### Remote Connectivity Issues

1. **"Remote connection test failed"**
   - Verify PowerShell remoting is enabled on remote computer
   - Check network connectivity (ping the remote computer)
   - Ensure firewall allows WinRM traffic (port 5985)
   - Verify credentials are correct and have admin rights

2. **"WinRM service is not running"**
   - Run `Enable-PSRemoting -Force` on remote computer
   - Check WinRM service status: `Get-Service WinRM`

3. **"Access is denied"**
   - Use domain administrator credentials
   - Ensure user is in remote computer's administrators group
   - Check UAC settings on remote computer

4. **"Cannot connect to remote computer"**
   - Verify computer name or IP address is correct
   - Check DNS resolution for computer names
   - Ensure both computers are on the same network

### Tips

- Use the recent files menu for quick access to frequently used files
- The process list helps track what's running as which user
- Keyboard shortcuts improve workflow efficiency
- The modern UI provides better visibility in different lighting conditions
- Test remote connections before launching tools to save time
- Use IP addresses if DNS resolution is problematic
- Enable WinRM on target computers beforehand for smooth operation

## Development Notes

### Modular Design Benefits

- **Maintainability** - Each module has a single responsibility
- **Reusability** - Components can be used in other projects
- **Security** - Centralized credential handling
- **Testing** - Individual modules can be tested separately

### Code Quality

- Error handling throughout the application
- Secure credential management
- Modern PowerShell best practices
- Comprehensive logging and user feedback

## Changelog

See [CHANGELOG.md](./CHANGELOG.md) for detailed version history and changes.
