#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Imports registry keys and values from a CSV file.

.DESCRIPTION
    This script imports registry keys and values from a CSV file created by the Export-RegistrySettings.ps1 script.
    It recreates the registry structure with all values, types, and data.

.PARAMETER InputPath
    The path to the CSV file containing the registry settings to import.

.PARAMETER BackupPath
    Optional path to save a backup of existing registry keys before importing. If not specified, no backup is created.

.PARAMETER SkipExisting
    If specified, existing registry values will be skipped instead of being replaced.

.PARAMETER FilterKeyPath
    Optional filter to import only registry keys that match the specified path pattern.

.PARAMETER LogPath
    The path where the log file will be saved. Default is "RegistryImport.log" in the current directory.

.EXAMPLE
    .\Import-RegistrySettings.ps1 -InputPath "C:\Backup\registry.csv"

.EXAMPLE
    .\Import-RegistrySettings.ps1 -InputPath "registry.csv" -BackupPath "C:\Backup\registry_backup.csv" -SkipExisting

.EXAMPLE
    .\Import-RegistrySettings.ps1 -InputPath "registry.csv" -FilterKeyPath "HKCU:\Software\Microsoft\Office"
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$InputPath,
    
    [string]$BackupPath,
    
    [switch]$SkipExisting,
    
    [string]$FilterKeyPath,
    
    [string]$LogPath = ".\RegistryImport.log"
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

# Function to convert string representation of registry value to actual value
function Convert-StringToRegistryValue {
    param(
        [string]$ValueString,
        [string]$ValueType
    )
    
    if ([string]::IsNullOrEmpty($ValueString)) {
        return $null
    }
    
    switch ($ValueType) {
        "Binary" {
            $bytes = $ValueString -split ',' | ForEach-Object { [byte]([Convert]::ToInt32($_, 16)) }
            return $bytes
        }
        "MultiString" {
            return $ValueString -split '\|'
        }
        "DWord" {
            if ($ValueString -like "0x*") {
                return [int]$ValueString
            }
            return [int]::Parse($ValueString)
        }
        "QWord" {
            if ($ValueString -like "0x*") {
                return [long]$ValueString
            }
            return [long]::Parse($ValueString)
        }
        default {
            return $ValueString
        }
    }
}

# Function to get registry value kind from string
function Get-RegistryValueKindFromString {
    param([string]$ValueTypeString)
    
    switch ($ValueTypeString) {
        "String" { return [Microsoft.Win32.RegistryValueKind]::String }
        "ExpandString" { return [Microsoft.Win32.RegistryValueKind]::ExpandString }
        "Binary" { return [Microsoft.Win32.RegistryValueKind]::Binary }
        "DWord" { return [Microsoft.Win32.RegistryValueKind]::DWord }
        "MultiString" { return [Microsoft.Win32.RegistryValueKind]::MultiString }
        "QWord" { return [Microsoft.Win32.RegistryValueKind]::QWord }
        default { return [Microsoft.Win32.RegistryValueKind]::Unknown }
    }
}

# Function to create registry key if it doesn't exist
function Test-RegistryKeyAndCreate {
    param([string]$KeyPath)
    
    if (-not (Test-Path -Path $KeyPath)) {
        try {
            $null = New-Item -Path $KeyPath -Force
            Write-Log "Created registry key: $KeyPath" -Level "SUCCESS"
            return $true
        }
        catch {
            Write-Log "Failed to create registry key '$KeyPath': $($_.Exception.Message)" -Level "ERROR"
            return $false
        }
    }
    
    return $true
}

