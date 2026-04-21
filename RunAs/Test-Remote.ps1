# Test script for remote functionality
# This script tests the remote manager module functions

# Import the remote manager module
. "$PSScriptRoot\Modules\RemoteManager.ps1"

# Test computer name validation
Write-Host "Testing computer name validation..."
$validNames = @("localhost", "192.168.1.1", "PC-NAME", "server.domain.com")
$invalidNames = @("", "   ", "invalid@name", "name with spaces")

foreach ($name in $validNames) {
    $result = Test-ComputerNameFormat -ComputerName $name
    Write-Host "'$name' - Valid: $result"
}

foreach ($name in $invalidNames) {
    $result = Test-ComputerNameFormat -ComputerName $name
    Write-Host "'$name' - Valid: $result"
}

# Test WinRM connectivity (only if you have a remote computer available)
Write-Host "`nTesting WinRM connectivity to localhost..."
$winrmResult = Test-WinRmEnabled -ComputerName "localhost"
Write-Host "WinRM enabled on localhost: $winrmResult"

# Test remote process functions (mock test)
Write-Host "`nTesting remote process functions (mock test)..."

# This would require actual credentials and a remote computer
# Uncomment and modify for real testing:
# $securePassword = ConvertTo-SecureString "YourPassword" -AsPlainText -Force
# $result = Start-RemoteProcessAsUser -ComputerName "RemotePC" -Username "Administrator" -Password $securePassword -FilePath "notepad.exe"
# Write-Host "Remote process result: $($result.Success) - $($result.Message)"

Write-Host "`nRemote functionality test completed!"
Write-Host "Note: Full remote testing requires:"
Write-Host "1. A remote computer with PowerShell remoting enabled"
Write-Host "2. Valid credentials for the remote computer"
Write-Host "3. Network connectivity between computers"
