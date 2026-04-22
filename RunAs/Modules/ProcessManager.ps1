# Process Management Module
# Handles process launching, tracking, and elevation

# Global variables
$script:RunningProcesses = @{}

# Define common tools with proper launch methods
# RemoteMode values:
#   MMCConnect    - tool supports /computer:NAME natively, launched locally
#   ManualConnect - tool must be launched locally; user connects manually
#   Domain        - manages domain resources remotely by design
#   WinRM         - non-GUI tool; execute on remote host via PSSession
#   None          - remote not supported for this tool
$script:CommonTools = @{
    "PowerShell"                = @{Path = "powershell.exe"; Args = @();               RemoteMode = "WinRM";        RemoteArgs = @()}
    "Command Prompt"            = @{Path = "cmd.exe";        Args = @();               RemoteMode = "WinRM";        RemoteArgs = @()}
    "Registry Editor"           = @{Path = "regedit.exe";   Args = @();               RemoteMode = "ManualConnect"; RemoteArgs = @()}
    "Computer Management"       = @{Path = "mmc.exe";       Args = @("compmgmt.msc"); RemoteMode = "MMCConnect";   RemoteArgs = @("compmgmt.msc", "/computer:{0}")}
    "Local Certificates"        = @{Path = "mmc.exe";       Args = @("certlm.msc");   RemoteMode = "None";         RemoteArgs = @()}
    "Current User Certificates" = @{Path = "mmc.exe";       Args = @("certmgr.msc");  RemoteMode = "None";         RemoteArgs = @()}
    "Services"                  = @{Path = "mmc.exe";       Args = @("services.msc"); RemoteMode = "MMCConnect";   RemoteArgs = @("services.msc",  "/computer:{0}")}
    "Event Viewer"              = @{Path = "mmc.exe";       Args = @("eventvwr.msc"); RemoteMode = "MMCConnect";   RemoteArgs = @("eventvwr.msc",  "/computer:{0}")}
    "Task Manager"              = @{Path = "taskmgr.exe";   Args = @();               RemoteMode = "None";         RemoteArgs = @()}
    "Local Group Policy"        = @{Path = "gpedit.msc";    Args = @();               RemoteMode = "None";         RemoteArgs = @()}
    "Group Policy Mgmt"         = @{Path = "gpmc.msc";      Args = @();               RemoteMode = "Domain";       RemoteArgs = @()}
}

# Get common tools definition
function Get-CommonTools {
    return $script:CommonTools
}

function Start-ProcessViaCredentialShell {
    param(
        [System.Management.Automation.PSCredential]$Credential,
        [string]$Command,
        [string]$WorkingDirectory,
        [bool]$KeepShellOpen = $false,
        [System.Diagnostics.ProcessWindowStyle]$WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden
    )

    $psArgs = @("-NoProfile", "-ExecutionPolicy", "Bypass")
    if ($KeepShellOpen) {
        $psArgs += "-NoExit"
    }
    $psArgs += @("-Command", $Command)

    Write-Log "CREDENTIAL-SHELL  Command='$Command' KeepShellOpen=$KeepShellOpen WindowStyle='$WindowStyle' Args='$($psArgs -join ' ')'"
    return Start-Process -FilePath "powershell.exe" -ArgumentList $psArgs -Credential $Credential -WorkingDirectory $WorkingDirectory -WindowStyle $WindowStyle -PassThru -ErrorAction Stop
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
        [System.Windows.Forms.MessageBox]::Show("Please enter username and password to run tools", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        return
    }
    
    try {
        $credential = New-Object System.Management.Automation.PSCredential($Username, $Password)
        
        $argsDisplay = if ($toolArgs.Count -gt 0) { " $($toolArgs -join ' ')" } else { "" }
        $workingDir = "C:\Windows\System32"
        Write-Log "START-TOOL  Tool='$ToolName'  Exe='$toolPath$argsDisplay'  User='$($credential.UserName)'  WorkingDir='$workingDir'"

        $process = $null
        
        try {
            Write-Log "START-TOOL  Attempt 1: direct Start-Process"
            if ($toolArgs.Count -gt 0) {
                $process = Start-Process -FilePath $toolPath -ArgumentList $toolArgs -Credential $credential -WorkingDirectory $workingDir -PassThru -ErrorAction Stop
            } else {
                $process = Start-Process -FilePath $toolPath -Credential $credential -WorkingDirectory $workingDir -PassThru -ErrorAction Stop
            }
            Write-Log "START-TOOL  Direct launch OK  PID=$($process.Id)"
        } catch {
            Write-Log "START-TOOL  Direct launch failed: $($_.Exception.Message)" -Level WARN
            try {
                Write-Log "START-TOOL  Attempt 2: PowerShell wrapper"
                if ($toolArgs.Count -gt 0) {
                    $command = "& '$toolPath' $($toolArgs -join ' ')"
                } else {
                    $command = "& '$toolPath'"
                }

                $keepShellOpen = ($ToolName -eq "Registry Editor")
                $process = Start-ProcessViaCredentialShell -Credential $credential -Command $command -WorkingDirectory $workingDir -KeepShellOpen:$keepShellOpen
                Write-Log "START-TOOL  Wrapper launch OK  PID=$($process.Id)"
            } catch {
                Write-Log "START-TOOL  Wrapper launch failed: $($_.Exception.Message)`n$($_.ScriptStackTrace)" -Level ERROR
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

        Write-Log "START-TOOL  SUCCESS  Tool=$ToolName  PID=$($process.Id)"
        $successMessage = "Successfully started $ToolName as $($credential.UserName)"
        [System.Windows.Forms.MessageBox]::Show(
            $successMessage,
            "Success",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        )
    } catch {
        Write-Log "START-TOOL  FAILED  Tool=$ToolName  Error=$($_.Exception.Message)" -Level ERROR
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
