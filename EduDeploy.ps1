Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase

$ConfigPath = Join-Path $PSScriptRoot "config.json"

if (-not (Test-Path $ConfigPath)) {
    [System.Windows.MessageBox]::Show(
        "config.json ei löytynyt.",
        "EduDeploy"
    )
    exit
}

$config = Get-Content $ConfigPath -Raw | ConvertFrom-Json

# -----------------------------
# Window
# -----------------------------

$window = New-Object System.Windows.Window
$window.Title = "EduDeploy"
$window.Width = 900
$window.Height = 600
$window.WindowStartupLocation = "CenterScreen"
$window.ResizeMode = "CanResize"

# -----------------------------
# Main layout
# -----------------------------

$mainGrid = New-Object System.Windows.Controls.Grid

$column1 = New-Object System.Windows.Controls.ColumnDefinition
$column1.Width = "220"

$column2 = New-Object System.Windows.Controls.ColumnDefinition
$column2.Width = "*"

$mainGrid.ColumnDefinitions.Add($column1)
$mainGrid.ColumnDefinitions.Add($column2)

# -----------------------------
# Sidebar
# -----------------------------

$sidebar = New-Object System.Windows.Controls.StackPanel
$sidebar.Margin = "20"

[System.Windows.Controls.Grid]::SetColumn($sidebar, 0)

$title = New-Object System.Windows.Controls.TextBlock
$title.Text = "EduDeploy"
$title.FontSize = 28
$title.FontWeight = "Bold"
$title.Margin = "0,0,0,5"

$subtitle = New-Object System.Windows.Controls.TextBlock
$subtitle.Text = "3D Software Installer"
$subtitle.FontSize = 13
$subtitle.Margin = "0,0,0,30"

$appsButton = New-Object System.Windows.Controls.Button
$appsButton.Content = "3D-ohjelmat"
$appsButton.Height = 40
$appsButton.Margin = "0,0,0,10"

$settingsButton = New-Object System.Windows.Controls.Button
$settingsButton.Content = "Asetukset"
$settingsButton.Height = 40

$sidebar.Children.Add($title)
$sidebar.Children.Add($subtitle)
$sidebar.Children.Add($appsButton)
$sidebar.Children.Add($settingsButton)

# -----------------------------
# Content
# -----------------------------

$content = New-Object System.Windows.Controls.StackPanel
$content.Margin = "20"

[System.Windows.Controls.Grid]::SetColumn($content, 1)

$header = New-Object System.Windows.Controls.TextBlock
$header.Text = "3D-ohjelmistot"
$header.FontSize = 26
$header.FontWeight = "Bold"
$header.Margin = "0,0,0,20"

$content.Children.Add($header)

foreach ($app in $config.applications) {

    $border = New-Object System.Windows.Controls.Border
    $border.BorderThickness = "1"
    $border.Padding = "15"
    $border.Margin = "0,0,0,12"

    $grid = New-Object System.Windows.Controls.Grid

    $nameColumn = New-Object System.Windows.Controls.ColumnDefinition
    $nameColumn.Width = "*"

    $buttonColumn = New-Object System.Windows.Controls.ColumnDefinition
    $buttonColumn.Width = "120"

    $grid.ColumnDefinitions.Add($nameColumn)
    $grid.ColumnDefinitions.Add($buttonColumn)

    # App information
    $info = New-Object System.Windows.Controls.StackPanel

    $name = New-Object System.Windows.Controls.TextBlock
    $name.Text = $app.name
    $name.FontSize = 18
    $name.FontWeight = "Bold"

    $description = New-Object System.Windows.Controls.TextBlock
    $description.Text = $app.description
    $description.Margin = "0,5,0,0"

    $info.Children.Add($name)
    $info.Children.Add($description)

    [System.Windows.Controls.Grid]::SetColumn($info, 0)

    # Install button
    $installButton = New-Object System.Windows.Controls.Button
    $installButton.Content = "ASENNA"
    $installButton.Width = 100
    $installButton.Height = 35

    [System.Windows.Controls.Grid]::SetColumn($installButton, 1)

    $appName = $app.name

    $installButton.Add_Click({

        [System.Windows.MessageBox]::Show(
            "Tässä vaiheessa $appName asennus on vielä testitilassa.",
            "EduDeploy v0.1"
        )

    })

    $grid.Children.Add($info)
    $grid.Children.Add($installButton)

    $border.Child = $grid

    $content.Children.Add($border)
}

$mainGrid.Children.Add($sidebar)
$mainGrid.Children.Add($content)

$window.Content = $mainGrid

# -----------------------------
# Start
# -----------------------------

$window.ShowDialog() | Out-Null