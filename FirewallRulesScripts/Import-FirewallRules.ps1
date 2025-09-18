#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Imports Windows Firewall rules from a CSV file.

.DESCRIPTION
    This script imports Windows Firewall rules from a CSV file created by the Export-FirewallRules.ps1 script.
    It recreates the firewall rules with all their properties including name, description, enabled status,
    direction, action, profiles, protocols, local/remote ports, local/remote addresses, programs, and services.

.PARAMETER InputPath
    The path to the CSV file containing the firewall rules to import.

.PARAMETER BackupPath
    Optional path to save a backup of existing firewall rules before importing. If not specified, no backup is created.

.PARAMETER SkipExisting
    If specified, existing rules with the same name will be skipped instead of being replaced.

.PARAMETER LogPath
    The path where the log file will be saved. Default is "FirewallRulesImport.log" in the current directory.

.EXAMPLE
    .\Import-FirewallRules.ps1 -InputPath "C:\Backup\firewall_rules.csv"

.EXAMPLE
    .\Import-FirewallRules.ps1 -InputPath "firewall_rules.csv" -BackupPath "C:\Backup\existing_rules.csv" -SkipExisting

.EXAMPLE
    .\Import-FirewallRules.ps1 -InputPath "firewall_rules.csv" -LogPath "C:\Logs\firewall_import.log"
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$InputPath,
    [string]$BackupPath,
    [switch]$SkipExisting,
    [string]$LogPath = ".\FirewallRulesImport.log"
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

# Function to convert profile string to enum value
function Convert-StringToProfile {
    param($ProfileString)
    $profileValue = 0
    
    $profileItems = $ProfileString -split ";"
    foreach ($profileItem in $profileItems) {
        switch ($profileItem) {
            "Domain"  { $profileValue = $profileValue -bor 1 }
            "Private" { $profileValue = $profileValue -bor 2 }
            "Public"  { $profileValue = $profileValue -bor 4 }
            "Any"     { $profileValue = $profileValue -bor 2147483647 }
        }
    }
    
    return $profileValue
}

# Function to convert interface type string to enum value
function Convert-StringToInterfaceType {
    param($InterfaceTypeString)
    $typeValue = 0
    
    if ($InterfaceTypeString -eq "All") { return 0 }
    
    $types = $InterfaceTypeString -split ";"
    foreach ($type in $types) {
        switch ($type) {
            "Wired"        { $typeValue = $typeValue -bor 1 }
            "Wireless"     { $typeValue = $typeValue -bor 2 }
            "RemoteAccess" { $typeValue = $typeValue -bor 4 }
        }
    }
    
    return $typeValue
}

# Initialize log file
$null = New-Item -Path $LogPath -ItemType File -Force
Write-Log "Starting import of Windows Firewall rules..." -Level "INFO"

# Check if input file exists
if (-not (Test-Path -Path $InputPath)) {
    Write-Log "Input file not found: $InputPath" -Level "ERROR"
    exit 1
}

# Create backup if requested
if ($BackupPath) {
    Write-Log "Creating backup of existing firewall rules to: $BackupPath" -Level "INFO"
    try {
        $existingRules = Get-NetFirewallRule | Select-Object Name, DisplayName, Description, Group, Enabled, Direction, Action, EdgeTraversalPolicy, LooseSourceMapping, LocalOnlyMapping, Owner
        $existingRules | Export-Csv -Path $BackupPath -NoTypeInformation -Encoding UTF8
        Write-Log "Backup created successfully with $($existingRules.Count) rules" -Level "SUCCESS"
    }
    catch {
        Write-Log "Failed to create backup: $($_.Exception.Message)" -Level "ERROR"
        exit 1
    }
}

