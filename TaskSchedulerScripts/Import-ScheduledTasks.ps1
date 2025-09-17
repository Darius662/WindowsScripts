#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Imports scheduled tasks from a CSV file created by Export-ScheduledTasks.ps1.

.DESCRIPTION
    This script reads a CSV file created by Export-ScheduledTasks.ps1 and recreates
    the scheduled tasks on the target computer. It handles task XML definitions,
    permissions, and configurations.

.PARAMETER InputPath
    The path to the CSV file containing the exported scheduled tasks data.

.PARAMETER SkipExisting
    If specified, existing tasks will be skipped instead of updated.

.PARAMETER LogPath
    Path for the import log file. Default is "TaskImportLog.txt" in the current directory.

.PARAMETER BackupPath
    Path to backup existing task configurations before making changes. Default is "TaskBackup.csv".

.PARAMETER TaskPassword
    Optional SecureString password for tasks that require a password to run.
    Use this if tasks run under specific user accounts that require authentication.

.EXAMPLE
    .\Import-ScheduledTasks.ps1 -InputPath "C:\Backup\tasks.csv"

.EXAMPLE
    .\Import-ScheduledTasks.ps1 -InputPath "tasks.csv" -SkipExisting

.EXAMPLE
    $SecurePass = ConvertTo-SecureString "Password123" -AsPlainText -Force
    .\Import-ScheduledTasks.ps1 -InputPath "tasks.csv" -TaskPassword $SecurePass
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$InputPath,
    
    [switch]$SkipExisting,
    
    [string]$LogPath = ".\TaskImportLog.txt",
    
    [string]$BackupPath = ".\TaskBackup.csv",
    
    [SecureString]$TaskPassword
)

# Function to write log entries
function Write-Log {
    param($Message, $Level = "INFO")
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "[$Timestamp] [$Level] $Message"
    Write-Host $LogEntry
    Add-Content -Path $LogPath -Value $LogEntry
}

# Function to backup existing tasks
function Backup-ExistingTasks {
    try {
        Write-Log "Creating backup of existing tasks..."
        $ExistingTasks = Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object { 
            -not ($_.TaskPath -like "\Microsoft\*") -and
            -not ($_.TaskPath -like "\MicrosoftEdge\*") -and
            -not ($_.TaskName -like "User_Feed_Synchronization*") -and
            -not ($_.Author -like "*Microsoft*")
        }
        
        if ($ExistingTasks) {
            $BackupData = @()
            foreach ($Task in $ExistingTasks) {
                try {
                    $TaskXml = (Export-ScheduledTask -TaskName $Task.TaskName -TaskPath $Task.TaskPath -ErrorAction Stop)
                    $Bytes = [System.Text.Encoding]::UTF8.GetBytes($TaskXml)
                    $Base64Xml = [Convert]::ToBase64String($Bytes)
                    
                    $BackupData += [PSCustomObject]@{
                        TaskName = $Task.TaskName
                        TaskPath = $Task.TaskPath
                        Description = $Task.Description
                        XML = $Base64Xml
                        BackupDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                    }
                }
                catch {
                    Write-Log "Failed to backup task '$($Task.TaskName)': $($_.Exception.Message)" "WARNING"
                }
            }
            $BackupData | Export-Csv -Path $BackupPath -NoTypeInformation -Encoding UTF8
            Write-Log "Backup saved to: $BackupPath"
        } else {
            Write-Log "No existing tasks to backup"
        }
    }
    catch {
        Write-Log "Failed to create backup: $($_.Exception.Message)" "WARNING"
    }
}

# Function to convert Base64 to task XML
function Convert-Base64ToTaskXml {
    param($Base64String)
    try {
        $Bytes = [Convert]::FromBase64String($Base64String)
        return [System.Text.Encoding]::UTF8.GetString($Bytes)
    }
    catch {
        Write-Log "Failed to convert Base64 to XML: $($_.Exception.Message)" "ERROR"
        return $null
    }
}

