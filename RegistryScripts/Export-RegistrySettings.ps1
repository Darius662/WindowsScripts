#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Exports registry keys and values to a CSV file.

.DESCRIPTION
    This script exports registry keys and values from specified paths to a CSV file
    that can be used for migration to another computer. It captures all relevant properties
    including key paths, value names, types, and data.

.PARAMETER RegistryPaths
    Array of registry paths to export. Each path should be in the format "HKLM:\Software\Microsoft\Windows".
    You can use any of the following registry hives: HKLM, HKCU, HKCR, HKU, HKCC.

.PARAMETER OutputPath
    The path where the CSV file will be saved. Default is "RegistryExport.csv" in the current directory.

.PARAMETER Recurse
    If specified, registry keys will be exported recursively (including all subkeys).

.PARAMETER ExcludePaths
    Array of registry paths to exclude from the export. Useful when recursively exporting large registry sections.

.PARAMETER IncludeEmptyValues
    If specified, registry keys with no values will also be exported.

.EXAMPLE
    .\Export-RegistrySettings.ps1 -RegistryPaths "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer" -OutputPath "C:\Backup\registry.csv" -Recurse

.EXAMPLE
    .\Export-RegistrySettings.ps1 -RegistryPaths @("HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run", "HKCU:\Software\Microsoft\Office")

.EXAMPLE
    .\Export-RegistrySettings.ps1 -RegistryPaths "HKLM:\SOFTWARE\Microsoft" -Recurse -ExcludePaths "HKLM:\SOFTWARE\Microsoft\Windows NT"
#>

param(
    [Parameter(Mandatory=$true)]
    [string[]]$RegistryPaths,
    
    [string]$OutputPath = ".\RegistryExport.csv",
    
    [switch]$Recurse,
    
    [string[]]$ExcludePaths = @(),
    
    [switch]$IncludeEmptyValues
)

# Function to convert registry path from HKLM:\ format to Registry:: format
function Convert-RegistryPath {
    param([string]$Path)
    
    $Path = $Path -replace '^HKLM:\\', 'HKEY_LOCAL_MACHINE\'
    $Path = $Path -replace '^HKCU:\\', 'HKEY_CURRENT_USER\'
    $Path = $Path -replace '^HKCR:\\', 'HKEY_CLASSES_ROOT\'
    $Path = $Path -replace '^HKU:\\', 'HKEY_USERS\'
    $Path = $Path -replace '^HKCC:\\', 'HKEY_CURRENT_CONFIG\'
    $Path = $Path -replace '\\', '\\'
    
    return "Registry::$Path"
}

# Function to convert registry path from Registry:: format to HKLM:\ format
function Convert-RegistryPathToStandard {
    param([string]$Path)
    
    $Path = $Path -replace '^Registry::HKEY_LOCAL_MACHINE\\', 'HKLM:\'
    $Path = $Path -replace '^Registry::HKEY_CURRENT_USER\\', 'HKCU:\'
    $Path = $Path -replace '^Registry::HKEY_CLASSES_ROOT\\', 'HKCR:\'
    $Path = $Path -replace '^Registry::HKEY_USERS\\', 'HKU:\'
    $Path = $Path -replace '^Registry::HKEY_CURRENT_CONFIG\\', 'HKCC:\'
    $Path = $Path -replace '^HKEY_LOCAL_MACHINE\\', 'HKLM:\'
    $Path = $Path -replace '^HKEY_CURRENT_USER\\', 'HKCU:\'
    $Path = $Path -replace '^HKEY_CLASSES_ROOT\\', 'HKCR:\'
    $Path = $Path -replace '^HKEY_USERS\\', 'HKU:\'
    $Path = $Path -replace '^HKEY_CURRENT_CONFIG\\', 'HKCC:\'
    
    return $Path
}

