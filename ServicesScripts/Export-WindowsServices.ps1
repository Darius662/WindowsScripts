#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Exports Windows services configuration to a CSV file.

.DESCRIPTION
    This script exports Windows services configuration from the current computer to a CSV file
    that can be used for migration to another computer. It captures all relevant service properties
    including name, display name, description, path, startup type, logon account, dependencies,
    and recovery options.

.PARAMETER OutputPath
    The path where the CSV file will be saved. Default is "ServicesExport.csv" in the current directory.

.PARAMETER IncludeSystemServices
    If specified, system services will also be exported. By default, only non-system services are exported.

.PARAMETER IncludeDisabledServices
    If specified, disabled services will also be exported. By default, only non-disabled services are exported.

.PARAMETER FilterByName
    Optional filter to export only services whose Name or DisplayName matches the specified wildcard pattern.

.PARAMETER FilterByStartupType
    Optional filter to export only services with specific startup type (Automatic, AutomaticDelayedStart, Manual, Disabled).

.EXAMPLE
    .\Export-WindowsServices.ps1 -OutputPath "C:\Backup\services.csv"

.EXAMPLE
    .\Export-WindowsServices.ps1 -IncludeSystemServices -FilterByName "SQL*"

.EXAMPLE
    .\Export-WindowsServices.ps1 -FilterByStartupType "Automatic" -IncludeDisabledServices
#>

