#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Exports all user-created Task Scheduler entries to a CSV file.

.DESCRIPTION
    This script extracts all user-created scheduled tasks from the Windows Task Scheduler
    and exports them to a CSV file that can be used for migration to another computer.
    The script excludes Microsoft and system tasks by default.

.PARAMETER OutputPath
    The path where the CSV file will be saved. Default is "ScheduledTasksExport.csv" in the current directory.

.PARAMETER IncludeSystem
    If specified, system tasks will also be exported (not recommended for migration).

.PARAMETER TaskPath
    Optional path filter to export only tasks from specific folders. Default is "\" (root) to get all tasks.

.EXAMPLE
    .\Export-ScheduledTasks.ps1 -OutputPath "C:\Backup\tasks.csv"

.EXAMPLE
    .\Export-ScheduledTasks.ps1 -TaskPath "\MyCustomTasks\"
#>

param(
    [string]$OutputPath = ".\ScheduledTasksExport.csv",
    [switch]$IncludeSystem,
    [string]$TaskPath = "\"
)

# Function to convert task XML to Base64 for storage
function Convert-TaskToBase64 {
    param($TaskName, $TaskPath)
    try {
        $TaskXml = (Export-ScheduledTask -TaskName $TaskName -TaskPath $TaskPath -ErrorAction Stop)
        $Bytes = [System.Text.Encoding]::UTF8.GetBytes($TaskXml)
        return [Convert]::ToBase64String($Bytes)
    }
    catch {
        Write-Warning "Could not export XML for task: $TaskPath$TaskName - $($_.Exception.Message)"
        return ""
    }
}

# Function to safely get task info
function Get-TaskInfo {
    param($Task)
    try {
        $TaskInfo = @{
            TaskName = $Task.TaskName
            TaskPath = $Task.TaskPath
            Description = $Task.Description
            Author = $Task.Author
            State = $Task.State
            IsEnabled = $Task.Settings.Enabled
            LastRunTime = $Task.LastRunTime
            LastTaskResult = $Task.LastTaskResult
            NumberOfMissedRuns = $Task.NumberOfMissedRuns
            NextRunTime = $Task.NextRunTime
            Actions = ($Task.Actions | ForEach-Object { $_.Execute + " " + $_.Arguments }) -join ";"
            Principal = $Task.Principal.UserId
            LogonType = $Task.Principal.LogonType
            RunLevel = $Task.Principal.RunLevel
            XML = Convert-TaskToBase64 -TaskName $Task.TaskName -TaskPath $Task.TaskPath
            ExportDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            SourceComputer = $env:COMPUTERNAME
        }
        return $TaskInfo
    }
    catch {
        Write-Warning "Error processing task $($Task.TaskName): $($_.Exception.Message)"
        return $null
    }
}

Write-Host "Starting export of scheduled tasks..." -ForegroundColor Green

# Initialize array to store data
$ExportData = @()

try {
    # Get all scheduled tasks
    Write-Host "Collecting scheduled tasks from path: $TaskPath" -ForegroundColor Yellow
    $Tasks = Get-ScheduledTask -TaskPath $TaskPath -ErrorAction SilentlyContinue
    
    if (-not $Tasks) {
        Write-Host "No scheduled tasks found in the specified path." -ForegroundColor Yellow
        $ExportData = @()
    }
    else {
        # Filter out Microsoft and system tasks unless IncludeSystem is specified
        if (-not $IncludeSystem) {
            $Tasks = $Tasks | Where-Object { 
                -not ($_.TaskPath -like "\Microsoft\*") -and
                -not ($_.TaskPath -like "\MicrosoftEdge\*") -and
                -not ($_.TaskName -like "User_Feed_Synchronization*") -and
                -not ($_.Author -like "*Microsoft*")
            }
            
            Write-Host "Filtered out Microsoft and system tasks. Use -IncludeSystem to include them." -ForegroundColor Yellow
        }
        
        $TotalTasks = $Tasks.Count
        Write-Host "Processing $TotalTasks tasks..." -ForegroundColor Cyan
        $CurrentTask = 0
        
        foreach ($Task in $Tasks) {
            $CurrentTask++
            Write-Progress -Activity "Exporting Scheduled Tasks" -Status "Processing $($Task.TaskName)" -PercentComplete (($CurrentTask / $TotalTasks) * 100)
            
            Write-Host "Processing task: $($Task.TaskPath)$($Task.TaskName)" -ForegroundColor Cyan
            
            $TaskInfo = Get-TaskInfo -Task $Task
            if ($TaskInfo) {
                $ExportData += [PSCustomObject]$TaskInfo
            }
        }
        
        Write-Progress -Activity "Exporting Scheduled Tasks" -Completed
    }

    # Export to CSV
    Write-Host "Exporting data to CSV: $OutputPath" -ForegroundColor Yellow
    $ExportData | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8

    Write-Host "Export completed successfully!" -ForegroundColor Green
    Write-Host "Total scheduled tasks exported: $($ExportData.Count)" -ForegroundColor Cyan
    Write-Host "CSV file saved to: $OutputPath" -ForegroundColor Cyan
    
    if ($ExportData.Count -gt 0) {
        Write-Host "`nExported tasks:" -ForegroundColor Yellow
        foreach ($Task in $ExportData) {
            Write-Host "  - $($Task.TaskPath)$($Task.TaskName)" -ForegroundColor White
        }
    }
}
catch {
    Write-Error "An error occurred during export: $($_.Exception.Message)"
    exit 1
}