# Function to export registry keys for backup
function Backup-RegistryKeys {
    param(
        [string]$OutputPath,
        [array]$KeysToBackup
    )
    
    $backupData = @()
    $uniqueKeys = $KeysToBackup | Select-Object -Unique
    
    foreach ($keyPath in $uniqueKeys) {
        if (Test-Path -Path $keyPath) {
            try {
                $key = Get-Item -Path $keyPath
                $valueNames = $key.GetValueNames()
                
                foreach ($valueName in $valueNames) {
                    $valueKind = $key.GetValueKind($valueName)
                    $value = $key.GetValue($valueName, $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
                    
                    # Convert value to string based on type
                    $valueString = ""
                    switch ($valueKind) {
                        "Binary" {
                            if ($value -is [byte[]]) {
                                $valueString = ($value | ForEach-Object { $_.ToString("X2") }) -join ","
                            }
                        }
                        "MultiString" {
                            if ($value -is [string[]]) {
                                $valueString = $value -join "|"
                            }
                        }
                        "DWord" {
                            $valueString = "0x" + $value.ToString("X8")
                        }
                        "QWord" {
                            $valueString = "0x" + $value.ToString("X16")
                        }
                        default {
                            $valueString = $value.ToString()
                        }
                    }
                    
                    $keyData = [PSCustomObject]@{
                        KeyPath = $keyPath
                        ValueName = $valueName
                        ValueType = $valueKind.ToString()
                        ValueData = $valueString
                    }
                    $backupData += $keyData
                }
            }
            catch {
                Write-Log "Error backing up key '$keyPath': $($_.Exception.Message)" -Level "WARNING"
            }
        }
    }
    
    # Export to CSV
    $backupData | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8
    Write-Log "Backup completed with $($backupData.Count) registry values" -Level "SUCCESS"
}

# Initialize log file
$null = New-Item -Path $LogPath -ItemType File -Force
Write-Log "Starting import of registry settings..." -Level "INFO"

# Check if input file exists
if (-not (Test-Path -Path $InputPath)) {
    Write-Log "Input file not found: $InputPath" -Level "ERROR"
    exit 1
}

try {
    # Import registry settings from CSV
    Write-Log "Importing registry settings from: $InputPath" -Level "INFO"
    $registrySettings = Import-Csv -Path $InputPath
    
    # Filter by key path if specified
    if ($FilterKeyPath) {
        Write-Log "Filtering registry settings by key path: $FilterKeyPath" -Level "INFO"
        $registrySettings = $registrySettings | Where-Object { $_.KeyPath -like "$FilterKeyPath*" }
    }
    
    # Create backup if requested
    if ($BackupPath) {
        Write-Log "Creating backup of existing registry keys to: $BackupPath" -Level "INFO"
        $keysToBackup = $registrySettings | Select-Object -ExpandProperty KeyPath
        Backup-RegistryKeys -OutputPath $BackupPath -KeysToBackup $keysToBackup
    }
    
    # Process registry settings
    $totalSettings = $registrySettings.Count
    $importedCount = 0
    $skippedCount = 0
    $errorCount = 0
    $currentSetting = 0
    
    foreach ($setting in $registrySettings) {
        $currentSetting++
        Write-Progress -Activity "Importing Registry Settings" -Status "Processing entry $currentSetting of $totalSettings" -PercentComplete (($currentSetting / $totalSettings) * 100)
        
        $keyPath = $setting.KeyPath
        $valueName = $setting.ValueName
        $valueType = $setting.ValueType
        $valueData = $setting.ValueData
        
        # Skip if key path is empty
        if ([string]::IsNullOrEmpty($keyPath)) {
            Write-Log "Skipping entry with empty key path" -Level "WARNING"
            $skippedCount++
            continue
        }
        
        try {
            # Create registry key if it doesn't exist
            if (-not (Test-RegistryKeyAndCreate -KeyPath $keyPath)) {
                $errorCount++
                continue
            }
            
            # If ValueName is empty, we're just creating the key
            if ([string]::IsNullOrEmpty($valueName)) {
                $importedCount++
                continue
            }
            
            # Check if value already exists
            $existingValue = $null
            try {
                $existingValue = Get-ItemProperty -Path $keyPath -Name $valueName -ErrorAction SilentlyContinue
            }
            catch {
                # Value doesn't exist, which is fine
            }
            
            if ($existingValue -and $SkipExisting) {
                Write-Log "Skipping existing value: '$valueName' in key '$keyPath'" -Level "WARNING"
                $skippedCount++
                continue
            }
            
            # Convert value string to actual value
            $registryValue = Convert-StringToRegistryValue -ValueString $valueData -ValueType $valueType
            
            # Get registry value kind
            $registryValueKind = Get-RegistryValueKindFromString -ValueTypeString $valueType
            
            # Set registry value
            $null = New-ItemProperty -Path $keyPath -Name $valueName -Value $registryValue -PropertyType $registryValueKind -Force
            
            Write-Log "Successfully imported value '$valueName' to key '$keyPath'" -Level "SUCCESS"
            $importedCount++
        }
        catch {
            Write-Log "Failed to import value '$valueName' to key '$keyPath': $($_.Exception.Message)" -Level "ERROR"
            $errorCount++
        }
    }
    
    Write-Progress -Activity "Importing Registry Settings" -Completed
    
    Write-Log "Import completed!" -Level "SUCCESS"
    Write-Log "Total settings processed: $totalSettings" -Level "INFO"
    Write-Log "Settings successfully imported: $importedCount" -Level "SUCCESS"
    Write-Log "Settings skipped: $skippedCount" -Level "INFO"
    Write-Log "Settings with errors: $errorCount" -Level "WARNING"
}
catch {
    Write-Log "An error occurred during import: $($_.Exception.Message)" -Level "ERROR"
    exit 1
}
