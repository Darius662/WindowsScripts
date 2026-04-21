# UI Components Module
# Provides modern UI styling and component creation functions

# Modern color scheme
$script:Colors = @{
    Background = [System.Drawing.Color]::FromArgb(45, 45, 48)
    Panel = [System.Drawing.Color]::FromArgb(62, 62, 66)
    TextBox = [System.Drawing.Color]::FromArgb(37, 37, 38)
    Primary = [System.Drawing.Color]::FromArgb(0, 120, 215)
    Success = [System.Drawing.Color]::FromArgb(16, 124, 16)
    Text = [System.Drawing.Color]::White
    TextSecondary = [System.Drawing.Color]::LightGray
}

# Modern font
$script:ModernFont = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Regular)

# Create modern button
function New-ModernButton {
    param(
        [string]$Text,
        [int]$Width = 100,
        [int]$Height = 30,
        [System.Drawing.Color]$BackColor = $script:Colors.Primary,
        [string]$FontStyle = "Regular"
    )
    
    $button = New-Object System.Windows.Forms.Button
    $button.Text = $Text
    $button.Size = New-Object System.Drawing.Size($Width, $Height)
    $button.BackColor = $BackColor
    $button.ForeColor = $script:Colors.Text
    $button.FlatStyle = "Flat"
    $button.Cursor = "Hand"
    
    $fontStyleValue = [System.Drawing.FontStyle]$FontStyle
    $button.Font = New-Object System.Drawing.Font("Segoe UI", 9, $fontStyleValue)
    
    return $button
}

# Create modern text box
function New-ModernTextBox {
    param(
        [bool]$Multiline = $false,
        [int]$Width = 200,
        [int]$Height = 25
    )
    
    $textBox = New-Object System.Windows.Forms.TextBox
    $textBox.Multiline = $Multiline
    $textBox.BackColor = $script:Colors.TextBox
    $textBox.ForeColor = $script:Colors.Text
    $textBox.BorderStyle = "FixedSingle"
    $textBox.Font = $script:ModernFont
    
    if ($Multiline) {
        $textBox.ScrollBars = "Vertical"
        $textBox.Size = New-Object System.Drawing.Size($Width, $Height)
    } else {
        $textBox.Size = New-Object System.Drawing.Size($Width, $Height)
    }
    
    return $textBox
}

# Create modern label
function New-ModernLabel {
    param(
        [string]$Text,
        [System.Drawing.Color]$ForeColor = $script:Colors.TextSecondary,
        [string]$FontStyle = "Regular"
    )
    
    $label = New-Object System.Windows.Forms.Label
    $label.Text = $Text
    $label.ForeColor = $ForeColor
    
    $fontStyleValue = [System.Drawing.FontStyle]$FontStyle
    $label.Font = New-Object System.Drawing.Font("Segoe UI", 9, $fontStyleValue)
    
    return $label
}

# Create modern group box
function New-ModernGroupBox {
    param(
        [string]$Text,
        [int]$Width = 300,
        [int]$Height = 200
    )
    
    $groupBox = New-Object System.Windows.Forms.GroupBox
    $groupBox.Text = $Text
    $groupBox.Size = New-Object System.Drawing.Size($Width, $Height)
    $groupBox.BackColor = $script:Colors.Panel
    $groupBox.ForeColor = $script:Colors.Text
    $groupBox.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    
    return $groupBox
}

# Create modern list view
function New-ModernListView {
    param(
        [int]$Width = 400,
        [int]$Height = 200
    )
    
    $listView = New-Object System.Windows.Forms.ListView
    $listView.View = "Details"
    $listView.FullRowSelect = $true
    $listView.GridLines = $true
    $listView.Size = New-Object System.Drawing.Size($Width, $Height)
    $listView.BackColor = $script:Colors.TextBox
    $listView.ForeColor = $script:Colors.Text
    $listView.Font = $script:ModernFont
    
    return $listView
}

# Create modern main form
function New-MainForm {
    param(
        [string]$Title = "Run As User GUI - Modern",
        [int]$Width = 850,
        [int]$Height = 850
    )
    
    $form = New-Object System.Windows.Forms.Form
    $form.Text = $Title
    $form.Size = New-Object System.Drawing.Size($Width, $Height)
    $form.StartPosition = "CenterScreen"
    $form.MinimumSize = New-Object System.Drawing.Size(650, 450)
    $form.BackColor = $script:Colors.Background
    $form.ForeColor = $script:Colors.Text
    $form.Font = $script:ModernFont
    
    return $form
}

# Create modern panel
function New-ModernPanel {
    param(
        [int]$Padding = 15
    )
    
    $panel = New-Object System.Windows.Forms.Panel
    $panel.Dock = "Fill"
    $panel.Padding = New-Object System.Windows.Forms.Padding($Padding)
    $panel.BackColor = $script:Colors.Background
    
    return $panel
}

# Create modern menu strip
function New-ModernMenuStrip {
    $menuStrip = New-Object System.Windows.Forms.MenuStrip
    $menuStrip.BackColor = $script:Colors.Background
    $menuStrip.ForeColor = $script:Colors.Text
    $menuStrip.Font = $script:ModernFont
    
    return $menuStrip
}

# Create modern status label
function New-ModernStatusLabel {
    param(
        [string]$Text = "Ready",
        [int]$Width = 780,
        [int]$Height = 25
    )
    
    $statusLabel = New-Object System.Windows.Forms.Label
    $statusLabel.Text = $Text
    $statusLabel.Size = New-Object System.Drawing.Size($Width, $Height)
    $statusLabel.BackColor = $script:Colors.TextBox
    $statusLabel.ForeColor = $script:Colors.TextSecondary
    $statusLabel.Font = New-Object System.Drawing.Font("Segoe UI", 8.5)
    $statusLabel.TextAlign = "MiddleLeft"
    
    return $statusLabel
}

# Get color scheme
function Get-ColorScheme {
    return $script:Colors
}

# Get modern font
function Get-ModernFont {
    return $script:ModernFont
}
