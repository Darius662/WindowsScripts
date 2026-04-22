# Remote Management Module
# Handles remote computer connectivity and process launching

# Global variables for remote connections
$script:RemoteConnections = @{}
$script:RemoteProcesses = @{}

# Log file path
$script:LogFile = "$env:TEMP\RunAsUserGUI.log"

# Write a timestamped, levelled log entry
function Write-Log {
    param(
        [string]$Message,
        [ValidateSet('INFO','WARN','ERROR','DEBUG')][string]$Level = 'INFO'
    )
    $ts   = Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff'
    $line = "[$ts][$Level] $Message"
    Add-Content -LiteralPath $script:LogFile -Value $line -ErrorAction SilentlyContinue
    Write-Host $line
}

# Test remote computer connectivity
function Test-RemoteComputer {
    param(
        [string]$ComputerName,
        [string]$Username,
        [System.Security.SecureString]$Password
    )

    Write-Log "TEST-REMOTE  ComputerName='$ComputerName'  Username='$Username'"
    try {
        $credential = New-Object System.Management.Automation.PSCredential($Username, $Password)

        Write-Log "TEST-REMOTE  Pinging $ComputerName ..."
        $pingResult = Test-Connection -ComputerName $ComputerName -Count 1 -Quiet -ErrorAction Stop
        if (-not $pingResult) {
            Write-Log "TEST-REMOTE  Ping FAILED for $ComputerName" -Level WARN
            throw "Computer $ComputerName is not reachable"
        }
        Write-Log "TEST-REMOTE  Ping OK"

        Write-Log "TEST-REMOTE  Opening PSSession to $ComputerName ..."
        $session = New-PSSession -ComputerName $ComputerName -Credential $credential -ErrorAction Stop
        Remove-PSSession -Session $session -ErrorAction SilentlyContinue
        Write-Log "TEST-REMOTE  PSSession OK  --> WinRM is reachable"

        return $true
    } catch {
        Write-Log "TEST-REMOTE  FAILED: $($_.Exception.Message)" -Level ERROR
        throw "Remote connection test failed: $($_.Exception.Message)"
    }
}

# Check whether the target supports Remote Registry access for Regedit.
function Test-RemoteRegistryAccess {
    param(
        [string]$ComputerName,
        [System.Management.Automation.PSCredential]$Credential
    )

    $result = @{
        Success = $false
        ServiceStatus = "Unknown"
        StartType = "Unknown"
        RegistryRead = $false
        Message = "Unknown remote registry status"
    }

    try {
        Write-Log "REMOTE-REGISTRY  Checking service and registry access on $ComputerName"
        $session = New-PSSession -ComputerName $ComputerName -Credential $Credential -ErrorAction Stop
        $check = Invoke-Command -Session $session -ScriptBlock {
            $service = Get-Service -Name RemoteRegistry -ErrorAction Stop
            $serviceCim = Get-CimInstance -ClassName Win32_Service -Filter "Name='RemoteRegistry'" -ErrorAction Stop

            $registryRead = $false
            $registryError = $null
            try {
                Get-Item -Path 'HKLM:\SOFTWARE' -ErrorAction Stop | Out-Null
                $registryRead = $true
            } catch {
                $registryError = $_.Exception.Message
            }

            @{
                ServiceStatus = $service.Status.ToString()
                StartType = $serviceCim.StartMode
                RegistryRead = $registryRead
                RegistryError = $registryError
            }
        } -ErrorAction Stop
                    $process = Start-ProcessViaCredentialShell -Credential $credential -Command $cmd -WorkingDirectory $workingDir
        $result.RegistryRead = [bool]$check.RegistryRead

        if ($check.ServiceStatus -ne 'Running') {
            $result.Message = "RemoteRegistry service is $($check.ServiceStatus). Start the service on $ComputerName before using Regedit remote connect."
            Write-Log "REMOTE-REGISTRY  Service not running. Status='$($check.ServiceStatus)' StartType='$($check.StartType)'" -Level WARN
            return $result
        }

        if (-not $check.RegistryRead) {
            $result.Message = "RemoteRegistry is running, but registry access failed for ${ComputerName}: $($check.RegistryError)"
            Write-Log "REMOTE-REGISTRY  Registry read failed: $($check.RegistryError)" -Level WARN
            return $result
        }

        $result.Success = $true
        $result.Message = "RemoteRegistry is running and basic registry access succeeded on $ComputerName."
        Write-Log "REMOTE-REGISTRY  SUCCESS  Status='$($check.ServiceStatus)' StartType='$($check.StartType)' RegistryRead=$($check.RegistryRead)"
        return $result
    } catch {
        $result.Message = "Unable to validate remote registry access on ${ComputerName}: $($_.Exception.Message)"
        Write-Log "REMOTE-REGISTRY  FAILED: $($_.Exception.Message)" -Level ERROR
        return $result
    }
}

