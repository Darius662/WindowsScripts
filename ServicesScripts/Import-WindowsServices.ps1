#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Imports Windows services configuration from a CSV file.

.DESCRIPTION
    This script imports Windows services configuration from a CSV file created by the Export-WindowsServices.ps1 script.
    It can update existing services or create new services with all their properties including startup type, 
    logon account, dependencies, and recovery options.

.PARAMETER InputPath
    The path to the CSV file containing the services configuration to import.

.PARAMETER BackupPath
    Optional path to save a backup of existing services configuration before importing. If not specified, no backup is created.

.PARAMETER SkipExisting
    If specified, existing services will be skipped instead of being updated.

.PARAMETER CreateMissing
    If specified, services that don't exist on the target computer will be created if possible.

.PARAMETER ServicePassword
    SecureString password to use for service accounts when creating or updating services. Required when using custom accounts.

.PARAMETER LogPath
    The path where the log file will be saved. Default is "ServicesImport.log" in the current directory.

.EXAMPLE
    .\Import-WindowsServices.ps1 -InputPath "C:\Backup\services.csv"

.EXAMPLE
    $SecurePass = ConvertTo-SecureString "ServicePassword" -AsPlainText -Force
    .\Import-WindowsServices.ps1 -InputPath "services.csv" -BackupPath "C:\Backup\services_backup.csv" -ServicePassword $SecurePass -CreateMissing

.EXAMPLE
    .\Import-WindowsServices.ps1 -InputPath "services.csv" -SkipExisting
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$InputPath,
    
    [string]$BackupPath,
    
    [switch]$SkipExisting,
    
    [switch]$CreateMissing,
    
    [SecureString]$ServicePassword,
    
    [string]$LogPath = ".\ServicesImport.log"
)

# Function to write to log file
function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("INFO", "WARNING", "ERROR", "SUCCESS")]
        [string]$Level = "INFO"
    )
    
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogMessage = "[$Timestamp] [$Level] $Message"
    
    # Output to console with color
    switch ($Level) {
        "INFO"    { Write-Host $LogMessage -ForegroundColor Gray }
        "WARNING" { Write-Host $LogMessage -ForegroundColor Yellow }
        "ERROR"   { Write-Host $LogMessage -ForegroundColor Red }
        "SUCCESS" { Write-Host $LogMessage -ForegroundColor Green }
    }
    
    # Write to log file
    Add-Content -Path $LogPath -Value $LogMessage
}

# Function to convert string to array
function Convert-StringToArray {
    param($String)
    if ([string]::IsNullOrEmpty($String)) { return $null }
    return $String -split ";"
}