param(
    [string]$OutputPath = ".\ServicesExport.csv",
    [switch]$IncludeSystemServices,
    [switch]$IncludeDisabledServices,
    [string]$FilterByName,
    [ValidateSet("Automatic", "AutomaticDelayedStart", "Manual", "Disabled", "")]
    [string]$FilterByStartupType = ""
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

# Function to check if a service is a system service
function Test-SystemService {
    param([string]$ServiceName)
    
    $systemServices = @(
        "AppIDSvc", "Appinfo", "AppMgmt", "AppReadiness", "AppXSvc", "AudioEndpointBuilder", 
        "Audiosrv", "BFE", "BITS", "BrokerInfrastructure", "Browser", "BthAvctpSvc", "BthHFSrv", 
        "bthserv", "CDPSvc", "CertPropSvc", "ClipSVC", "COMSysApp", "CoreMessagingRegistrar", 
        "CryptSvc", "DcomLaunch", "DeviceAssociationService", "DeviceInstall", "Dhcp", "DiagTrack", 
        "Dnscache", "DoSvc", "DPS", "DsmSvc", "DsSvc", "DusmSvc", "EapHost", "EFS", "embeddedmode", 
        "EventLog", "EventSystem", "Fax", "fdPHost", "FDResPub", "FontCache", "FrameServer", 
        "gpsvc", "hidserv", "hns", "HvHost", "IKEEXT", "InstallService", "iphlpsvc", "KeyIso", 
        "KPSSVC", "KtmRm", "LanmanServer", "LanmanWorkstation", "lfsvc", "LicenseManager", 
        "lltdsvc", "lmhosts", "LSM", "MapsBroker", "MpsSvc", "MSDTC", "MSiSCSI", "msiserver", 
        "NcaSvc", "NcbService", "Netlogon", "Netman", "netprofm", "NetSetupSvc", "NgcCtnrSvc", 
        "NgcSvc", "NlaSvc", "nsi", "PcaSvc", "PerfHost", "pla", "PlugPlay", "PolicyAgent", 
        "Power", "PrintNotify", "ProfSvc", "PushToInstall", "QWAVE", "RasAuto", "RasMan", 
        "RemoteAccess", "RemoteRegistry", "RmSvc", "RpcEptMapper", "RpcLocator", "RpcSs", 
        "SamSs", "SCardSvr", "ScDeviceEnum", "Schedule", "SCPolicySvc", "SDRSVC", "seclogon", 
        "SecurityHealthService", "SEMgrSvc", "SENS", "Sense", "SensorDataService", "SensorService", 
        "SensrSvc", "SessionEnv", "SharedAccess", "ShellHWDetection", "shpamsvc", "smphost", 
        "SmsRouter", "SNMPTRAP", "Spooler", "SSDPSRV", "SstpSvc", "StateRepository", "stisvc", 
        "StorSvc", "svsvc", "swprv", "SysMain", "SystemEventsBroker", "TabletInputService", 
        "TapiSrv", "TermService", "Themes", "tiledatamodelsvc", "TimeBrokerSvc", "TrkWks", 
        "TrustedInstaller", "tzautoupdate", "UevAgentService", "UmRdpService", "upnphost", 
        "UserManager", "UsoSvc", "VaultSvc", "vds", "vmcompute", "vmicguestinterface", 
        "vmicheartbeat", "vmickvpexchange", "vmicrdv", "vmicshutdown", "vmictimesync", 
        "vmicvmsession", "vmicvss", "VSS", "W32Time", "WaaSMedicSvc", "WalletService", 
        "WarpJITSvc", "WbioSrvc", "Wcmsvc", "WdiServiceHost", "WdiSystemHost", "WdNisSvc", 
        "WebClient", "Wecsvc", "WEPHOSTSVC", "wercplsupport", "WerSvc", "WiaRpc", "WinDefend", 
        "WinHttpAutoProxySvc", "Winmgmt", "WinRM", "wisvc", "WlanSvc", "wlidsvc", "wlpasvc", 
        "WManSvc", "wmiApSrv", "WMPNetworkSvc", "workfolderssvc", "WpcMonSvc", "WPDBusEnum", 
        "WpnService", "wscsvc", "WSearch", "wuauserv", "wudfsvc", "WwanSvc", "XblAuthManager", 
        "XblGameSave", "XboxGipSvc", "XboxNetApiSvc"
    )
    
    return $systemServices -contains $ServiceName
}

# Function to get service recovery options
function Get-ServiceRecoveryOptions {
    param([string]$ServiceName)
    
    try {
        $sc = New-Object -ComObject "ScriptControl"
        $sc.Language = "VBScript"
        $sc.AddCode(@"
            Function GetRecoveryOptions(serviceName)
                Dim wmi, service, actions
                Set wmi = GetObject("winmgmts:{impersonationLevel=impersonate}!\\.\root\cimv2")
                Set service = wmi.Get("Win32_Service.Name='" & serviceName & "'")
                
                Dim result
                result = service.GetFailureActions(, , , actions)
                
                Dim actionList
                actionList = ""
                
                If IsArray(actions) Then
                    For i = 0 To UBound(actions) Step 3
                        Select Case actions(i)
                            Case 0
                                actionList = actionList & "None;"
                            Case 1
                                actionList = actionList & "Restart;" & actions(i+1) & ";"
                            Case 2
                                actionList = actionList & "Reboot;" & actions(i+1) & ";"
                            Case 3
                                actionList = actionList & "RunCommand;" & actions(i+1) & ";"
                        End Select
                    Next
                End If
                
                GetRecoveryOptions = actionList
            End Function
"@)
        
        $recoveryString = $sc.Run("GetRecoveryOptions", $ServiceName)
        return $recoveryString
    }
    catch {
        return ""
    }
}

# Function to get service delayed auto-start status
function Get-ServiceDelayedStart {
    param([string]$ServiceName)
    
    try {
        $service = Get-WmiObject -Class Win32_Service -Filter "Name='$ServiceName'"
        $delayedAutoStart = $service.DelayedAutoStart
        return $delayedAutoStart
    }
    catch {
        return $false
    }
}

Write-Host "Starting export of Windows services..." -ForegroundColor Green

# Initialize array to store data
$ExportData = @()

try {
    # Get services
    Write-Host "Collecting Windows services..." -ForegroundColor Yellow
    $Services = Get-Service
    
    # Apply filters
    if (-not $IncludeDisabledServices) {
        $Services = $Services | Where-Object { $_.StartType -ne "Disabled" }
    }
    
    if ($FilterByName) {
        $Services = $Services | Where-Object { $_.Name -like $FilterByName -or $_.DisplayName -like $FilterByName }
    }
    
    if ($FilterByStartupType) {
        if ($FilterByStartupType -eq "AutomaticDelayedStart") {
            $Services = $Services | Where-Object { $_.StartType -eq "Automatic" }
            # We'll filter for delayed start later
        }
        else {
            $Services = $Services | Where-Object { $_.StartType -eq $FilterByStartupType }
        }
    }
    
    $TotalServices = $Services.Count
    $CurrentService = 0
    
    foreach ($Service in $Services) {
        $CurrentService++
        Write-Progress -Activity "Exporting Services" -Status "Processing service $CurrentService of $TotalServices" -PercentComplete (($CurrentService / $TotalServices) * 100)
        
        # Skip system services if not included
        if (-not $IncludeSystemServices -and (Test-SystemService -ServiceName $Service.Name)) {
            continue
        }
        
        # Get additional service details
        $ServiceDetails = Get-WmiObject -Class Win32_Service -Filter "Name='$($Service.Name)'"
        
        # Skip if service details not found
        if (-not $ServiceDetails) {
            Write-Warning "Could not get details for service: $($Service.Name)"
            continue
        }
        
        # Check for delayed start
        $DelayedStart = Get-ServiceDelayedStart -ServiceName $Service.Name
        
        # Skip if filtering by delayed start and this doesn't match
        if ($FilterByStartupType -eq "AutomaticDelayedStart" -and -not $DelayedStart) {
            continue
        }
        
        # Get service dependencies
        $Dependencies = $Service.ServicesDependedOn | Select-Object -ExpandProperty Name
        
        # Get service recovery options
        $RecoveryOptions = Get-ServiceRecoveryOptions -ServiceName $Service.Name
        
        # Create service data object
        $ServiceData = [PSCustomObject]@{
            Name = $Service.Name
            DisplayName = $Service.DisplayName
            Description = $ServiceDetails.Description
            StartupType = $Service.StartType
            DelayedAutoStart = $DelayedStart
            Path = $ServiceDetails.PathName
            Account = $ServiceDetails.StartName
            Dependencies = Convert-ArrayToString -Array $Dependencies
            RecoveryOptions = $RecoveryOptions
            Status = $Service.Status
            CanStop = $Service.CanStop
            CanPauseAndContinue = $Service.CanPauseAndContinue
            CanShutdown = $Service.CanShutdown
            ServiceType = $ServiceDetails.ServiceType
            StartMode = $ServiceDetails.StartMode
            ErrorControl = $ServiceDetails.ErrorControl
            TagId = $ServiceDetails.TagId
            LoadOrderGroup = $ServiceDetails.LoadOrderGroup
            DesktopInteract = $ServiceDetails.DesktopInteract
            AcceptStop = $ServiceDetails.AcceptStop
            AcceptPause = $ServiceDetails.AcceptPause
            SystemCreated = (Test-SystemService -ServiceName $Service.Name)
        }
        
        $ExportData += $ServiceData
    }
    
    Write-Progress -Activity "Exporting Services" -Completed
    
    # Export to CSV
    Write-Host "Exporting data to CSV: $OutputPath" -ForegroundColor Yellow
    $ExportData | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8
    
    Write-Host "Export completed successfully!" -ForegroundColor Green
    Write-Host "Total services exported: $($ExportData.Count)" -ForegroundColor Cyan
    Write-Host "CSV file saved to: $OutputPath" -ForegroundColor Cyan
}
catch {
    Write-Error "An error occurred during export: $($_.Exception.Message)"
    exit 1
}
