#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Exports Windows Firewall rules to a CSV file.

.DESCRIPTION
    This script exports Windows Firewall rules from the current computer to a CSV file
    that can be used for migration to another computer. It captures all relevant rule properties
    including name, description, enabled status, direction, action, profiles, protocols,
    local/remote ports, local/remote addresses, programs, and services.

.PARAMETER OutputPath
    The path where the CSV file will be saved. Default is "FirewallRulesExport.csv" in the current directory.

.PARAMETER IncludeDisabledRules
    If specified, disabled firewall rules will also be exported. By default, only enabled rules are exported.

.PARAMETER FilterByDisplayName
    Optional filter to export only rules whose DisplayName matches the specified wildcard pattern.

.PARAMETER FilterByProfile
    Optional filter to export only rules that apply to specific profiles (Domain, Private, Public, Any).

.PARAMETER FilterByDirection
    Optional filter to export only rules with specific direction (Inbound, Outbound).

.EXAMPLE
    .\Export-FirewallRules.ps1 -OutputPath "C:\Backup\firewall_rules.csv"

.EXAMPLE
    .\Export-FirewallRules.ps1 -IncludeDisabledRules -FilterByDisplayName "Remote Desktop*"

.EXAMPLE
    .\Export-FirewallRules.ps1 -FilterByProfile "Public" -FilterByDirection "Inbound"
#>

param(
    [string]$OutputPath = ".\FirewallRulesExport.csv",
    [switch]$IncludeDisabledRules,
    [string]$FilterByDisplayName,
    [ValidateSet("Domain", "Private", "Public", "Any", "")]
    [string]$FilterByProfile = "",
    [ValidateSet("Inbound", "Outbound", "")]
    [string]$FilterByDirection = ""
)

# Function to safely get property value
function Get-SafeProperty {
    param($Object, $PropertyName)
    try {
        return $Object.$PropertyName
    }
    catch {
        return $null
    }
}

# Function to convert array to string
function Convert-ArrayToString {
    param($Array)
    if ($null -eq $Array) { return "" }
    if ($Array -is [array]) {
        return ($Array -join ";")
    }
    return $Array.ToString()
}

# Function to convert profile enum to string
function Convert-ProfileToString {
    param($ProfileValue)
    $profiles = @()
    
    if ($ProfileValue -band 1) { $profiles += "Domain" }
    if ($ProfileValue -band 2) { $profiles += "Private" }
    if ($ProfileValue -band 4) { $profiles += "Public" }
    if ($ProfileValue -band 2147483647) { $profiles += "Any" }
    
    return ($profiles -join ";")
}

# Function to convert interface type enum to string
function Convert-InterfaceTypeToString {
    param($InterfaceTypeValue)
    $types = @()
    
    if ($InterfaceTypeValue -band 1) { $types += "Wired" }
    if ($InterfaceTypeValue -band 2) { $types += "Wireless" }
    if ($InterfaceTypeValue -band 4) { $types += "RemoteAccess" }
    
    if ($types.Count -eq 0) { return "All" }
    return ($types -join ";")
}

Write-Host "Starting export of Windows Firewall rules..." -ForegroundColor Green

# Initialize array to store data
$ExportData = @()