# Start process on remote computer
function Start-RemoteProcessAsUser {
    param(
        [string]$ComputerName,
        [string]$Username,
        [System.Security.SecureString]$Password,
        [string]$FilePath,
        [string[]]$Arguments = @()
    )
    
    try {
        $credential = New-Object System.Management.Automation.PSCredential($Username, $Password)
        
        # Create PowerShell session
        $session = New-PSSession -ComputerName $ComputerName -Credential $credential -ErrorAction Stop
        
        # Build the command to execute
        $command = "Start-Process -FilePath '$FilePath'"
        if ($Arguments.Count -gt 0) {
            $argString = $Arguments | ForEach-Object { "'$_'" }
            $command += " -ArgumentList $($argString -join ',')"
        }
        $command += " -PassThru"
        
        # Execute the command remotely
        $result = Invoke-Command -Session $session -ScriptBlock {
            param($RemoteCommand)
            Invoke-Expression $RemoteCommand
        } -ArgumentList $command -ErrorAction Stop
        
        # Clean up session
        Remove-PSSession -Session $session -ErrorAction SilentlyContinue
        
        # Track the remote process
        $processId = if ($result) { $result.Id } else { "Unknown" }
        $script:RemoteProcesses["$ComputerName`:$processId"] = @{
            ComputerName = $ComputerName
            ProcessId = $processId
            FilePath = $FilePath
            User = $Username
            StartTime = Get-Date
        }
        
        return @{
            Success = $true
            ProcessId = $processId
            Message = "Successfully started $FilePath on $ComputerName"
        }
    } catch {
        return @{
            Success = $false
            ProcessId = $null
            Message = "Failed to start remote process: $($_.Exception.Message)"
        }
    }
}

