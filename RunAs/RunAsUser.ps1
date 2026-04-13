# Enhanced RunAsUser with GUI - Modular Version
# Requires Windows Forms assembly
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Import modules
. "$PSScriptRoot\Modules\Config.ps1"
. "$PSScriptRoot\Modules\ProcessManager.ps1"
. "$PSScriptRoot\Modules\UIComponents.ps1"

# File dialog function
function Show-FileDialog {
    $openFileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $openFileDialog.Title = "Select file to run as different user"
    $openFileDialog.Filter = "Executable Files (*.exe)|*.exe|All Files (*.*)|*.*"
    $openFileDialog.Multiselect = $true
    
    if ($openFileDialog.ShowDialog() -eq 'OK') {
        if ($openFileDialog.FileNames.Count -gt 1) {
            $global:FilePathTextBox.Text = $openFileDialog.FileNames -join "`r`n"
        } else {
            $global:FilePathTextBox.Text = $openFileDialog.FileName
        }
    }
}

# Validate file path
function Test-FilePath {
    param([string]$Path)
    
    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $false
    }
    
    $paths = $Path -split "`r`n|`n"
    foreach ($p in $paths) {
        if (-not (Test-Path $p.Trim())) {
            return $false
        }
    }
    return $true
}

# Update recent files menu
function Update-RecentFilesMenu {
    $global:RecentMenuItem.DropDownItems.Clear()
    
    $recentFiles = Get-RecentFiles
    if ($recentFiles.Count -eq 0) {
        $menuItem = New-Object System.Windows.Forms.ToolStripMenuItem
        $menuItem.Text = "(No recent files)"
        $menuItem.Enabled = $false
        $global:RecentMenuItem.DropDownItems.Add($menuItem) | Out-Null
    } else {
        foreach ($file in $recentFiles) {
            $menuItem = New-Object System.Windows.Forms.ToolStripMenuItem
            $menuItem.Text = $file
            $menuItem.Add_Click({
                param()
                $global:FilePathTextBox.Text = $this.Text
            })
            $global:RecentMenuItem.DropDownItems.Add($menuItem) | Out-Null
        }
    }
}