try {
    # Get firewall rules
    Write-Host "Collecting firewall rules..." -ForegroundColor Yellow
    $FirewallRules = Get-NetFirewallRule -ErrorAction SilentlyContinue
    
    # Apply filters if specified
    if (-not $IncludeDisabledRules) {
        $FirewallRules = $FirewallRules | Where-Object { $_.Enabled -eq "True" }
    }
    
    if ($FilterByDisplayName) {
        $FirewallRules = $FirewallRules | Where-Object { $_.DisplayName -like $FilterByDisplayName }
    }
    
    if ($FilterByProfile) {
        $FirewallRules = $FirewallRules | Where-Object { $_.Profile -match $FilterByProfile }
    }
    
    if ($FilterByDirection) {
        $FirewallRules = $FirewallRules | Where-Object { $_.Direction -eq $FilterByDirection }
    }
    
    $TotalRules = $FirewallRules.Count
    $CurrentRule = 0
    
    foreach ($Rule in $FirewallRules) {
        $CurrentRule++
        Write-Progress -Activity "Exporting Firewall Rules" -Status "Processing rule $CurrentRule of $TotalRules" -PercentComplete (($CurrentRule / $TotalRules) * 100)
        
        # Get additional rule properties
        $AddressFilter = Get-NetFirewallAddressFilter -AssociatedNetFirewallRule $Rule -ErrorAction SilentlyContinue
        $PortFilter = Get-NetFirewallPortFilter -AssociatedNetFirewallRule $Rule -ErrorAction SilentlyContinue
        $ApplicationFilter = Get-NetFirewallApplicationFilter -AssociatedNetFirewallRule $Rule -ErrorAction SilentlyContinue
        $ServiceFilter = Get-NetFirewallServiceFilter -AssociatedNetFirewallRule $Rule -ErrorAction SilentlyContinue
        $SecurityFilter = Get-NetFirewallSecurityFilter -AssociatedNetFirewallRule $Rule -ErrorAction SilentlyContinue
        $InterfaceFilter = Get-NetFirewallInterfaceFilter -AssociatedNetFirewallRule $Rule -ErrorAction SilentlyContinue
        $InterfaceTypeFilter = Get-NetFirewallInterfaceTypeFilter -AssociatedNetFirewallRule $Rule -ErrorAction SilentlyContinue
        
        # Create rule data object
        $RuleData = [PSCustomObject]@{
            Name = $Rule.Name
            DisplayName = $Rule.DisplayName
            Description = $Rule.Description
            Group = $Rule.Group
            Enabled = $Rule.Enabled
            Direction = $Rule.Direction
            Action = $Rule.Action
            EdgeTraversalPolicy = $Rule.EdgeTraversalPolicy
            LooseSourceMapping = $Rule.LooseSourceMapping
            LocalOnlyMapping = $Rule.LocalOnlyMapping
            Owner = $Rule.Owner
            
            # Profiles
            Profile = Convert-ProfileToString $Rule.Profile
            
            # Address Filter
            LocalAddress = Convert-ArrayToString (Get-SafeProperty $AddressFilter "LocalAddress")
            RemoteAddress = Convert-ArrayToString (Get-SafeProperty $AddressFilter "RemoteAddress")
            
            # Port Filter
            Protocol = Get-SafeProperty $PortFilter "Protocol"
            LocalPort = Convert-ArrayToString (Get-SafeProperty $PortFilter "LocalPort")
            RemotePort = Convert-ArrayToString (Get-SafeProperty $PortFilter "RemotePort")
            IcmpType = Convert-ArrayToString (Get-SafeProperty $PortFilter "IcmpType")
            DynamicTarget = Get-SafeProperty $PortFilter "DynamicTarget"
            
            # Application Filter
            Program = Get-SafeProperty $ApplicationFilter "Program"
            Package = Get-SafeProperty $ApplicationFilter "Package"
            
            # Service Filter
            Service = Get-SafeProperty $ServiceFilter "Service"
            
            # Security Filter
            Authentication = Get-SafeProperty $SecurityFilter "Authentication"
            Encryption = Get-SafeProperty $SecurityFilter "Encryption"
            OverrideBlockRules = Get-SafeProperty $SecurityFilter "OverrideBlockRules"
            LocalUser = Get-SafeProperty $SecurityFilter "LocalUser"
            RemoteUser = Get-SafeProperty $SecurityFilter "RemoteUser"
            RemoteMachine = Get-SafeProperty $SecurityFilter "RemoteMachine"
            
            # Interface Filter
            InterfaceAlias = Convert-ArrayToString (Get-SafeProperty $InterfaceFilter "InterfaceAlias")
            
            # Interface Type Filter
            InterfaceType = Convert-InterfaceTypeToString (Get-SafeProperty $InterfaceTypeFilter "InterfaceType")
        }
        
        $ExportData += $RuleData
    }
    
    Write-Progress -Activity "Exporting Firewall Rules" -Completed
    
    # Export to CSV
    Write-Host "Exporting data to CSV: $OutputPath" -ForegroundColor Yellow
    $ExportData | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8
    
    Write-Host "Export completed successfully!" -ForegroundColor Green
    Write-Host "Total firewall rules exported: $($ExportData.Count)" -ForegroundColor Cyan
    Write-Host "CSV file saved to: $OutputPath" -ForegroundColor Cyan
}
catch {
    Write-Error "An error occurred during export: $($_.Exception.Message)"
    exit 1
}
