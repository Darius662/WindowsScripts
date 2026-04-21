# Remote Management Module
# Handles remote computer connectivity and process launching

# Global variables for remote connections
$script:RemoteConnections = @{}
$script:RemoteProcesses = @{}

# Test remote computer connectivity
function Test-RemoteComputer {
    param(
        [string]$ComputerName,
        [string]$Username,
        [System.Security.SecureString]$Password
    )
    
    try {
        $credential = New-Object System.Management.Automation.PSCredential($Username, $Password)
        
        # Test basic connectivity with ping
        $pingResult = Test-Connection -ComputerName $ComputerName -Count 1 -Quiet -ErrorAction Stop
        if (-not $pingResult) {
            throw "Computer $ComputerName is not reachable"
        }
        
        # Test PowerShell remoting
        $session = New-PSSession -ComputerName $ComputerName -Credential $credential -ErrorAction Stop
        Remove-PSSession -Session $session -ErrorAction SilentlyContinue
        
        return $true
    } catch {
        throw "Remote connection test failed: $($_.Exception.Message)"
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
            param($Command)
            Invoke-Expression $Command
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

# Launch remote tool with smart handling
function Start-RemoteToolAsUser {
    param(
        [string]$ComputerName,
        [string]$Username,
        [System.Security.SecureString]$Password,
        [string]$ToolName
    )
    
    # Get tool info from common tools
    $commonTools = Get-CommonTools
    $toolInfo = $commonTools[$ToolName]
    
    if (-not $toolInfo) {
        return @{
            Success = $false
            Message = "Unknown tool: $ToolName"
        }
    }
    
    try {
        $credential = New-Object System.Management.Automation.PSCredential($Username, $Password)
        
        # Create PowerShell session
        $session = New-PSSession -ComputerName $ComputerName -Credential $credential -ErrorAction Stop
        
        # Build the command for the tool
        $toolPath = $toolInfo.Path
        $toolArgs = $toolInfo.Args
        
        $command = "Start-Process -FilePath '$toolPath'"
        if ($toolArgs.Count -gt 0) {
            $argString = $toolArgs | ForEach-Object { "'$_'" }
            $command += " -ArgumentList $($argString -join ',')"
        }
        $command += " -PassThru"
        
        # Execute the command remotely
        $result = Invoke-Command -Session $session -ScriptBlock {
            param($Command)
            Invoke-Expression $Command
        } -ArgumentList $command -ErrorAction Stop
        
        # Clean up session
        Remove-PSSession -Session $session -ErrorAction SilentlyContinue
        
        # Track the remote process
        $processId = if ($result) { $result.Id } else { "Unknown" }
        $script:RemoteProcesses["$ComputerName`:$processId"] = @{
            ComputerName = $ComputerName
            ProcessId = $processId
            FilePath = $toolPath
            User = $Username
            StartTime = Get-Date
        }
        
        return @{
            Success = $true
            ProcessId = $processId
            Message = "Successfully started $ToolName on $ComputerName"
        }
    } catch {
        return @{
            Success = $false
            Message = "Failed to start $ToolName on $ComputerName`: $($_.Exception.Message)"
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
        $result = Test-WSMan -ComputerName $ComputerName -ErrorAction Stop
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