# Launch remote tool - behaviour depends on the tool's RemoteMode
function Start-RemoteToolAsUser {
    param(
        [string]$ComputerName,
        [string]$Username,
        [System.Security.SecureString]$Password,
        [string]$ToolName
    )

    Write-Log "START-REMOTE-TOOL  Tool='$ToolName'  ComputerName='$ComputerName'  Username='$Username'"

    $commonTools = Get-CommonTools
    $toolInfo = $commonTools[$ToolName]

    if (-not $toolInfo) {
        Write-Log "START-REMOTE-TOOL  Unknown tool: $ToolName" -Level ERROR
        return @{ Success = $false; Message = "Unknown tool: $ToolName" }
    }

    $remoteMode = $toolInfo.RemoteMode
    Write-Log "START-REMOTE-TOOL  RemoteMode='$remoteMode'  Path='$($toolInfo.Path)'"

    $credential = New-Object System.Management.Automation.PSCredential($Username, $Password)
    $workingDir = "C:\Windows\System32"

    switch ($remoteMode) {

        "MMCConnect" {
            try {
                $finalArgs = $toolInfo.RemoteArgs | ForEach-Object { $_ -replace '\{0\}', $ComputerName }
                Write-Log "MMCCONNECT  Exe='$($toolInfo.Path)'  Args='$($finalArgs -join ' ')'"

                $process = $null
                try {
                    Write-Log "MMCCONNECT  Attempt 1: direct Start-Process"
                    $process = Start-Process -FilePath $toolInfo.Path -ArgumentList $finalArgs `
                               -Credential $credential -WorkingDirectory $workingDir -PassThru -ErrorAction Stop
                    Write-Log "MMCCONNECT  Direct launch OK  PID=$($process.Id)"
                } catch {
                    Write-Log "MMCCONNECT  Direct launch failed: $($_.Exception.Message)" -Level WARN
                    Write-Log "MMCCONNECT  Attempt 2: PowerShell wrapper"
                    $cmd = "& '$($toolInfo.Path)' $($finalArgs -join ' ')"
                    $psArgs = @("-Command", $cmd, "-NoProfile", "-ExecutionPolicy", "Bypass")
                    Write-Log "MMCCONNECT  psArgs='$($psArgs -join ' ')'"
                    $process = Start-Process -FilePath "powershell.exe" -ArgumentList $psArgs `
                               -Credential $credential -WorkingDirectory $workingDir -PassThru -ErrorAction Stop
                    Write-Log "MMCCONNECT  Wrapper launch OK  PID=$($process.Id)"
                }
                Write-Log "MMCCONNECT  SUCCESS  Tool=$ToolName  PID=$($process.Id)"
                return @{
                    Success   = $true
                    ProcessId = $process.Id
                    Message   = "Launched $ToolName as $Username, connected to $ComputerName."
                }
            } catch {
                Write-Log "MMCCONNECT  FAILED: $($_.Exception.Message)`n$($_.ScriptStackTrace)" -Level ERROR
                return @{ Success = $false; Message = "Failed to launch $ToolName`: $($_.Exception.Message)" }
            }
        }

        "ManualConnect" {
            # Registry Editor does not accept a /computer switch.
            # Launched locally; user connects via File > Connect Network Registry.
            Write-Log "MANUALCONNECT  Launching '$($toolInfo.Path)' locally as $Username"
            try {
                $registryCheck = Test-RemoteRegistryAccess -ComputerName $ComputerName -Credential $credential
                Write-Log "MANUALCONNECT  Registry preflight: Success=$($registryCheck.Success) ServiceStatus='$($registryCheck.ServiceStatus)' StartType='$($registryCheck.StartType)'"

                $cmd = "& '$($toolInfo.Path)'"
                $process = Start-ProcessViaCredentialShell -Credential $credential -Command $cmd -WorkingDirectory $workingDir -KeepShellOpen:$true
                Write-Log "MANUALCONNECT  Wrapper launch OK  PID=$($process.Id)"
                return @{
                    Success   = $true
                    ProcessId = $process.Id
                    Message   = "Registry Editor launched as $Username.`n`nTo reach ${ComputerName}:`n- Use File > Connect Network Registry`n- Ensure the target is ready: $($registryCheck.Message)"
                }
            } catch {
                Write-Log "MANUALCONNECT  FAILED: $($_.Exception.Message)`n$($_.ScriptStackTrace)" -Level ERROR
                return @{ Success = $false; Message = "Failed to launch Registry Editor: $($_.Exception.Message)" }
            }
        }

        "Domain" {
            Write-Log "DOMAIN  Launching '$($toolInfo.Path)' locally as $Username (GPMC)"
            try {
                $process = $null
                try {
                    Write-Log "DOMAIN  Attempt 1: direct Start-Process"
                    $process = Start-Process -FilePath $toolInfo.Path `
                               -Credential $credential -WorkingDirectory $workingDir -PassThru -ErrorAction Stop
                    Write-Log "DOMAIN  Direct launch OK  PID=$($process.Id)"
                } catch {
                    Write-Log "DOMAIN  Direct launch failed: $($_.Exception.Message)" -Level WARN
                    Write-Log "DOMAIN  Attempt 2: PowerShell wrapper"
                    $cmd = "& '$($toolInfo.Path)'"
                    $process = Start-ProcessViaCredentialShell -Credential $credential -Command $cmd -WorkingDirectory $workingDir
                    Write-Log "DOMAIN  Wrapper launch OK  PID=$($process.Id)"
                }
                Write-Log "DOMAIN  SUCCESS  PID=$($process.Id)"
                return @{
                    Success   = $true
                    ProcessId = $process.Id
                    Message   = "Group Policy Management Console launched as $Username.`nConnect to your domain forest inside the tool to manage GPOs."
                }
            } catch {
                Write-Log "DOMAIN  FAILED: $($_.Exception.Message)`n$($_.ScriptStackTrace)" -Level ERROR
                return @{ Success = $false; Message = "Failed to launch Group Policy Mgmt: $($_.Exception.Message)" }
            }
        }

        "WinRM" {
            Write-Log "WINRM  Opening PSSession to $ComputerName ..."
            try {
                $session = New-PSSession -ComputerName $ComputerName -Credential $credential -ErrorAction Stop
                Write-Log "WINRM  PSSession opened OK"
                $toolPath = $toolInfo.Path
                $toolArgs = $toolInfo.Args
                Write-Log "WINRM  Invoking Start-Process '$toolPath' Args='$($toolArgs -join ' ')' on $ComputerName"
                $result = Invoke-Command -Session $session -ScriptBlock {
                    param($Path, $ToolArgs)
                    if ($ToolArgs.Count -gt 0) {
                        Start-Process -FilePath $Path -ArgumentList $ToolArgs -PassThru
                    } else {
                        Start-Process -FilePath $Path -PassThru
                    }
                } -ArgumentList $toolPath, $toolArgs -ErrorAction Stop
                Remove-PSSession -Session $session -ErrorAction SilentlyContinue

                $processId = if ($result) { $result.Id } else { "Unknown" }
                Write-Log "WINRM  Remote process started  PID=$processId"
                $script:RemoteProcesses["$ComputerName`:$processId"] = @{
                    ComputerName = $ComputerName
                    ProcessId    = $processId
                    FilePath     = $toolPath
                    User         = $Username
                    StartTime    = Get-Date
                }
                return @{
                    Success   = $true
                    ProcessId = $processId
                    Message   = "Started $ToolName on $ComputerName via WinRM (PID $processId).`nNote: the window appears on the remote desktop, not here."
                }
            } catch {
                Write-Log "WINRM  FAILED: $($_.Exception.Message)`n$($_.ScriptStackTrace)" -Level ERROR
                return @{ Success = $false; Message = "WinRM launch failed: $($_.Exception.Message)" }
            }
        }

        "None" {
            Write-Log "NONE  Tool '$ToolName' does not support remote mode" -Level WARN
            return @{
                Success = $false
                Message = "$ToolName does not support remote management.`nLaunch it locally without the Remote Execution checkbox."
            }
        }

        default {
            Write-Log "UNKNOWN-MODE  remoteMode='$remoteMode' for tool '$ToolName'" -Level ERROR
            return @{ Success = $false; Message = "Unknown remote mode for tool: $ToolName" }
        }
    }
}