# Function to ensure task folder exists
function Test-TaskFolderExists {
    param($TaskPath)
    
    if ($TaskPath -eq "\") {
        return $true
    }
    
    try {
        $FolderExists = Get-ScheduledTask -TaskPath $TaskPath -ErrorAction SilentlyContinue
        if (-not $FolderExists) {
            # Extract parent folder path
            $ParentPath = Split-Path -Parent $TaskPath
            if ($ParentPath -ne "\") {
                $ParentPath = "$ParentPath\"
            }
            
            # Ensure parent folder exists first (recursive)
            Test-TaskFolderExists -TaskPath $ParentPath
            
            # Create the folder
            $FolderName = (Split-Path -Leaf $TaskPath).TrimEnd('\')
            if ($FolderName) {
                $null = Register-ScheduledTask -TaskName $FolderName -TaskPath $ParentPath -Action (New-ScheduledTaskAction -Execute "cmd.exe") -ErrorAction SilentlyContinue
                $null = Unregister-ScheduledTask -TaskName $FolderName -TaskPath $ParentPath -Confirm:$false -ErrorAction SilentlyContinue
            }
        }
        return $true
    }
    catch {
        Write-Log "Failed to create task folder '$TaskPath': $($_.Exception.Message)" "WARNING"
        return $false
    }
}

# Function to safely import a task
function Import-Task {
    param(
        $TaskData,
        [SecureString]$Password
    )
    
    try {
        $TaskName = $TaskData.TaskName
        $TaskPath = $TaskData.TaskPath
        
        # Check if task already exists
        $ExistingTask = Get-ScheduledTask -TaskName $TaskName -TaskPath $TaskPath -ErrorAction SilentlyContinue
        
        if ($ExistingTask -and $SkipExisting) {
            Write-Log "Task '$TaskPath$TaskName' already exists, skipping due to -SkipExisting flag" "WARNING"
            return $false
        }
        
        # Convert Base64 XML back to string
        $TaskXml = Convert-Base64ToTaskXml -Base64String $TaskData.XML
        if (-not $TaskXml) {
            Write-Log "Could not retrieve XML definition for task: $TaskPath$TaskName" "ERROR"
            return $false
        }
        
        # Ensure task folder exists
        if (-not (Test-TaskFolderExists -TaskPath $TaskPath)) {
            Write-Log "Failed to create task folder structure for: $TaskPath" "ERROR"
            return $false
        }
        
        # Remove existing task if it exists
        if ($ExistingTask) {
            Write-Log "Removing existing task: $TaskPath$TaskName"
            Unregister-ScheduledTask -TaskName $TaskName -TaskPath $TaskPath -Confirm:$false
        }
        
        # Register the task
        Write-Log "Registering task: $TaskPath$TaskName"
        
        # Determine if we need to use a password
        if ($Password -and $TaskData.LogonType -eq "Password") {
            # Get username from the task data
            $Username = $TaskData.Principal
            if (-not $Username) {
                $Username = $env:USERNAME
                Write-Log "No username found in task data, using current user: $Username" "WARNING"
            }
            
            # Register with password
            $null = Register-ScheduledTask -TaskName $TaskName -TaskPath $TaskPath -Xml $TaskXml -User $Username -Password $Password
            Write-Log "Task registered with user credentials: $Username"
        }
        else {
            # Register without password
            $null = Register-ScheduledTask -TaskName $TaskName -TaskPath $TaskPath -Xml $TaskXml
            Write-Log "Task registered without specific credentials"
        }
        
        # Verify task was created
        $NewTask = Get-ScheduledTask -TaskName $TaskName -TaskPath $TaskPath -ErrorAction SilentlyContinue
        if ($NewTask) {
            Write-Log "Task '$TaskPath$TaskName' imported successfully"
            return $true
        }
        else {
            Write-Log "Failed to verify task creation: $TaskPath$TaskName" "ERROR"
            return $false
        }
    }
    catch {
        Write-Log "Failed to import task '$($TaskData.TaskName)': $($_.Exception.Message)" "ERROR"
        return $false
    }
}

# Main script execution
Write-Log "Starting import of scheduled tasks from: $InputPath"

# Validate input file
if (-not (Test-Path $InputPath)) {
    Write-Log "Input file not found: $InputPath" "ERROR"
    exit 1
}

try {
    # Create backup of existing tasks
    Backup-ExistingTasks
    
    # Import CSV data
    Write-Log "Reading CSV data..."
    $ImportData = Import-Csv -Path $InputPath
    
    if (-not $ImportData) {
        Write-Log "No data found in CSV file" "ERROR"
        exit 1
    }
    
    Write-Log "Found $($ImportData.Count) scheduled tasks in CSV file"
    
    # Import tasks
    Write-Log "Importing scheduled tasks..."
    $TasksImported = 0
    $TotalTasks = $ImportData.Count
    $CurrentTask = 0
    
    foreach ($Task in $ImportData) {
        $CurrentTask++
        Write-Progress -Activity "Importing Scheduled Tasks" -Status "Processing $($Task.TaskName)" -PercentComplete (($CurrentTask / $TotalTasks) * 100)
        
        if (Import-Task -TaskData $Task -Password $TaskPassword) {
            $TasksImported++
        }
    }
    
    Write-Progress -Activity "Importing Scheduled Tasks" -Completed
    
    # Final summary
    Write-Log "Import completed!" "SUCCESS"
    Write-Log "Scheduled tasks imported/updated: $TasksImported of $($ImportData.Count)"
    Write-Log "Log file saved to: $LogPath"
    if (Test-Path $BackupPath) {
        Write-Log "Backup file saved to: $BackupPath"
    }
    
    Write-Host "`nIMPORTANT: Please verify all imported tasks and their settings!" -ForegroundColor Red -BackgroundColor Yellow
    Write-Host "Review the imported tasks using: Get-ScheduledTask" -ForegroundColor Yellow
    
}
catch {
    Write-Log "Critical error during import: $($_.Exception.Message)" "ERROR"
    exit 1
}
