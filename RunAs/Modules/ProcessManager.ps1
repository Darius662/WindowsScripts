# Process Management Module
# Handles process launching, tracking, and elevation

# Global variables
$script:RunningProcesses = @{}

# Define common tools with proper launch methods
$script:CommonTools = @{
    "PowerShell" = @{Path = "powershell.exe"; Args = @()}
    "Command Prompt" = @{Path = "cmd.exe"; Args = @()}
    "Registry Editor" = @{Path = "regedit.exe"; Args = @()}
    "Computer Management" = @{Path = "mmc.exe"; Args = @("compmgmt.msc")}
    "Local Certificates" = @{Path = "mmc.exe"; Args = @("certlm.msc")}
    "Current User Certificates" = @{Path = "mmc.exe"; Args = @("certmgr.msc")}
    "Services" = @{Path = "mmc.exe"; Args = @("services.msc")}
    "Event Viewer" = @{Path = "mmc.exe"; Args = @("eventvwr.msc")}
    "Task Manager" = @{Path = "taskmgr.exe"; Args = @()}
    "Group Policy" = @{Path = "gpedit.msc"; Args = @()}
}

# Get common tools definition
function Get-CommonTools {
    return $script:CommonTools
}

# Run process with credentials
function Start-ProcessAsUser {
    param(
        [string[]]$FilePaths,
        [System.Management.Automation.PSCredential]$Credential
    )
    
    foreach ($file in $FilePaths) {
        $trimmedFile = $file.Trim()
        if (Test-Path $trimmedFile) {
            try {
                Write-Host "Starting $trimmedFile as $($Credential.UserName)..."
                
                $workingDir = Split-Path $trimmedFile -Parent
                if ([string]::IsNullOrEmpty($workingDir)) {
                    $workingDir = $env:SYSTEMROOT
                }
                $process = Start-Process -FilePath $trimmedFile -Credential $Credential -WorkingDirectory $workingDir -PassThru
                
                # Track the process
                $script:RunningProcesses[$process.Id] = @{
                    Process = $process
                    FilePath = $trimmedFile
                    User = $Credential.UserName
                    StartTime = Get-Date
                }
                
                Add-RecentFile -FilePath $trimmedFile
                
                [System.Windows.Forms.MessageBox]::Show(
                    "Successfully started $($trimmedFile) as $($Credential.UserName)",
                    "Success",
                    [System.Windows.Forms.MessageBoxButtons]::OK,
                    [System.Windows.Forms.MessageBoxIcon]::Information
                )
            } catch {
                [System.Windows.Forms.MessageBox]::Show(
                    "Failed to start $($trimmedFile): $($_.Exception.Message)",
                    "Error",
                    [System.Windows.Forms.MessageBoxButtons]::OK,
                    [System.Windows.Forms.MessageBoxIcon]::Error
                )
            }
        }
    }
}

# Launch tool with smart elevation handling
function Start-ToolAsUser {
    param(
        [string]$ToolName,
        [string]$Username,
        [System.Security.SecureString]$Password
    )
    
    $toolInfo = $script:CommonTools[$ToolName]
    $toolPath = $toolInfo.Path
    $toolArgs = $toolInfo.Args
    
    if ([string]::IsNullOrWhiteSpace($Username) -or $null -eq $Password) {
        [System.Windows.Forms.MessageBox]::Show("Please enter username and password to run tools", "Error", "OK", "Error")
        return
    }
    
    try {
        $credential = New-Object System.Management.Automation.PSCredential($Username, $Password)
        
        $argsDisplay = if ($toolArgs.Count -gt 0) { " $($toolArgs -join ' ')" } else { "" }
        Write-Host "Starting $toolPath$argsDisplay as $($credential.UserName)..."
        
        # Smart elevation handling - try direct launch first, then PowerShell wrapper if needed
        $workingDir = "C:\Windows\System32"
        $process = $null
        
        try {
            # Try direct launch first (for non-admin users)
            if ($toolArgs.Count -gt 0) {
                $process = Start-Process -FilePath $toolPath -ArgumentList $toolArgs -Credential $credential -WorkingDirectory $workingDir -PassThru -ErrorAction Stop
            } else {
                $process = Start-Process -FilePath $toolPath -Credential $credential -WorkingDirectory $workingDir -PassThru -ErrorAction Stop
            }
        } catch {
            # If direct launch fails (elevation required), try PowerShell wrapper
            try {
                Write-Host "Direct launch failed, trying PowerShell wrapper..."
                if ($toolArgs.Count -gt 0) {
                    $command = "& '$toolPath' $($toolArgs -join ' ')"
                } else {
                    $command = "& '$toolPath'"
                }
                
                $psArgs = @("-Command", $command, "-NoProfile", "-ExecutionPolicy", "Bypass")
                $process = Start-Process -FilePath "powershell.exe" -ArgumentList $psArgs -Credential $credential -WorkingDirectory $workingDir -PassThru -ErrorAction Stop
            } catch {
                throw $_
            }
        }
        
        # Track the process
        $script:RunningProcesses[$process.Id] = @{
            Process = $process
            FilePath = $toolPath
            User = $credential.UserName
            StartTime = Get-Date
        }
        
        [System.Windows.Forms.MessageBox]::Show(
            "Successfully started $ToolName as $($credential.UserName)",
            "Success",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        )
    } catch {
        [System.Windows.Forms.MessageBox]::Show(
            "Failed to start $ToolName`: $($_.Exception.Message)",
            "Error",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
    }
}

# Update running processes list
function Update-ProcessListView {
    param([System.Windows.Forms.ListView]$ListView, [System.Windows.Forms.Label]$StatusLabel)
    
    # Check if parameters are null (timer may call before UI is ready)
    if ($null -eq $ListView -or $null -eq $StatusLabel) {
        return
    }
    
    $ListView.Items.Clear()
    
    # Remove dead processes
    $deadProcesses = @()
    foreach ($processId in $script:RunningProcesses.Keys) {
        try {
            $process = Get-Process -Id $processId -ErrorAction Stop
            $item = New-Object System.Windows.Forms.ListViewItem
            $item.Text = $process.ProcessName
            $item.SubItems.Add($script:RunningProcesses[$processId].FilePath)
            $item.SubItems.Add($script:RunningProcesses[$processId].User)
            $item.SubItems.Add($script:RunningProcesses[$processId].StartTime.ToString("HH:mm:ss"))
            $item.SubItems.Add($process.Id)
            $ListView.Items.Add($item) | Out-Null
        } catch {
            $deadProcesses += $processId
        }
    }
    
    # Remove dead processes from tracking
    foreach ($deadId in $deadProcesses) {
        $script:RunningProcesses.Remove($deadId)
    }
    
    $StatusLabel.Text = "Running processes: $($script:RunningProcesses.Count)"
}

# Get running processes count
function Get-RunningProcessesCount {
    return $script:RunningProcesses.Count
}