# Function to check if a path should be excluded
function Test-ExcludePath {
    param(
        [string]$Path,
        [string[]]$ExcludePaths
    )
    
    foreach ($ExcludePath in $ExcludePaths) {
        $standardExcludePath = Convert-RegistryPathToStandard $ExcludePath
        $standardPath = Convert-RegistryPathToStandard $Path
        
        if ($standardPath -eq $standardExcludePath -or $standardPath.StartsWith("$standardExcludePath\")) {
            return $true
        }
    }
    
    return $false
}

# Function to safely get registry value
function Get-SafeRegistryValue {
    param(
        [Microsoft.Win32.RegistryKey]$Key,
        [string]$ValueName
    )
    
    try {
        $value = $Key.GetValue($ValueName, $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
        return $value
    }
    catch {
        Write-Warning "Could not read value '$ValueName' from key '$($Key.Name)': $($_.Exception.Message)"
        return $null
    }
}

# Function to get registry value kind as string
function Get-RegistryValueKindString {
    param(
        [Microsoft.Win32.RegistryKey]$Key,
        [string]$ValueName
    )
    
    try {
        $valueKind = $Key.GetValueKind($ValueName)
        return $valueKind.ToString()
    }
    catch {
        Write-Warning "Could not get value kind for '$ValueName' from key '$($Key.Name)': $($_.Exception.Message)"
        return "Unknown"
    }
}

# Function to convert registry value to string representation
function Convert-RegistryValueToString {
    param(
        $Value,
        [string]$ValueKind
    )
    
    if ($null -eq $Value) {
        return ""
    }
    
    switch ($ValueKind) {
        "Binary" {
            if ($Value -is [byte[]]) {
                return ($Value | ForEach-Object { $_.ToString("X2") }) -join ","
            }
            return ""
        }
        "MultiString" {
            if ($Value -is [string[]]) {
                return $Value -join "|"
            }
            return ""
        }
        "ExpandString" {
            return $Value.ToString()
        }
        "DWord" {
            return "0x" + $Value.ToString("X8")
        }
        "QWord" {
            return "0x" + $Value.ToString("X16")
        }
        default {
            return $Value.ToString()
        }
    }
}

# Function to export registry keys and values
function Export-RegistryKey {
    param(
        [string]$KeyPath,
        [switch]$Recurse,
        [string[]]$ExcludePaths,
        [switch]$IncludeEmptyValues,
        [ref]$ExportData
    )
    
    # Skip if path is in exclude list
    if (Test-ExcludePath -Path $KeyPath -ExcludePaths $ExcludePaths) {
        Write-Verbose "Skipping excluded path: $KeyPath"
        return
    }
    
    try {
        # Open the registry key
        $key = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey(
            [Microsoft.Win32.RegistryHive]::LocalMachine, "").OpenSubKey($KeyPath.Replace("Registry::HKEY_LOCAL_MACHINE\", ""))
        
        if ($null -eq $key) {
            $key = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey(
                [Microsoft.Win32.RegistryHive]::CurrentUser, "").OpenSubKey($KeyPath.Replace("Registry::HKEY_CURRENT_USER\", ""))
        }
        
        if ($null -eq $key) {
            $key = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey(
                [Microsoft.Win32.RegistryHive]::ClassesRoot, "").OpenSubKey($KeyPath.Replace("Registry::HKEY_CLASSES_ROOT\", ""))
        }
        
        if ($null -eq $key) {
            $key = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey(
                [Microsoft.Win32.RegistryHive]::Users, "").OpenSubKey($KeyPath.Replace("Registry::HKEY_USERS\", ""))
        }
        
        if ($null -eq $key) {
            $key = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey(
                [Microsoft.Win32.RegistryHive]::CurrentConfig, "").OpenSubKey($KeyPath.Replace("Registry::HKEY_CURRENT_CONFIG\", ""))
        }
        
        if ($null -eq $key) {
            Write-Warning "Could not open registry key: $KeyPath"
            return
        }
        
        # Get values in the key
        $valueNames = $key.GetValueNames()
        
        # Export values
        if ($valueNames.Count -gt 0 -or $IncludeEmptyValues) {
            if ($valueNames.Count -eq 0) {
                # Export the key itself with no values
                $keyData = [PSCustomObject]@{
                    KeyPath = Convert-RegistryPathToStandard $KeyPath
                    ValueName = ""
                    ValueType = ""
                    ValueData = ""
                }
                $ExportData.Value += $keyData
            }
            else {
                foreach ($valueName in $valueNames) {
                    $valueKind = Get-RegistryValueKindString -Key $key -ValueName $valueName
                    $value = Get-SafeRegistryValue -Key $key -ValueName $valueName
                    $valueString = Convert-RegistryValueToString -Value $value -ValueKind $valueKind
                    
                    $keyData = [PSCustomObject]@{
                        KeyPath = Convert-RegistryPathToStandard $KeyPath
                        ValueName = $valueName
                        ValueType = $valueKind
                        ValueData = $valueString
                    }
                    $ExportData.Value += $keyData
                }
            }
        }
        
        # Process subkeys if recursive
        if ($Recurse) {
            foreach ($subKeyName in $key.GetSubKeyNames()) {
                $subKeyPath = "$KeyPath\$subKeyName"
                Export-RegistryKey -KeyPath $subKeyPath -Recurse:$Recurse -ExcludePaths $ExcludePaths -IncludeEmptyValues:$IncludeEmptyValues -ExportData $ExportData
            }
        }
        
        # Close the key
        $key.Close()
    }
    catch {
        Write-Warning "Error processing registry key '$KeyPath': $($_.Exception.Message)"
    }
}

Write-Host "Starting export of registry settings..." -ForegroundColor Green

# Initialize array to store data
$ExportData = @()

try {
    # Process each registry path
    foreach ($path in $RegistryPaths) {
        Write-Host "Processing registry path: $path" -ForegroundColor Yellow
        
        # Convert path to Registry:: format
        $convertedPath = Convert-RegistryPath -Path $path
        
        # Convert exclude paths to Registry:: format
        $convertedExcludePaths = @()
        foreach ($excludePath in $ExcludePaths) {
            $convertedExcludePaths += Convert-RegistryPath -Path $excludePath
        }
        
        # Export registry keys and values
        Export-RegistryKey -KeyPath $convertedPath -Recurse:$Recurse -ExcludePaths $convertedExcludePaths -IncludeEmptyValues:$IncludeEmptyValues -ExportData ([ref]$ExportData)
    }
    
    # Export to CSV
    Write-Host "Exporting data to CSV: $OutputPath" -ForegroundColor Yellow
    $ExportData | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8
    
    Write-Host "Export completed successfully!" -ForegroundColor Green
    Write-Host "Total registry entries exported: $($ExportData.Count)" -ForegroundColor Cyan
    Write-Host "CSV file saved to: $OutputPath" -ForegroundColor Cyan
}
catch {
    Write-Error "An error occurred during export: $($_.Exception.Message)"
    exit 1
}