# Function to set service recovery options
function Set-ServiceRecoveryOptions {
    param(
        [string]$ServiceName,
        [string]$RecoveryOptions
    )
    
    if ([string]::IsNullOrEmpty($RecoveryOptions)) {
        return $true
    }
    
    try {
        $actions = $RecoveryOptions -split ";"
        $actionCount = [math]::Floor($actions.Count / 3)
        
        $resetPeriod = 86400 # 1 day in seconds
        $command = ""
        $rebootMessage = ""
        
        $sc = New-Object -ComObject "ScriptControl"
        $sc.Language = "VBScript"
        $sc.AddCode(@"
            Function SetRecoveryOptions(serviceName, actions, resetPeriod, command, rebootMsg)
                Dim wmi, service
                Set wmi = GetObject("winmgmts:{impersonationLevel=impersonate}!\\.\root\cimv2")
                Set service = wmi.Get("Win32_Service.Name='" & serviceName & "'")
                
                Dim result
                result = service.SetFailureActions(resetPeriod, command, rebootMsg, actions)
                
                SetRecoveryOptions = result = 0
            End Function
"@)
        
        $actionArray = @()
        
        for ($i = 0; $i -lt $actionCount; $i++) {
            $actionType = $actions[$i*3]
            $delay = 0
            
            if ($i*3+1 -lt $actions.Count) {
                [int]::TryParse($actions[$i*3+1], [ref]$delay)
            }
            
            switch ($actionType) {
                "None" { $actionArray += 0, $delay, 0 }
                "Restart" { $actionArray += 1, $delay, 0 }
                "Reboot" { $actionArray += 2, $delay, 0 }
                "RunCommand" { $actionArray += 3, $delay, 0 }
            }
        }
        
        $result = $sc.Run("SetRecoveryOptions", $ServiceName, $actionArray, $resetPeriod, $command, $rebootMessage)
        return $result
    }
    catch {
        Write-Log "Failed to set recovery options for service '$ServiceName': $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

# Function to set service startup type including delayed start
function Set-ServiceStartupType {
    param(
        [string]$ServiceName,
        [string]$StartupType,
        [bool]$DelayedAutoStart
    )
    
    try {
        # Set basic startup type
        Set-Service -Name $ServiceName -StartupType $StartupType
        
        # Set delayed auto-start if needed
        if ($StartupType -eq "Automatic" -and $DelayedAutoStart) {
            $service = Get-WmiObject -Class Win32_Service -Filter "Name='$ServiceName'"
            $result = $service.ChangeStartMode("Automatic")
            
            if ($result.ReturnValue -eq 0) {
                # Use registry to set delayed auto-start
                $regPath = "HKLM:\SYSTEM\CurrentControlSet\Services\$ServiceName"
                if (Test-Path $regPath) {
                    Set-ItemProperty -Path $regPath -Name "DelayedAutostart" -Value 1 -Type DWORD
                    Write-Log "Set delayed auto-start for service '$ServiceName'" -Level "SUCCESS"
                }
            }
        }
        
        return $true
    }
    catch {
        Write-Log "Failed to set startup type for service '$ServiceName': $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

# Function to create a new service
function New-WindowsServiceEx {
    param(
        [string]$Name,
        [string]$DisplayName,
        [string]$Description,
        [string]$Path,
        [string]$StartupType,
        [bool]$DelayedAutoStart,
        [string]$Account,
        [SecureString]$Password
    )
    
    try {
        # Convert startup type to SC format
        $scStartType = switch ($StartupType) {
            "Automatic" { "auto" }
            "Manual" { "demand" }
            "Disabled" { "disabled" }
            default { "auto" }
        }
        
        # Create service using SC command
        $accountParam = ""
        if ($Account -ne "LocalSystem" -and $Account -ne "NT AUTHORITY\LocalService" -and $Account -ne "NT AUTHORITY\NetworkService") {
            if ($null -eq $Password) {
                Write-Log "Password required for account '$Account'" -Level "ERROR"
                return $false
            }
            
            $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password)
            $plainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
            $accountParam = "obj= ""$Account"" password= ""$plainPassword"""
        }
        else {
            $accountParam = "obj= ""$Account"""
        }
        
        $createCommand = "sc.exe create ""$Name"" binPath= ""$Path"" DisplayName= ""$DisplayName"" start= $scStartType $accountParam"
        Invoke-Expression $createCommand | Out-Null
        
        # Set description
        if (-not [string]::IsNullOrEmpty($Description)) {
            $descCommand = "sc.exe description ""$Name"" ""$Description"""
            Invoke-Expression $descCommand | Out-Null
        }
        
        # Set delayed start if needed
        if ($StartupType -eq "Automatic" -and $DelayedAutoStart) {
            $regPath = "HKLM:\SYSTEM\CurrentControlSet\Services\$Name"
            if (Test-Path $regPath) {
                Set-ItemProperty -Path $regPath -Name "DelayedAutostart" -Value 1 -Type DWORD
            }
        }
        
        Write-Log "Successfully created service '$Name'" -Level "SUCCESS"
        return $true
    }
    catch {
        Write-Log "Failed to create service '$Name': $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

# Function to set service dependencies
function Set-ServiceDependencies {
    param(
        [string]$ServiceName,
        [string]$Dependencies
    )
    
    if ([string]::IsNullOrEmpty($Dependencies)) {
        return $true
    }
    
    try {
        $deps = Convert-StringToArray -String $Dependencies
        
        # Format dependencies for sc.exe command
        $depsString = ""
        foreach ($dep in $deps) {
            $depsString += "/$dep"
        }
        
        if (-not [string]::IsNullOrEmpty($depsString)) {
            $command = "sc.exe config ""$ServiceName"" depend= $depsString"
            Invoke-Expression $command | Out-Null
            Write-Log "Set dependencies for service '$ServiceName'" -Level "SUCCESS"
        }
        
        return $true
    }
    catch {
        Write-Log "Failed to set dependencies for service '$ServiceName': $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

# Initialize log file
$null = New-Item -Path $LogPath -ItemType File -Force
Write-Log "Starting import of Windows services..." -Level "INFO"

# Check if input file exists
if (-not (Test-Path -Path $InputPath)) {
    Write-Log "Input file not found: $InputPath" -Level "ERROR"
    exit 1
}

try {
    # Import services from CSV
    Write-Log "Importing services from: $InputPath" -Level "INFO"
    $services = Import-Csv -Path $InputPath
    
    # Create backup if requested
    if ($BackupPath) {
        Write-Log "Creating backup of existing services to: $BackupPath" -Level "INFO"
        
        $existingServices = Get-Service | ForEach-Object {
            $serviceDetails = Get-WmiObject -Class Win32_Service -Filter "Name='$($_.Name)'"
            
            # Get delayed auto-start status
            $delayedStart = $false
            try {
                $regPath = "HKLM:\SYSTEM\CurrentControlSet\Services\$($_.Name)"
                if (Test-Path $regPath) {
                    $delayedStart = (Get-ItemProperty -Path $regPath -Name "DelayedAutostart" -ErrorAction SilentlyContinue).DelayedAutostart -eq 1
                }
            }
            catch {
                # Ignore errors
            }
            
            # Get service dependencies
            $dependencies = $_.ServicesDependedOn | Select-Object -ExpandProperty Name
            $dependenciesString = if ($dependencies) { $dependencies -join ";" } else { "" }
            
            [PSCustomObject]@{
                Name = $_.Name
                DisplayName = $_.DisplayName
                Description = $serviceDetails.Description
                StartupType = $_.StartType
                DelayedAutoStart = $delayedStart
                Path = $serviceDetails.PathName
                Account = $serviceDetails.StartName
                Dependencies = $dependenciesString
                Status = $_.Status
                ServiceType = $serviceDetails.ServiceType
                StartMode = $serviceDetails.StartMode
            }
        }
        
        $existingServices | Export-Csv -Path $BackupPath -NoTypeInformation -Encoding UTF8
        Write-Log "Backup created successfully with $($existingServices.Count) services" -Level "SUCCESS"
    }
    
    # Process services
    $totalServices = $services.Count
    $importedCount = 0
    $skippedCount = 0
    $errorCount = 0
    $currentService = 0
    
    foreach ($service in $services) {
        $currentService++
        Write-Progress -Activity "Importing Services" -Status "Processing service $currentService of $totalServices" -PercentComplete (($currentService / $totalServices) * 100)
        
        $serviceName = $service.Name
        
        # Check if service exists
        $existingService = $null
        try {
            $existingService = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
        }
        catch {
            # Service doesn't exist
        }
        
        if ($existingService) {
            if ($SkipExisting) {
                Write-Log "Skipping existing service: $serviceName" -Level "WARNING"
                $skippedCount++
                continue
            }
            
            Write-Log "Updating existing service: $serviceName" -Level "INFO"
            
            try {
                # Stop service if running and can be stopped
                if ($existingService.Status -eq "Running" -and $existingService.CanStop) {
                    Stop-Service -Name $serviceName -Force
                    Write-Log "Stopped service '$serviceName' for configuration update" -Level "INFO"
                }
                
                # Update startup type
                $startupType = $service.StartupType
                $delayedStart = $service.DelayedAutoStart -eq "True"
                
                Set-ServiceStartupType -ServiceName $serviceName -StartupType $startupType -DelayedAutoStart $delayedStart
                
                # Update service account if provided
                $account = $service.Account
                if (-not [string]::IsNullOrEmpty($account) -and $account -ne "LocalSystem" -and $account -ne "NT AUTHORITY\LocalService" -and $account -ne "NT AUTHORITY\NetworkService") {
                    if ($null -eq $ServicePassword) {
                        Write-Log "Password required to update service account for '$serviceName'" -Level "WARNING"
                    }
                    else {
                        $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($ServicePassword)
                        $plainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
                        
                        $command = "sc.exe config ""$serviceName"" obj= ""$account"" password= ""$plainPassword"""
                        Invoke-Expression $command | Out-Null
                        Write-Log "Updated service account for '$serviceName'" -Level "SUCCESS"
                    }
                }
                
                # Update dependencies
                Set-ServiceDependencies -ServiceName $serviceName -Dependencies $service.Dependencies
                
                # Update recovery options
                Set-ServiceRecoveryOptions -ServiceName $serviceName -RecoveryOptions $service.RecoveryOptions
                
                # Update description if different
                $currentDesc = (Get-WmiObject -Class Win32_Service -Filter "Name='$serviceName'").Description
                if ($currentDesc -ne $service.Description) {
                    $descCommand = "sc.exe description ""$serviceName"" ""$($service.Description)"""
                    Invoke-Expression $descCommand | Out-Null
                    Write-Log "Updated description for service '$serviceName'" -Level "SUCCESS"
                }
                
                # Restart service if it was running
                if ($existingService.Status -eq "Running") {
                    Start-Service -Name $serviceName
                    Write-Log "Restarted service '$serviceName'" -Level "SUCCESS"
                }
                
                $importedCount++
                Write-Log "Successfully updated service: $serviceName" -Level "SUCCESS"
            }
            catch {
                Write-Log "Failed to update service '$serviceName': $($_.Exception.Message)" -Level "ERROR"
                $errorCount++
            }
        }
        elseif ($CreateMissing) {
            Write-Log "Creating new service: $serviceName" -Level "INFO"
            
            try {
                # Create new service
                $result = New-WindowsServiceEx -Name $serviceName `
                                             -DisplayName $service.DisplayName `
                                             -Description $service.Description `
                                             -Path $service.Path `
                                             -StartupType $service.StartupType `
                                             -DelayedAutoStart ($service.DelayedAutoStart -eq "True") `
                                             -Account $service.Account `
                                             -Password $ServicePassword
                
                if ($result) {
                    # Set dependencies
                    Set-ServiceDependencies -ServiceName $serviceName -Dependencies $service.Dependencies
                    
                    # Set recovery options
                    Set-ServiceRecoveryOptions -ServiceName $serviceName -RecoveryOptions $service.RecoveryOptions
                    
                    $importedCount++
                    Write-Log "Successfully created service: $serviceName" -Level "SUCCESS"
                }
                else {
                    $errorCount++
                }
            }
            catch {
                Write-Log "Failed to create service '$serviceName': $($_.Exception.Message)" -Level "ERROR"
                $errorCount++
            }
        }
        else {
            Write-Log "Service '$serviceName' does not exist and -CreateMissing not specified" -Level "WARNING"
            $skippedCount++
        }
    }
    
    Write-Progress -Activity "Importing Services" -Completed
    
    Write-Log "Import completed!" -Level "SUCCESS"
    Write-Log "Total services processed: $totalServices" -Level "INFO"
    Write-Log "Services successfully imported/updated: $importedCount" -Level "SUCCESS"
    Write-Log "Services skipped: $skippedCount" -Level "INFO"
    Write-Log "Services with errors: $errorCount" -Level "WARNING"
}
catch {
    Write-Log "An error occurred during import: $($_.Exception.Message)" -Level "ERROR"
    exit 1
}
