# Task Scheduler Migration Scripts

This repository contains two PowerShell scripts for migrating Windows Task Scheduler entries between computers.

## Scripts Overview

### 1. Export-ScheduledTasks.ps1
Exports all user-created scheduled tasks and their configurations from the source computer to a CSV file.

### 2. Import-ScheduledTasks.ps1
Imports scheduled tasks and their configurations from the CSV file to recreate them on the target computer.

## Prerequisites

- **Administrator privileges** required on both source and target computers
- PowerShell 5.1 or later
- Windows 10/11 or Windows Server 2016+
- Same folder structure on target computer as source computer (for tasks that reference local files)

## Usage

### Step 1: Export from Source Computer

```powershell
# Run as Administrator
.\Export-ScheduledTasks.ps1 -OutputPath "C:\Migration\tasks.csv"
```

**Parameters:**
- `-OutputPath` (optional): Path where the CSV file will be saved. Default: `.\ScheduledTasksExport.csv`
- `-IncludeSystem` (optional): Include Microsoft and system tasks in the export (not recommended)
- `-TaskPath` (optional): Filter to export only tasks from a specific folder path. Default: `\` (all tasks)

**Examples:**
```powershell
# Export to specific location
.\Export-ScheduledTasks.ps1 -OutputPath "D:\Backup\MyTasks.csv"

# Export only tasks from a specific folder
.\Export-ScheduledTasks.ps1 -TaskPath "\MyCustomTasks\"

# Export all tasks including system tasks (not recommended)
.\Export-ScheduledTasks.ps1 -IncludeSystem
```

### Step 2: Transfer CSV File
Copy the generated CSV file to the target computer.

### Step 3: Import to Target Computer

```powershell
# Run as Administrator
.\Import-ScheduledTasks.ps1 -InputPath "C:\Migration\tasks.csv"
```

**Parameters:**
- `-InputPath` (required): Path to the CSV file created by the export script
- `-SkipExisting` (optional): Skip existing tasks instead of updating them
- `-LogPath` (optional): Path for the import log file. Default: `.\TaskImportLog.txt`
- `-BackupPath` (optional): Path to backup existing tasks before import. Default: `.\TaskBackup.csv`
- `-TaskPassword` (optional): SecureString password for tasks that require authentication

**Examples:**
```powershell
# Basic import
.\Import-ScheduledTasks.ps1 -InputPath "tasks.csv"

# Skip existing tasks
.\Import-ScheduledTasks.ps1 -InputPath "tasks.csv" -SkipExisting

# Custom log and backup paths
.\Import-ScheduledTasks.ps1 -InputPath "tasks.csv" -LogPath "C:\Logs\import.log" -BackupPath "C:\Backup\existing-tasks.csv"

# Import with password for tasks that run under specific user accounts
$SecurePass = ConvertTo-SecureString "Password123" -AsPlainText -Force
.\Import-ScheduledTasks.ps1 -InputPath "tasks.csv" -TaskPassword $SecurePass
```

## What Gets Migrated

### Task Configuration
- Task name and path
- Task description and author information
- Task XML definition (complete task configuration)
- Task state (enabled/disabled)
- Task actions (commands, arguments)
- Task triggers (schedule information)
- Task principal (user context)
- Task settings (all task settings)

### Metadata
- Export date and source computer information
- Task statistics (last run time, next run time, etc.)
- Task execution history summary

## Important Notes

### Security Considerations
- **Review all tasks** after import to ensure they're appropriate for the target environment
- **Verify file paths** exist on the target system before running imported tasks
- **Test task execution** after migration
- **Backup existing tasks** automatically created before import
- **Password-protected tasks** may require providing credentials during import

### Limitations
- Microsoft and system tasks are excluded from export by default
- Tasks that reference local files require the same file structure on the target computer
- Some tasks may require manual adjustment of paths or settings
- Tasks that use specific local user accounts may need password provided during import
- Tasks with complex triggers or custom settings should be verified after import

### Best Practices
1. **Test first**: Run on a test system before production migration
2. **Backup**: Automatic backup is created, but consider additional system backups
3. **Verify**: Check all tasks and their settings after import
4. **File paths**: Ensure referenced files exist in the same locations on target system
5. **Documentation**: Keep logs of the migration process

## Troubleshooting

### Common Issues

**"Access Denied" errors:**
- Ensure you're running PowerShell as Administrator
- Verify you have permission to access the Task Scheduler
- Check if antivirus software is blocking access

**"Path not found" errors:**
- Verify task folder paths exist on target system
- Check for correct task path formatting (must start with "\")

**Task registration errors:**
- Verify XML definition is valid
- Check if referenced files exist on target system
- Ensure user accounts referenced in tasks exist on target system

**Task fails to run after import:**
- Check task action paths and arguments
- Verify user context and run level settings
- Check for missing dependencies or files

### Log Files
The import script creates detailed logs at the specified location (default: `TaskImportLog.txt`). Check this file for detailed information about any issues.

### Verification Steps
After import, verify:
1. All expected tasks are present: `Get-ScheduledTask`
2. Task settings are correct: `Get-ScheduledTask -TaskName "TaskName" | Select *`
3. Task XML is valid: `Export-ScheduledTask -TaskName "TaskName" -TaskPath "\TaskPath\"`
4. Task can run successfully: Test run the task
5. Task history is being recorded: Check the task history in Task Scheduler

## Example Workflow

```powershell
# On source computer (as Administrator)
.\Export-ScheduledTasks.ps1 -OutputPath "C:\Migration\company-tasks.csv"

# Transfer file to target computer
# Copy company-tasks.csv to target computer

# On target computer (as Administrator)
.\Import-ScheduledTasks.ps1 -InputPath "C:\Migration\company-tasks.csv"

# Verify import
Get-ScheduledTask | Where-Object {$_.TaskPath -notlike "\Microsoft\*"}
```

## Advanced Usage

### Selective Import
You can modify the CSV file before import to:
- Remove tasks you don't want to recreate
- Change task properties or settings
- Update file paths to match the target system

### Batch Operations
```powershell
# Export from multiple servers
$Servers = @("Server1", "Server2", "Server3")
foreach ($Server in $Servers) {
    Invoke-Command -ComputerName $Server -ScriptBlock {
        .\Export-ScheduledTasks.ps1 -OutputPath "C:\Migration\$env:COMPUTERNAME-tasks.csv"
    }
}
```

## Support

For issues or questions:
1. Check the import log file for detailed error messages
2. Verify administrator privileges
3. Ensure PowerShell execution policy allows script execution:
   ```powershell
   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
   ```
4. Verify Task Scheduler service is running:
   ```powershell
   Get-Service -Name "Schedule"
   ```

## Version History

- **v1.0**: Initial release with comprehensive export/import functionality
- Complete task definition migration via XML
- Automatic backup creation
- Detailed logging and error handling
- Support for task folder structure recreation
