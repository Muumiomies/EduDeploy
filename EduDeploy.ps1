Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase

$ErrorActionPreference = "Stop"

# ==========================================
# EduDeploy v0.1
# ==========================================

$Version = "0.1"

# ==========================================
# Load configuration
# ==========================================

$ConfigPath = Join-Path $PSScriptRoot "config.json"

if (-not (Test-Path $ConfigPath)) {
    [System.Windows.MessageBox]::Show(
        "config.json ei löytynyt.",
        "EduDeploy"
    )
    exit
}

try {
    $Config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
}
catch {
    [System.Windows.MessageBox]::Show(
        "config.json-tiedoston lukeminen epäonnistui.`n`n$($_.Exception.Message)",
        "EduDeploy"
    )
    exit
}

# ==========================================
# Main Window
# ==========================================

$Window = New-Object System.Windows.Window

$Window.Title = "EduDeploy"
$Window.Width = 1000
$Window.Height = 650
$Window.MinWidth = 800
$Window.MinHeight = 500
$Window.WindowStartupLocation = "CenterScreen"
$Window.Background = "#F5F5F5"

# ==========================================
# Main Grid
# ==========================================

$MainGrid = New-Object System.Windows.Controls.Grid

# Sidebar
$SidebarColumn = New-Object System.Windows.Controls.ColumnDefinition
$SidebarColumn.Width = "230"

# Content
$ContentColumn = New-Object System.Windows.Controls.ColumnDefinition
$ContentColumn.Width = "*"

$MainGrid.ColumnDefinitions.Add($SidebarColumn)
$MainGrid.ColumnDefinitions.Add($ContentColumn)

# ==========================================
# Sidebar
# ==========================================

$Sidebar = New-Object System.Windows.Controls.StackPanel
$Sidebar.Margin = "20"

[System.Windows.Controls.Grid]::SetColumn($Sidebar, 0)

# Logo / title

$Logo = New-Object System.Windows.Controls.TextBlock
$Logo.Text = "EduDeploy"
$Logo.FontSize = 30
$Logo.FontWeight = "Bold"
$Logo.Margin = "0,5,0,0"

$Sidebar.Children.Add($Logo)

$Subtitle = New-Object System.Windows.Controls.TextBlock
$Subtitle.Text = "3D Software Installer"
$Subtitle.FontSize = 13
$Subtitle.Foreground = "#666666"
$Subtitle.Margin = "0,2,0,35"

$Sidebar.Children.Add($Subtitle)

# Navigation title

$NavigationTitle = New-Object System.Windows.Controls.TextBlock
$NavigationTitle.Text = "KATEGORIAT"
$NavigationTitle.FontSize = 11
$NavigationTitle.FontWeight = "Bold"
$NavigationTitle.Foreground = "#777777"
$NavigationTitle.Margin = "0,0,0,10"

$Sidebar.Children.Add($NavigationTitle)

# Buttons

$AllButton = New-Object System.Windows.Controls.Button
$AllButton.Content = "Kaikki ohjelmat"
$AllButton.Height = 40
$AllButton.HorizontalContentAlignment = "Left"
$AllButton.Padding = "15,0"
$AllButton.Margin = "0,0,0,6"

$ThreeDButton = New-Object System.Windows.Controls.Button
$ThreeDButton.Content = "3D"
$ThreeDButton.Height = 40
$ThreeDButton.HorizontalContentAlignment = "Left"
$ThreeDButton.Padding = "15,0"
$ThreeDButton.Margin = "0,0,0,6"

$CadButton = New-Object System.Windows.Controls.Button
$CadButton.Content = "CAD"
$CadButton.Height = 40
$CadButton.HorizontalContentAlignment = "Left"
$CadButton.Padding = "15,0"
$CadButton.Margin = "0,0,0,6"

$Sidebar.Children.Add($AllButton)
$Sidebar.Children.Add($ThreeDButton)
$Sidebar.Children.Add($CadButton)

# Bottom version

$VersionText = New-Object System.Windows.Controls.TextBlock
$VersionText.Text = "EduDeploy v$Version"
$VersionText.Foreground = "#888888"
$VersionText.Margin = "0,35,0,0"