# Import rules from CSV
try {
    Write-Log "Importing firewall rules from: $InputPath" -Level "INFO"
    $rules = Import-Csv -Path $InputPath
    
    $totalRules = $rules.Count
    $importedCount = 0
    $skippedCount = 0
    $errorCount = 0
    $currentRule = 0
    
    foreach ($rule in $rules) {
        $currentRule++
        Write-Progress -Activity "Importing Firewall Rules" -Status "Processing rule $currentRule of $totalRules" -PercentComplete (($currentRule / $totalRules) * 100)
        
        # Check if rule already exists
        $existingRule = Get-NetFirewallRule -Name $rule.Name -ErrorAction SilentlyContinue
        
        if ($existingRule -and $SkipExisting) {
            Write-Log "Skipping existing rule: $($rule.DisplayName) [$($rule.Name)]" -Level "WARNING"
            $skippedCount++
            continue
        }
        elseif ($existingRule) {
            Write-Log "Removing existing rule before recreation: $($rule.DisplayName) [$($rule.Name)]" -Level "INFO"
            Remove-NetFirewallRule -Name $rule.Name -ErrorAction SilentlyContinue
        }
        
        try {
            # Create base rule
            $params = @{
                Name = $rule.Name
                DisplayName = $rule.DisplayName
                Description = $rule.Description
                Direction = $rule.Direction
                Action = $rule.Action
                Enabled = $rule.Enabled -eq "True"
            }
            
            # Add optional parameters
            if (-not [string]::IsNullOrEmpty($rule.Group)) { $params.Group = $rule.Group }
            if (-not [string]::IsNullOrEmpty($rule.EdgeTraversalPolicy)) { $params.EdgeTraversalPolicy = $rule.EdgeTraversalPolicy }
            if (-not [string]::IsNullOrEmpty($rule.Owner)) { $params.Owner = $rule.Owner }
            
            # Set profile
            if (-not [string]::IsNullOrEmpty($rule.Profile)) {
                $profileValue = Convert-StringToProfile $rule.Profile
                $params.Profile = $profileValue
            }
            
            # Create the rule
            $newRule = New-NetFirewallRule @params -ErrorAction Stop
            
            # Set address filter
            $addressParams = @{}
            if (-not [string]::IsNullOrEmpty($rule.LocalAddress)) { 
                $addressParams.LocalAddress = Convert-StringToArray $rule.LocalAddress 
            }
            if (-not [string]::IsNullOrEmpty($rule.RemoteAddress)) { 
                $addressParams.RemoteAddress = Convert-StringToArray $rule.RemoteAddress 
            }
            if ($addressParams.Count -gt 0) {
                $newRule | Set-NetFirewallAddressFilter @addressParams -ErrorAction SilentlyContinue
            }
            
            # Set port filter
            $portParams = @{}
            if (-not [string]::IsNullOrEmpty($rule.Protocol)) { $portParams.Protocol = $rule.Protocol }
            if (-not [string]::IsNullOrEmpty($rule.LocalPort)) { 
                $portParams.LocalPort = Convert-StringToArray $rule.LocalPort 
            }
            if (-not [string]::IsNullOrEmpty($rule.RemotePort)) { 
                $portParams.RemotePort = Convert-StringToArray $rule.RemotePort 
            }
            if (-not [string]::IsNullOrEmpty($rule.IcmpType)) { 
                $portParams.IcmpType = Convert-StringToArray $rule.IcmpType 
            }
            if (-not [string]::IsNullOrEmpty($rule.DynamicTarget)) { 
                $portParams.DynamicTarget = $rule.DynamicTarget 
            }
            if ($portParams.Count -gt 0) {
                $newRule | Set-NetFirewallPortFilter @portParams -ErrorAction SilentlyContinue
            }
            
            # Set application filter
            $appParams = @{}
            if (-not [string]::IsNullOrEmpty($rule.Program)) { $appParams.Program = $rule.Program }
            if (-not [string]::IsNullOrEmpty($rule.Package)) { $appParams.Package = $rule.Package }
            if ($appParams.Count -gt 0) {
                $newRule | Set-NetFirewallApplicationFilter @appParams -ErrorAction SilentlyContinue
            }
            
            # Set service filter
            if (-not [string]::IsNullOrEmpty($rule.Service)) {
                $newRule | Set-NetFirewallServiceFilter -Service $rule.Service -ErrorAction SilentlyContinue
            }
            
            # Set security filter
            $secParams = @{}
            if (-not [string]::IsNullOrEmpty($rule.Authentication)) { $secParams.Authentication = $rule.Authentication }
            if (-not [string]::IsNullOrEmpty($rule.Encryption)) { $secParams.Encryption = $rule.Encryption }
            if (-not [string]::IsNullOrEmpty($rule.OverrideBlockRules)) { 
                $secParams.OverrideBlockRules = $rule.OverrideBlockRules -eq "True" 
            }
            if (-not [string]::IsNullOrEmpty($rule.LocalUser)) { $secParams.LocalUser = $rule.LocalUser }
            if (-not [string]::IsNullOrEmpty($rule.RemoteUser)) { $secParams.RemoteUser = $rule.RemoteUser }
            if (-not [string]::IsNullOrEmpty($rule.RemoteMachine)) { $secParams.RemoteMachine = $rule.RemoteMachine }
            if ($secParams.Count -gt 0) {
                $newRule | Set-NetFirewallSecurityFilter @secParams -ErrorAction SilentlyContinue
            }
            
            # Set interface filter
            if (-not [string]::IsNullOrEmpty($rule.InterfaceAlias)) {
                $newRule | Set-NetFirewallInterfaceFilter -InterfaceAlias (Convert-StringToArray $rule.InterfaceAlias) -ErrorAction SilentlyContinue
            }
            
            # Set interface type filter
            if (-not [string]::IsNullOrEmpty($rule.InterfaceType)) {
                $typeValue = Convert-StringToInterfaceType $rule.InterfaceType
                $newRule | Set-NetFirewallInterfaceTypeFilter -InterfaceType $typeValue -ErrorAction SilentlyContinue
            }
            
            Write-Log "Successfully imported rule: $($rule.DisplayName) [$($rule.Name)]" -Level "SUCCESS"
            $importedCount++
        }
        catch {
            Write-Log "Failed to import rule $($rule.DisplayName) [$($rule.Name)]: $($_.Exception.Message)" -Level "ERROR"
            $errorCount++
        }
    }
    
    Write-Progress -Activity "Importing Firewall Rules" -Completed
    
    Write-Log "Import completed!" -Level "SUCCESS"
    Write-Log "Total rules processed: $totalRules" -Level "INFO"
    Write-Log "Rules successfully imported: $importedCount" -Level "SUCCESS"
    Write-Log "Rules skipped: $skippedCount" -Level "INFO"
    Write-Log "Rules with errors: $errorCount" -Level "WARNING"
}
catch {
    Write-Log "An error occurred during import: $($_.Exception.Message)" -Level "ERROR"
    exit 1
}