# Get remote processes
function Get-RemoteProcesses {
    return $script:RemoteProcesses
}

# Clear remote processes tracking
function Clear-RemoteProcesses {
    $script:RemoteProcesses = @{}
}

# Validate remote computer name format
function Test-ComputerNameFormat {
    param([string]$ComputerName)
    
    if ([string]::IsNullOrWhiteSpace($ComputerName)) {
        return $false
    }
    
    # Basic validation for computer name or IP address
    if ($ComputerName -match '^[a-zA-Z0-9\-\.]+$') {
        return $true
    }
    
    return $false
}

# Check if WinRM is enabled on remote computer
function Test-WinRmEnabled {
    param([string]$ComputerName)
    
    try {
        Test-WSMan -ComputerName $ComputerName -ErrorAction Stop | Out-Null
        return $true
    } catch {
        return $false
    }
}

# Enable WinRM on remote computer (requires admin rights)
function Enable-RemoteWinRM {
    param(
        [string]$ComputerName,
        [string]$Username,
        [System.Security.SecureString]$Password
    )
    
    try {
        $credential = New-Object System.Management.Automation.PSCredential($Username, $Password)
        
        # Use psexec or similar method to enable WinRM remotely
        # This is a placeholder - actual implementation may vary
        $command = "winrm quickconfig -quiet"
        
        $session = New-PSSession -ComputerName $ComputerName -Credential $credential -ErrorAction Stop
        Invoke-Command -Session $session -ScriptBlock {
            param($Cmd)
            Invoke-Expression $Cmd
        } -ArgumentList $command -ErrorAction Stop | Out-Null
        
        Remove-PSSession -Session $session -ErrorAction SilentlyContinue
        
        return $true
    } catch {
        return $false
    }
}