$Sidebar.Children.Add($VersionText)

# ==========================================
# Content area
# ==========================================

$Content = New-Object System.Windows.Controls.StackPanel
$Content.Margin = "30"

[System.Windows.Controls.Grid]::SetColumn($Content, 1)

# Header

$Header = New-Object System.Windows.Controls.TextBlock
$Header.Text = "3D-ohjelmistot"
$Header.FontSize = 28
$Header.FontWeight = "Bold"
$Header.Margin = "0,0,0,5"

$Content.Children.Add($Header)

$DescriptionHeader = New-Object System.Windows.Controls.TextBlock
$DescriptionHeader.Text = "Asenna tarvitsemasi ohjelmistot yhdestä paikasta."
$DescriptionHeader.Foreground = "#666666"
$DescriptionHeader.Margin = "0,0,0,25"

$Content.Children.Add($DescriptionHeader)

# ==========================================
# Application container
# ==========================================

$AppPanel = New-Object System.Windows.Controls.StackPanel

$Content.Children.Add($AppPanel)

# ==========================================
# Application rendering
# ==========================================

function Show-Applications {
    param (
        [string]$Category = "All"
    )

    $AppPanel.Children.Clear()

    foreach ($App in $Config.applications) {

        if ($Category -ne "All" -and $App.category -ne $Category) {
            continue
        }

        # Card
        $Card = New-Object System.Windows.Controls.Border
        $Card.Background = "White"
        $Card.BorderBrush = "#DDDDDD"
        $Card.BorderThickness = "1"
        $Card.Padding = "18"
        $Card.Margin = "0,0,0,12"

        # Card grid
        $CardGrid = New-Object System.Windows.Controls.Grid

        $InfoColumn = New-Object System.Windows.Controls.ColumnDefinition
        $InfoColumn.Width = "*"

        $ButtonColumn = New-Object System.Windows.Controls.ColumnDefinition
        $ButtonColumn.Width = "120"

        $CardGrid.ColumnDefinitions.Add($InfoColumn)
        $CardGrid.ColumnDefinitions.Add($ButtonColumn)

        # Information

        $Info = New-Object System.Windows.Controls.StackPanel

        $Name = New-Object System.Windows.Controls.TextBlock
        $Name.Text = $App.name
        $Name.FontSize = 19
        $Name.FontWeight = "Bold"

        $AppDescription = New-Object System.Windows.Controls.TextBlock
        $AppDescription.Text = $App.description
        $AppDescription.Foreground = "#666666"
        $AppDescription.Margin = "0,5,0,0"

        $Info.Children.Add($Name)
        $Info.Children.Add($AppDescription)

        [System.Windows.Controls.Grid]::SetColumn($Info, 0)

        # Install button

        $InstallButton = New-Object System.Windows.Controls.Button
        $InstallButton.Content = "ASENNA"
        $InstallButton.Width = 100
        $InstallButton.Height = 38
        $InstallButton.VerticalAlignment = "Center"
        $InstallButton.HorizontalAlignment = "Right"

        $ApplicationName = $App.name

        $InstallButton.Add_Click({

            [System.Windows.MessageBox]::Show(
                "Asennus testitilassa.`n`nOhjelma: $ApplicationName",
                "EduDeploy v$Version"
            )

        }.GetNewClosure())

        [System.Windows.Controls.Grid]::SetColumn($InstallButton, 1)

        $CardGrid.Children.Add($Info)
        $CardGrid.Children.Add($InstallButton)

        $Card.Child = $CardGrid

        $AppPanel.Children.Add($Card)
    }
}

# ==========================================
# Navigation events
# ==========================================

$AllButton.Add_Click({
    Show-Applications -Category "All"
})

$ThreeDButton.Add_Click({
    Show-Applications -Category "3D"
})

$CadButton.Add_Click({
    Show-Applications -Category "CAD"
})

# ==========================================
# Assemble window
# ==========================================

$MainGrid.Children.Add($Sidebar)
$MainGrid.Children.Add($Content)

$Window.Content = $MainGrid

# ==========================================
# Initial view
# ==========================================

Show-Applications -Category "All"

# ==========================================
# Start
# ==========================================

$Window.ShowDialog() | Out-Null