# Create main application
function New-MainApplication {
    # Initialize configuration
    Import-Config
    
    # Create main form
    $mainForm = New-MainForm
    
    # Create menu bar
    $menuStrip = New-ModernMenuStrip
    
    # File menu
    $fileMenu = New-Object System.Windows.Forms.ToolStripMenuItem
    $fileMenu.Text = "File"
    
    $browseMenuItem = New-Object System.Windows.Forms.ToolStripMenuItem
    $browseMenuItem.Text = "Browse..."
    $browseMenuItem.ShortcutKeys = [System.Windows.Forms.Keys]::Control + [System.Windows.Forms.Keys]::O
    $browseMenuItem.Add_Click({ Show-FileDialog })
    $fileMenu.DropDownItems.Add($browseMenuItem) | Out-Null
    
    $global:RecentMenuItem = New-Object System.Windows.Forms.ToolStripMenuItem
    $global:RecentMenuItem.Text = "Recent Files"
    $fileMenu.DropDownItems.Add($global:RecentMenuItem) | Out-Null
    
    $fileMenu.DropDownItems.Add((New-Object System.Windows.Forms.ToolStripSeparator)) | Out-Null
    
    $exitMenuItem = New-Object System.Windows.Forms.ToolStripMenuItem
    $exitMenuItem.Text = "Exit"
    $exitMenuItem.ShortcutKeys = [System.Windows.Forms.Keys]::Alt + [System.Windows.Forms.Keys]::F4
    $exitMenuItem.Add_Click({ $mainForm.Close() })
    $fileMenu.DropDownItems.Add($exitMenuItem) | Out-Null
    
    $menuStrip.Items.Add($fileMenu) | Out-Null
    
    # View menu
    $viewMenu = New-Object System.Windows.Forms.ToolStripMenuItem
    $viewMenu.Text = "View"
    
    $refreshMenuItem = New-Object System.Windows.Forms.ToolStripMenuItem
    $refreshMenuItem.Text = "Refresh Processes"
    $refreshMenuItem.ShortcutKeys = [System.Windows.Forms.Keys]::F5
    $refreshMenuItem.Add_Click({ Update-ProcessListView $global:ProcessListView $global:StatusLabel })
    $viewMenu.DropDownItems.Add($refreshMenuItem) | Out-Null
    
    $menuStrip.Items.Add($viewMenu) | Out-Null
    
    $mainForm.MainMenuStrip = $menuStrip
    $mainForm.Controls.Add($menuStrip)
    
    # Create main panel
    $mainPanel = New-ModernPanel
    
    # File selection group
    $fileGroup = New-ModernGroupBox -Text "File Selection" -Width 780 -Height 130
    $fileGroup.Location = New-Object System.Drawing.Point(0, 0)
    
    $filePathLabel = New-ModernLabel -Text "File Path(s):"
    $filePathLabel.Location = New-Object System.Drawing.Point(15, 25)
    $filePathLabel.Size = New-Object System.Drawing.Size(100, 25)
    $fileGroup.Controls.Add($filePathLabel)
    
    $global:FilePathTextBox = New-ModernTextBox -Multiline $true -Width 650 -Height 60
    $global:FilePathTextBox.Location = New-Object System.Drawing.Point(15, 50)
    $fileGroup.Controls.Add($global:FilePathTextBox)
    
    $browseButton = New-ModernButton -Text "Browse..." -Width 90 -Height 60
    $browseButton.Location = New-Object System.Drawing.Point(675, 50)
    $browseButton.Add_Click({ Show-FileDialog })
    $fileGroup.Controls.Add($browseButton)
    
    # Credentials group
    $credGroup = New-ModernGroupBox -Text "Credentials" -Width 780 -Height 110
    $credGroup.Location = New-Object System.Drawing.Point(0, 145)
    
    $usernameLabel = New-ModernLabel -Text "Username:"
    $usernameLabel.Location = New-Object System.Drawing.Point(15, 30)
    $usernameLabel.Size = New-Object System.Drawing.Size(100, 25)
    $credGroup.Controls.Add($usernameLabel)
    
    $global:UsernameTextBox = New-ModernTextBox -Width 250 -Height 25
    $global:UsernameTextBox.Location = New-Object System.Drawing.Point(120, 30)
    $credGroup.Controls.Add($global:UsernameTextBox)
    
    $passwordLabel = New-ModernLabel -Text "Password:"
    $passwordLabel.Location = New-Object System.Drawing.Point(15, 65)
    $passwordLabel.Size = New-Object System.Drawing.Size(100, 25)
    $credGroup.Controls.Add($passwordLabel)
    
    $global:PasswordTextBox = New-ModernTextBox -Width 250 -Height 25
    $global:PasswordTextBox.PasswordChar = "*"
    $global:PasswordTextBox.Location = New-Object System.Drawing.Point(120, 65)
    $credGroup.Controls.Add($global:PasswordTextBox)
    
    $runButton = New-ModernButton -Text "Run as User" -Width 90 -Height 60 -BackColor $script:Colors.Success -FontStyle "Bold"
    $runButton.Location = New-Object System.Drawing.Point(680, 30)
    $runButton.Add_Click({
        if ([string]::IsNullOrWhiteSpace($global:FilePathTextBox.Text)) {
            [System.Windows.Forms.MessageBox]::Show("Please enter a file path", "Error", "OK", "Error")
            return
        }
        
        if (-not (Test-FilePath -Path $global:FilePathTextBox.Text)) {
            [System.Windows.Forms.MessageBox]::Show("One or more files do not exist", "Error", "OK", "Error")
            return
        }
        
        if ([string]::IsNullOrWhiteSpace($global:UsernameTextBox.Text) -or [string]::IsNullOrWhiteSpace($global:PasswordTextBox.Text)) {
            [System.Windows.Forms.MessageBox]::Show("Please enter username and password", "Error", "OK", "Error")
            return
        }
        
        try {
            $securePassword = ConvertTo-SecureString $global:PasswordTextBox.Text -AsPlainText -Force
            $credential = New-Object System.Management.Automation.PSCredential($global:UsernameTextBox.Text, $securePassword)
            
            $filePaths = $global:FilePathTextBox.Text -split "`r`n|`n"
            Start-ProcessAsUser -FilePaths $filePaths -Credential $credential
            
            # Clear password for security
            $global:PasswordTextBox.Text = ""
        } catch {
            [System.Windows.Forms.MessageBox]::Show("Invalid credentials: $($_.Exception.Message)", "Error", "OK", "Error")
        }
    })
    $credGroup.Controls.Add($runButton)
    
    # Quick tools group
    $toolsGroup = New-ModernGroupBox -Text "Quick Tools" -Width 780 -Height 100
    $toolsGroup.Location = New-Object System.Drawing.Point(0, 270)
    
    # Create buttons for tools
    $commonTools = Get-CommonTools
    $buttonIndex = 0
    foreach ($toolName in $commonTools.Keys) {
        $button = New-ModernButton -Text $toolName -Width 145 -Height 30 -FontStyle "Bold"
        $xPos = 15 + ($buttonIndex % 5) * 155
        $yPos = 30 + [Math]::Floor($buttonIndex / 5) * 40
        $button.Location = New-Object System.Drawing.Point($xPos, $yPos)
        
        $button.Add_Click({
            $securePassword = ConvertTo-SecureString $global:PasswordTextBox.Text -AsPlainText -Force
            Start-ToolAsUser -ToolName $this.Text -Username $global:UsernameTextBox.Text -Password $securePassword
            Update-ProcessListView $global:ProcessListView $global:StatusLabel
        })
        $toolsGroup.Controls.Add($button)
        $buttonIndex++
    }
    
    # Running processes group
    $processGroup = New-ModernGroupBox -Text "Running Processes" -Width 780 -Height 220
    $processGroup.Location = New-Object System.Drawing.Point(0, 385)
    
    $global:ProcessListView = New-ModernListView -Width 750 -Height 185
    $global:ProcessListView.Location = New-Object System.Drawing.Point(15, 30)
    
    $global:ProcessListView.Columns.Add("Process", 150) | Out-Null
    $global:ProcessListView.Columns.Add("File Path", 300) | Out-Null
    $global:ProcessListView.Columns.Add("User", 150) | Out-Null
    $global:ProcessListView.Columns.Add("Start Time", 80) | Out-Null
    $global:ProcessListView.Columns.Add("PID", 50) | Out-Null
    
    $processGroup.Controls.Add($global:ProcessListView)
    
    # Status bar
    $global:StatusLabel = New-ModernStatusLabel -Text "Ready - Enter credentials to launch applications as different user"
    $global:StatusLabel.Location = New-Object System.Drawing.Point(0, 620)
    
    # Add controls to main panel
    $mainPanel.Controls.Add($fileGroup)
    $mainPanel.Controls.Add($credGroup)
    $mainPanel.Controls.Add($toolsGroup)
    $mainPanel.Controls.Add($processGroup)
    $mainPanel.Controls.Add($global:StatusLabel)
    
    $mainForm.Controls.Add($mainPanel)
    
    # Timer to refresh process list
    $timer = New-Object System.Windows.Forms.Timer
    $timer.Interval = 5000  # 5 seconds
    $timer.Add_Tick({ Update-ProcessListView $global:ProcessListView $global:StatusLabel })
    $timer.Start()
    
    # Initialize
    Update-RecentFilesMenu
    Update-ProcessListView $global:ProcessListView $global:StatusLabel
    
    # Show form
    [void]$mainForm.ShowDialog()
}

# Start the application
New-MainApplication
