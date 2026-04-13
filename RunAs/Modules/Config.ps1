# Configuration Management Module
# Handles recent files and application configuration

# Global variables
$script:RecentFiles = @()
$script:ConfigFile = "$env:USERPROFILE\RunAsUserGUI_Config.json"

# Load configuration if exists
function Import-Config {
    if (Test-Path $script:ConfigFile) {
        try {
            $config = Get-Content $script:ConfigFile | ConvertFrom-Json
            $script:RecentFiles = $config.RecentFiles
        } catch {
            Write-Warning "Failed to load configuration file"
        }
    }
}

# Save configuration
function Export-Config {
    $config = @{
        RecentFiles = $script:RecentFiles
    }
    try {
        $config | ConvertTo-Json | Set-Content $script:ConfigFile
    } catch {
        Write-Warning "Failed to save configuration file"
    }
}

# Add file to recent files
function Add-RecentFile {
    param([string]$FilePath)
    
    $script:RecentFiles = $script:RecentFiles | Where-Object { $_ -ne $FilePath }
    $script:RecentFiles = @($FilePath) + $script:RecentFiles
    $script:RecentFiles = $script:RecentFiles | Select-Object -First 10
    Export-Config
}

# Get recent files
function Get-RecentFiles {
    return $script:RecentFiles
}

# Clear recent files
function Clear-RecentFiles {
    $script:RecentFiles = @()
    Export-Config
}
