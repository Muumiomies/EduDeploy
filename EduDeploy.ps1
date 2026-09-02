Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase

$ErrorActionPreference = "Stop"

# ==========================================
# EduDeploy v0.5.0
# ==========================================

$Version = "0.5.0"

# ==========================================
# Load configuration
# ==========================================

$ConfigPath = Join-Path $PSScriptRoot "config.json"

if (-not (Test-Path $ConfigPath)) {
    [System.Windows.MessageBox]::Show(
        "config.json was not found.",
        "EduDeploy"
    )
    exit
}

try {
    $Config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
}
catch {
    [System.Windows.MessageBox]::Show(
        "Failed to read config.json.`n`n$($_.Exception.Message)",
        "EduDeploy"
    )
    exit
}

# ==========================================
# Validate configuration
# ==========================================

if ($null -eq $Config.applications) {
    [System.Windows.MessageBox]::Show(
        "config.json does not contain an applications list.",
        "EduDeploy"
    )
    exit
}

if ($Config.applications.Count -eq 0) {
    [System.Windows.MessageBox]::Show(
        "config.json does not contain any applications.",
        "EduDeploy"
    )
    exit
}

# ==========================================
# Global UI references
# ==========================================

$CurrentStatusText = $null
$CurrentProgressBar = $null
$CurrentProgressText = $null
$CurrentSpeedText = $null
$CurrentSizeText = $null

$Window = $null
$AppPanel = $null
$Header = $null
$DescriptionHeader = $null

# ==========================================
# Installation detection cache
# ==========================================

$script:InstalledApplicationCache = @{}

# ==========================================
# Format file size
# ==========================================

function Format-FileSize {
    param (
        [long]$Bytes
    )

    if ($Bytes -ge 1GB) {
        return "{0:N2} GB" -f ($Bytes / 1GB)
    }

    if ($Bytes -ge 1MB) {
        return "{0:N2} MB" -f ($Bytes / 1MB)
    }

    if ($Bytes -ge 1KB) {
        return "{0:N2} KB" -f ($Bytes / 1KB)
    }

    return "$Bytes B"
}

# ==========================================
# Update status text
# ==========================================

function Write-Status {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    if ($null -ne $CurrentStatusText) {
        $CurrentStatusText.Text = $Message
    }

    if ($null -ne $Window) {
        $Window.Dispatcher.Invoke(
            [Action] {},
            [System.Windows.Threading.DispatcherPriority]::Background
        )
    }
}

# ==========================================
# Check whether application is installed
# ==========================================

function Test-ApplicationInstalled {
    param (
        [Parameter(Mandatory = $true)]
        $App
    )

    if ([string]::IsNullOrWhiteSpace($App.installedCheck)) {
        return $false
    }

    $Check = $App.installedCheck.ToString()
    $AppName = $App.name.ToString()

    $CacheKey = "$AppName|$Check"

    # ==========================================
    # Cache
    # ==========================================

    if ($script:InstalledApplicationCache.ContainsKey($CacheKey)) {
        return [bool]$script:InstalledApplicationCache[$CacheKey]
    }

    # ==========================================
    # Check PATH
    # ==========================================

    try {
        $Command = Get-Command $Check -ErrorAction SilentlyContinue

        if ($null -ne $Command) {
            $script:InstalledApplicationCache[$CacheKey] = $true
            return $true
        }
    }
    catch {
        # Ignore
    }

    # ==========================================
    # Blender special detection
    # ==========================================

    if ($Check -eq "blender.exe") {
        try {
            $BlenderRoot = "C:\Program Files\Blender Foundation"

            if (Test-Path $BlenderRoot) {
                $BlenderExe = Get-ChildItem `
                    -Path $BlenderRoot `
                    -Filter "blender.exe" `
                    -File `
                    -Recurse `
                    -ErrorAction SilentlyContinue `
                    | Select-Object -First 1

                if ($null -ne $BlenderExe) {
                    $script:InstalledApplicationCache[$CacheKey] = $true
                    return $true
                }
            }
        }
        catch {
            # Ignore
        }
    }

    # ==========================================
    # Windows uninstall registry
    # ==========================================

    $RegistryPaths = @(
        "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )

    foreach ($RegistryPath in $RegistryPaths) {
        try {
            $Entries = Get-ItemProperty `
                -Path $RegistryPath `
                -ErrorAction SilentlyContinue

            foreach ($Entry in $Entries) {

                if ([string]::IsNullOrWhiteSpace($Entry.DisplayName)) {
                    continue
                }

                $DisplayName = $Entry.DisplayName.ToString()

                if ($DisplayName -eq $AppName) {
                    $script:InstalledApplicationCache[$CacheKey] = $true
                    return $true
                }

                if ($DisplayName -like "*$AppName*") {
                    $script:InstalledApplicationCache[$CacheKey] = $true
                    return $true
                }
            }
        }
        catch {
            # Ignore inaccessible registry keys
        }
    }

    # ==========================================
    # Direct common executable locations
    # ==========================================

    $CommonPaths = @(
        "$env:ProgramFiles\$Check",
        "${env:ProgramFiles(x86)}\$Check",
        "$env:LOCALAPPDATA\Programs\$Check",
        "$env:LOCALAPPDATA\$Check"
    )

    foreach ($Path in $CommonPaths) {

        if (
            -not [string]::IsNullOrWhiteSpace($Path) -and
            (Test-Path $Path -PathType Leaf)
        ) {
            $script:InstalledApplicationCache[$CacheKey] = $true
            return $true
        }
    }

    # ==========================================
    # Not installed
    # ==========================================

    $script:InstalledApplicationCache[$CacheKey] = $false

    return $false
}

# ==========================================
# Check WinGet package
# ==========================================

function Test-WingetInstalled {
    param (
        [Parameter(Mandatory = $true)]
        $App
    )

    if ([string]::IsNullOrWhiteSpace($App.packageId)) {
        return $false
    }

    try {
        $Winget = Get-Command winget.exe -ErrorAction SilentlyContinue

        if ($null -eq $Winget) {
            return $false
        }

        $Output = & $Winget.Source list `
            --id $App.packageId `
            --exact `
            --accept-source-agreements 2>$null

        if ($LASTEXITCODE -eq 0) {

            foreach ($Line in $Output) {

                if ($Line -match [regex]::Escape($App.packageId)) {
                    return $true
                }
            }
        }
    }
    catch {
        # Ignore
    }

    return $false
}

# ==========================================
# Update download progress
# ==========================================

function Update-DownloadProgress {
    param (
        [long]$BytesReceived,
        [long]$TotalBytes,
        [double]$SpeedBytesPerSecond
    )

    if ($null -eq $CurrentProgressBar) {
        return
    }

    if ($TotalBytes -gt 0) {

        $Percent = ($BytesReceived / $TotalBytes) * 100

        if ($Percent -gt 100) {
            $Percent = 100
        }

        $CurrentProgressBar.IsIndeterminate = $false
        $CurrentProgressBar.Value = $Percent

        $CurrentProgressText.Text =
            "{0:N0} %" -f $Percent

        $CurrentSizeText.Text =
            "{0} / {1}" -f `
                (Format-FileSize $BytesReceived), `
                (Format-FileSize $TotalBytes)
    }
    else {

        $CurrentProgressBar.IsIndeterminate = $true

        $CurrentProgressText.Text =
            "Downloading..."

        $CurrentSizeText.Text =
            Format-FileSize $BytesReceived
    }

    if ($SpeedBytesPerSecond -gt 0) {

        $CurrentSpeedText.Text =
            "{0}/s" -f (Format-FileSize $SpeedBytesPerSecond)
    }
    else {

        $CurrentSpeedText.Text = ""
    }

    if ($null -ne $Window) {
        $Window.Dispatcher.Invoke(
            [Action] {},
            [System.Windows.Threading.DispatcherPriority]::Background
        )
    }
}

# ==========================================
# Download installer
# ==========================================

function Download-Installer {

    param (
        [Parameter(Mandatory = $true)]
        [string]$Url,

        [Parameter(Mandatory = $true)]
        [string]$Destination
    )

    $WebRequest = [System.Net.HttpWebRequest]::Create($Url)

    $WebRequest.Method = "GET"
    $WebRequest.UserAgent = "EduDeploy/$Version"
    $WebRequest.AllowAutoRedirect = $true

    $Response = $null
    $InputStream = $null
    $OutputStream = $null

    try {

        $Response = $WebRequest.GetResponse()

        $TotalBytes = $Response.ContentLength

        $InputStream = $Response.GetResponseStream()

        $OutputStream = [System.IO.File]::Create($Destination)

        $Buffer = New-Object byte[] 65536

        [long]$BytesReceived = 0

        $Stopwatch =
            [System.Diagnostics.Stopwatch]::StartNew()

        $LastUpdate = 0

        while (
            ($Read = $InputStream.Read(
                $Buffer,
                0,
                $Buffer.Length
            )) -gt 0
        ) {

            $OutputStream.Write(
                $Buffer,
                0,
                $Read
            )

            $BytesReceived += $Read

            $ElapsedSeconds =
                $Stopwatch.Elapsed.TotalSeconds

            if ($ElapsedSeconds -gt 0) {
                $Speed =
                    $BytesReceived / $ElapsedSeconds
            }
            else {
                $Speed = 0
            }

            if (
                ($Stopwatch.ElapsedMilliseconds - $LastUpdate) -ge 100
            ) {

                Update-DownloadProgress `
                    -BytesReceived $BytesReceived `
                    -TotalBytes $TotalBytes `
                    -SpeedBytesPerSecond $Speed

                $LastUpdate =
                    $Stopwatch.ElapsedMilliseconds
            }
        }

        $Stopwatch.Stop()

        Update-DownloadProgress `
            -BytesReceived $BytesReceived `
            -TotalBytes $TotalBytes `
            -SpeedBytesPerSecond 0
    }
    finally {

        if ($null -ne $OutputStream) {
            $OutputStream.Close()
        }

        if ($null -ne $InputStream) {
            $InputStream.Close()
        }

        if ($null -ne $Response) {
            $Response.Close()
        }
    }
}

# ==========================================
# Run installer process
# ==========================================

function Start-InstallerProcess {

    param (
        [Parameter(Mandatory = $true)]
        [string]$FilePath,

        [Parameter(Mandatory = $true)]
        [string]$Arguments,

        [Parameter(Mandatory = $true)]
        [string]$WorkingDirectory
    )

    $Process =
        New-Object System.Diagnostics.Process

    $Process.StartInfo =
        New-Object System.Diagnostics.ProcessStartInfo

    $Process.StartInfo.FileName =
        $FilePath

    $Process.StartInfo.Arguments =
        $Arguments

    $Process.StartInfo.WorkingDirectory =
        $WorkingDirectory

    $Process.StartInfo.UseShellExecute =
        $true

    $Process.StartInfo.Verb =
        "runas"

    [void]$Process.Start()

    while (-not $Process.HasExited) {

        if ($null -ne $Window) {

            $Window.Dispatcher.Invoke(
                [Action] {},
                [System.Windows.Threading.DispatcherPriority]::Background
            )
        }

        Start-Sleep -Milliseconds 100
    }

    $ExitCode =
        $Process.ExitCode

    $Process.Dispose()

    return $ExitCode
}

# ==========================================
# Install application
# ==========================================

function Install-Application {

    param (
        [Parameter(Mandatory = $true)]
        $App
    )

    $TempDir =
        Join-Path $env:TEMP "EduDeploy"

    if (-not (Test-Path $TempDir)) {

        New-Item `
            -ItemType Directory `
            -Path $TempDir `
            -Force |
            Out-Null
    }

    # ==========================================
    # WinGet application
    # ==========================================

    if ($App.installerType -eq "winget") {

        if ([string]::IsNullOrWhiteSpace($App.packageId)) {
            throw "WinGet packageId is missing for $($App.name)."
        }

        $Winget =
            Get-Command winget.exe -ErrorAction SilentlyContinue

        if ($null -eq $Winget) {
            throw "WinGet is not available on this Windows installation."
        }

        Write-Status `
            "Installing $($App.name) with WinGet..."

        $CurrentProgressBar.IsIndeterminate =
            $true

        $CurrentProgressText.Text =
            "Installing"

        $CurrentSizeText.Text = ""
        $CurrentSpeedText.Text = ""

        $InstallArgs = @(
            "install"
            "--id"
            $App.packageId
            "--exact"
            "--silent"
            "--disable-interactivity"
            "--accept-package-agreements"
            "--accept-source-agreements"
        )

        $ProcessInfo =
            New-Object System.Diagnostics.ProcessStartInfo

        $ProcessInfo.FileName =
            $Winget.Source

        $ProcessInfo.Arguments =
            ($InstallArgs -join " ")

        $ProcessInfo.UseShellExecute =
            $true

        $ProcessInfo.Verb =
            "runas"

        $Process =
            New-Object System.Diagnostics.Process

        $Process.StartInfo =
            $ProcessInfo

        [void]$Process.Start()

        while (-not $Process.HasExited) {

            if ($null -ne $Window) {

                $Window.Dispatcher.Invoke(
                    [Action] {},
                    [System.Windows.Threading.DispatcherPriority]::Background
                )
            }

            Start-Sleep -Milliseconds 200
        }

        $ExitCode =
            $Process.ExitCode

        $Process.Dispose()

        if ($ExitCode -notin @(0, 3010)) {

            throw (
                "$($App.name): WinGet installation failed.`n`n" +
                "Exit code: $ExitCode"
            )
        }

        return @{
            Type = "installer"
            Success = $true
            RestartRequired = ($ExitCode -eq 3010)
            ExitCode = $ExitCode
        }
    }

    # ==========================================
    # Website application
    # ==========================================

    if ($App.installerType -eq "website") {

        if (
            [string]::IsNullOrWhiteSpace(
                $App.website
            )
        ) {
            throw "No website has been configured for this application."
        }

        Write-Status "Opening download page..."

        Start-Process `
            -FilePath $App.website

        return @{
            Type = "website"
            Success = $true
        }
    }

    # ==========================================
    # Download URL
    # ==========================================

    if (
        [string]::IsNullOrWhiteSpace(
            $App.downloadUrl
        )
    ) {
        throw "No downloadUrl has been configured for this application."
    }

    # ==========================================
    # Installer type
    # ==========================================

    $Extension = ".bin"

    switch ($App.installerType.ToLower()) {

        "msi" {
            $Extension = ".msi"
        }

        "exe" {
            $Extension = ".exe"
        }

        default {
            throw "Unknown installerType: $($App.installerType)"
        }
    }

    # ==========================================
    # Safe filename
    # ==========================================

    $SafeName =
        $App.name -replace '[^a-zA-Z0-9_-]', '_'

    $InstallerPath =
        Join-Path `
            $TempDir `
            "$SafeName$Extension"

    $LogPath =
        Join-Path `
            $TempDir `
            "$SafeName-install.log"

    # ==========================================
    # Remove old files
    # ==========================================

    if (Test-Path $InstallerPath) {

        Remove-Item `
            $InstallerPath `
            -Force `
            -ErrorAction SilentlyContinue
    }

    if (Test-Path $LogPath) {

        Remove-Item `
            $LogPath `
            -Force `
            -ErrorAction SilentlyContinue
    }

    # ==========================================
    # Prepare progress
    # ==========================================

    $CurrentProgressBar.Foreground =
        [System.Windows.Media.Brushes]::Gray

    $CurrentProgressBar.IsIndeterminate =
        $false

    $CurrentProgressBar.Value =
        0

    $CurrentProgressText.Text =
        "0 %"

    $CurrentSpeedText.Text =
        ""

    $CurrentSizeText.Text =
        ""

    # ==========================================
    # Download
    # ==========================================

    Write-Status "Downloading $($App.name)..."

    Download-Installer `
        -Url $App.downloadUrl `
        -Destination $InstallerPath

    # ==========================================
    # Verify download
    # ==========================================

    if (-not (Test-Path $InstallerPath)) {
        throw "$($App.name): download failed."
    }

    $FileSize =
        (Get-Item $InstallerPath).Length

    if ($FileSize -lt 10KB) {
        throw "$($App.name): downloaded file appears to be too small."
    }

    # ==========================================
    # Download complete
    # ==========================================

    $CurrentProgressBar.IsIndeterminate =
        $false

    $CurrentProgressBar.Value =
        100

    $CurrentProgressText.Text =
        "100 %"

    $CurrentSizeText.Text =
        Format-FileSize $FileSize

    $CurrentSpeedText.Text =
        ""

    # ==========================================
    # Installation
    # ==========================================

    Write-Status "Installing $($App.name)..."

    $CurrentProgressBar.IsIndeterminate =
        $true

    $CurrentProgressText.Text =
        "Installing"

    $CurrentSizeText.Text =
        ""

    $CurrentSpeedText.Text =
        ""

    # ==========================================
    # MSI installer
    # ==========================================

    if ($App.installerType.ToLower() -eq "msi") {

        $Arguments =
            "/i `"$InstallerPath`""

        if (
            -not [string]::IsNullOrWhiteSpace(
                $App.installerArguments
            )
        ) {

            $Arguments +=
                " $($App.installerArguments)"
        }

        $Arguments +=
            " /L*v `"$LogPath`""

        $ExitCode =
            Start-InstallerProcess `
                -FilePath "msiexec.exe" `
                -Arguments $Arguments `
                -WorkingDirectory $TempDir

        if ($ExitCode -eq 0) {

            return @{
                Type = "installer"
                Success = $true
                ExitCode = $ExitCode
                InstallerPath = $InstallerPath
                LogPath = $LogPath
            }
        }

        if ($ExitCode -eq 3010) {

            return @{
                Type = "installer"
                Success = $true
                RestartRequired = $true
                ExitCode = $ExitCode
                InstallerPath = $InstallerPath
                LogPath = $LogPath
            }
        }

        throw (
            "$($App.name): MSI installation failed.`n`n" +
            "Exit code: $ExitCode`n`n" +
            "Log file:`n$LogPath"
        )
    }

    # ==========================================
    # EXE installer
    # ==========================================

    if ($App.installerType.ToLower() -eq "exe") {

        $Arguments = ""

        if (
            -not [string]::IsNullOrWhiteSpace(
                $App.installerArguments
            )
        ) {

            $Arguments =
                $App.installerArguments
        }

        $ExitCode =
            Start-InstallerProcess `
                -FilePath $InstallerPath `
                -Arguments $Arguments `
                -WorkingDirectory $TempDir

        if ($ExitCode -eq 0 -or $ExitCode -eq 3010) {

            return @{
                Type = "installer"
                Success = $true
                RestartRequired = ($ExitCode -eq 3010)
                ExitCode = $ExitCode
                InstallerPath = $InstallerPath
            }
        }

        throw (
            "$($App.name): EXE installation failed.`n`n" +
            "Exit code: $ExitCode"
        )
    }
}

# ==========================================
# Main Window
# ==========================================

$Window =
    New-Object System.Windows.Window

$Window.Title =
    "EduDeploy"

$Window.Width =
    1000

$Window.Height =
    700

$Window.MinWidth =
    800

$Window.MinHeight =
    500

$Window.WindowStartupLocation =
    "CenterScreen"

$Window.Background =
    "#F5F5F5"

# ==========================================
# Main Grid
# ==========================================

$MainGrid =
    New-Object System.Windows.Controls.Grid

$SidebarColumn =
    New-Object System.Windows.Controls.ColumnDefinition

$SidebarColumn.Width =
    "230"

$ContentColumn =
    New-Object System.Windows.Controls.ColumnDefinition

$ContentColumn.Width =
    "*"

$MainGrid.ColumnDefinitions.Add(
    $SidebarColumn
)

$MainGrid.ColumnDefinitions.Add(
    $ContentColumn
)

# ==========================================
# Sidebar
# ==========================================

$Sidebar =
    New-Object System.Windows.Controls.StackPanel

$Sidebar.Margin =
    "20"

[System.Windows.Controls.Grid]::SetColumn(
    $Sidebar,
    0
)

$Logo =
    New-Object System.Windows.Controls.TextBlock

$Logo.Text =
    "EduDeploy"

$Logo.FontSize =
    30

$Logo.FontWeight =
    "Bold"

$Logo.Margin =
    "0,5,0,0"

$Sidebar.Children.Add(
    $Logo
)

$Subtitle =
    New-Object System.Windows.Controls.TextBlock

$Subtitle.Text =
    "Student Software Installer"

$Subtitle.FontSize =
    13

$Subtitle.Foreground =
    "#666666"

$Subtitle.Margin =
    "0,2,0,25"

$Sidebar.Children.Add(
    $Subtitle
)

$NavigationTitle =
    New-Object System.Windows.Controls.TextBlock

$NavigationTitle.Text =
    "CATEGORIES"

$NavigationTitle.FontSize =
    11

$NavigationTitle.FontWeight =
    "Bold"

$NavigationTitle.Foreground =
    "#777777"

$NavigationTitle.Margin =
    "0,0,0,10"

$Sidebar.Children.Add(
    $NavigationTitle
)

# ==========================================
# Category scroll area
# ==========================================

$CategoryScroll =
    New-Object System.Windows.Controls.ScrollViewer

$CategoryScroll.Height =
    450

$CategoryScroll.VerticalScrollBarVisibility =
    "Auto"

$CategoryScroll.HorizontalScrollBarVisibility =
    "Disabled"

$CategoryPanel =
    New-Object System.Windows.Controls.StackPanel

$CategoryScroll.Content =
    $CategoryPanel

$Sidebar.Children.Add(
    $CategoryScroll
)

# ==========================================
# Version
# ==========================================

$VersionText =
    New-Object System.Windows.Controls.TextBlock

$VersionText.Text =
    "EduDeploy v$Version"

$VersionText.Foreground =
    "#888888"

$VersionText.Margin =
    "0,15,0,0"

$Sidebar.Children.Add(
    $VersionText
)

# ==========================================
# Content
# ==========================================

$Content =
    New-Object System.Windows.Controls.StackPanel

$Content.Margin =
    "30"

[System.Windows.Controls.Grid]::SetColumn(
    $Content,
    1
)

$Header =
    New-Object System.Windows.Controls.TextBlock

$Header.Text =
    "All Applications"

$Header.FontSize =
    28

$Header.FontWeight =
    "Bold"

$Header.Margin =
    "0,0,0,5"

$Content.Children.Add(
    $Header
)

$DescriptionHeader =
    New-Object System.Windows.Controls.TextBlock

$DescriptionHeader.Text =
    "Install the software you need from one place."

$DescriptionHeader.Foreground =
    "#666666"

$DescriptionHeader.Margin =
    "0,0,0,20"

$Content.Children.Add(
    $DescriptionHeader
)

# ==========================================
# Status panel
# ==========================================

$StatusBorder =
    New-Object System.Windows.Controls.Border

$StatusBorder.Background =
    "White"

$StatusBorder.BorderBrush =
    "#DDDDDD"

$StatusBorder.BorderThickness =
    "1"

$StatusBorder.Padding =
    "15"

$StatusBorder.Margin =
    "0,0,0,15"

$StatusPanel =
    New-Object System.Windows.Controls.StackPanel

$CurrentStatusText =
    New-Object System.Windows.Controls.TextBlock

$CurrentStatusText.Text =
    "Ready"

$CurrentStatusText.FontSize =
    15

$CurrentStatusText.FontWeight =
    "Bold"

$StatusPanel.Children.Add(
    $CurrentStatusText
)

# ==========================================
# Progress grid
# ==========================================

$ProgressGrid =
    New-Object System.Windows.Controls.Grid

$ProgressGrid.Margin =
    "0,12,0,0"

$ProgressColumn =
    New-Object System.Windows.Controls.ColumnDefinition

$ProgressColumn.Width =
    "*"

$PercentColumn =
    New-Object System.Windows.Controls.ColumnDefinition

$PercentColumn.Width =
    "100"

$ProgressGrid.ColumnDefinitions.Add(
    $ProgressColumn
)

$ProgressGrid.ColumnDefinitions.Add(
    $PercentColumn
)

$CurrentProgressBar =
    New-Object System.Windows.Controls.ProgressBar

$CurrentProgressBar.Height =
    12

$CurrentProgressBar.Minimum =
    0

$CurrentProgressBar.Maximum =
    100

$CurrentProgressBar.Value =
    0

[System.Windows.Controls.Grid]::SetColumn(
    $CurrentProgressBar,
    0
)

$CurrentProgressText =
    New-Object System.Windows.Controls.TextBlock

$CurrentProgressText.Text =
    "0 %"

$CurrentProgressText.HorizontalAlignment =
    "Right"

$CurrentProgressText.VerticalAlignment =
    "Center"

$CurrentProgressText.Margin =
    "10,0,0,0"

[System.Windows.Controls.Grid]::SetColumn(
    $CurrentProgressText,
    1
)

$ProgressGrid.Children.Add(
    $CurrentProgressBar
)

$ProgressGrid.Children.Add(
    $CurrentProgressText
)

$StatusPanel.Children.Add(
    $ProgressGrid
)

# ==========================================
# Download information
# ==========================================

$DownloadInfoGrid =
    New-Object System.Windows.Controls.Grid

$DownloadInfoGrid.Margin =
    "0,8,0,0"

$SizeColumn =
    New-Object System.Windows.Controls.ColumnDefinition

$SizeColumn.Width =
    "*"

$SpeedColumn =
    New-Object System.Windows.Controls.ColumnDefinition

$SpeedColumn.Width =
    "*"

$DownloadInfoGrid.ColumnDefinitions.Add(
    $SizeColumn
)

$DownloadInfoGrid.ColumnDefinitions.Add(
    $SpeedColumn
)

$CurrentSizeText =
    New-Object System.Windows.Controls.TextBlock

$CurrentSizeText.Text =
    ""

[System.Windows.Controls.Grid]::SetColumn(
    $CurrentSizeText,
    0
)

$CurrentSpeedText =
    New-Object System.Windows.Controls.TextBlock

$CurrentSpeedText.Text =
    ""

$CurrentSpeedText.HorizontalAlignment =
    "Right"

[System.Windows.Controls.Grid]::SetColumn(
    $CurrentSpeedText,
    1
)

$DownloadInfoGrid.Children.Add(
    $CurrentSizeText
)

$DownloadInfoGrid.Children.Add(
    $CurrentSpeedText
)

$StatusPanel.Children.Add(
    $DownloadInfoGrid
)

$StatusBorder.Child =
    $StatusPanel

$Content.Children.Add(
    $StatusBorder
)

# ==========================================
# Application ScrollViewer
# ==========================================

$AppScrollViewer =
    New-Object System.Windows.Controls.ScrollViewer

$AppScrollViewer.Height =
    470

$AppScrollViewer.VerticalScrollBarVisibility =
    "Auto"

$AppScrollViewer.HorizontalScrollBarVisibility =
    "Disabled"

$AppPanel =
    New-Object System.Windows.Controls.StackPanel

$AppScrollViewer.Content =
    $AppPanel

$Content.Children.Add(
    $AppScrollViewer
)

# ==========================================
# Application rendering
# ==========================================

function Show-Applications {

    param (
        [string]$Category = "All"
    )

    $AppPanel.Children.Clear()

    if ($Category -eq "All") {

        $Header.Text =
            "All Applications"

        $DescriptionHeader.Text =
            "Install the software you need from one place."
    }
    else {

        $Header.Text =
            "$Category Software"

        $DescriptionHeader.Text =
            "Available software in the $Category category."
    }

    foreach ($App in $Config.applications) {

        if (
            $Category -ne "All" -and
            $App.category -ne $Category
        ) {
            continue
        }

        # ==========================================
        # Card
        # ==========================================

        $Card =
            New-Object System.Windows.Controls.Border

        $Card.Background =
            "White"

        $Card.BorderBrush =
            "#DDDDDD"

        $Card.BorderThickness =
            "1"

        $Card.Padding =
            "18"

        $Card.Margin =
            "0,0,0,12"

        $CardGrid =
            New-Object System.Windows.Controls.Grid

        $InfoColumn =
            New-Object System.Windows.Controls.ColumnDefinition

        $InfoColumn.Width =
            "*"

        $ButtonColumn =
            New-Object System.Windows.Controls.ColumnDefinition

        $ButtonColumn.Width =
            "120"

        $CardGrid.ColumnDefinitions.Add(
            $InfoColumn
        )

        $CardGrid.ColumnDefinitions.Add(
            $ButtonColumn
        )

        # ==========================================
        # Information
        # ==========================================

        $Info =
            New-Object System.Windows.Controls.StackPanel

        $Name =
            New-Object System.Windows.Controls.TextBlock

        $Name.Text =
            $App.name

        $Name.FontSize =
            19

        $Name.FontWeight =
            "Bold"

        $AppDescription =
            New-Object System.Windows.Controls.TextBlock

        $AppDescription.Text =
            $App.description

        $AppDescription.Foreground =
            "#666666"

        $AppDescription.TextWrapping =
            "Wrap"

        $AppDescription.Margin =
            "0,5,0,0"

        $VersionInfo =
            New-Object System.Windows.Controls.TextBlock

        $VersionInfo.Text =
            "Version: $($App.version)"

        $VersionInfo.Foreground =
            "#888888"

        $VersionInfo.FontSize =
            12

        $VersionInfo.Margin =
            "0,6,0,0"

        $Info.Children.Add(
            $Name
        )

        $Info.Children.Add(
            $AppDescription
        )

        $Info.Children.Add(
            $VersionInfo
        )

        [System.Windows.Controls.Grid]::SetColumn(
            $Info,
            0
        )

        # ==========================================
        # Install button
        # ==========================================

        $InstallButton =
            New-Object System.Windows.Controls.Button

        $IsInstalled =
            Test-ApplicationInstalled -App $App

        # WinGet applications get an additional
        # package check if registry detection failed.

        if (
            -not $IsInstalled -and
            $App.installerType -eq "winget"
        ) {

            $IsInstalled =
                Test-WingetInstalled -App $App
        }

        if ($IsInstalled) {

            $InstallButton.Content =
                "INSTALLED"

            $InstallButton.IsEnabled =
                $false
        }
        elseif ($App.installerType -eq "website") {

            $InstallButton.Content =
                "DOWNLOAD"
        }
        else {

            $InstallButton.Content =
                "INSTALL"
        }

        $InstallButton.Width =
            100

        $InstallButton.Height =
            38

        $InstallButton.VerticalAlignment =
            "Center"

        $InstallButton.HorizontalAlignment =
            "Right"

        $CurrentApp =
            $App

        $CurrentButton =
            $InstallButton

        $InstallButton.Add_Click({

            try {

                $CurrentButton.IsEnabled =
                    $false

                # ==========================================
                # Website application
                # ==========================================

                if (
                    $CurrentApp.installerType -eq "website"
                ) {

                    $CurrentButton.Content =
                        "OPENING..."

                    Write-Status `
                        "Opening download page..."

                    Install-Application `
                        -App $CurrentApp |
                        Out-Null

                    $CurrentButton.Content =
                        "DOWNLOAD"

                    $CurrentButton.IsEnabled =
                        $true

                    Write-Status "Ready"

                    return
                }

                # ==========================================
                # Installer application
                # ==========================================

                $CurrentButton.Content =
                    "INSTALLING..."

                $Result =
                    Install-Application `
                        -App $CurrentApp

                # ==========================================
                # Clear installation cache
                # ==========================================

                if ($null -ne $script:InstalledApplicationCache) {
                    $script:InstalledApplicationCache.Clear()
                }

                # ==========================================
                # Verify installation
                # ==========================================

                Write-Status `
                    "Verifying installation..."

                $CurrentProgressBar.IsIndeterminate =
                    $true

                $CurrentProgressText.Text =
                    "Checking"

                $Window.Dispatcher.Invoke(
                    [Action] {},
                    [System.Windows.Threading.DispatcherPriority]::Background
                )

                Start-Sleep -Milliseconds 500

                $Installed =
                    Test-ApplicationInstalled `
                        -App $CurrentApp

                # WinGet fallback verification

                if (
                    -not $Installed -and
                    $CurrentApp.installerType -eq "winget"
                ) {

                    $Installed =
                        Test-WingetInstalled `
                            -App $CurrentApp
                }

                # ==========================================
                # Installation successful
                # ==========================================

                if ($Installed) {

                    $CurrentProgressBar.IsIndeterminate =
                        $false

                    $CurrentProgressBar.Value =
                        100

                    $CurrentProgressText.Text =
                        "100 %"

                    $CurrentSizeText.Text =
                        ""

                    $CurrentSpeedText.Text =
                        ""

                    $CurrentProgressBar.Foreground =
                        [System.Windows.Media.Brushes]::Green

                    Write-Status `
                        "Installation complete"

                    $CurrentButton.Content =
                        "INSTALLED"

                    $CurrentButton.IsEnabled =
                        $false

                    if ($Result.RestartRequired) {

                        [System.Windows.MessageBox]::Show(
                            "$($CurrentApp.name) was installed successfully.`n`nA Windows restart may be required.",
                            "EduDeploy v$Version"
                        )
                    }
                    else {

                        [System.Windows.MessageBox]::Show(
                            "$($CurrentApp.name) was installed successfully.",
                            "EduDeploy v$Version"
                        )
                    }
                }
                else {

                    throw (
                        "$($CurrentApp.name) installer finished successfully, " +
                        "but EduDeploy could not verify the installation.`n`n" +
                        "The application may still be installed. " +
                        "You can check Windows or launch the application manually."
                    )
                }
            }
            catch {

                # ==========================================
                # Installation failed
                # ==========================================

                $CurrentButton.Content =
                    "INSTALL"

                $CurrentButton.IsEnabled =
                    $true

                Write-Status `
                    "Installation failed"

                $CurrentProgressBar.IsIndeterminate =
                    $false

                $CurrentProgressBar.Value =
                    0

                $CurrentProgressBar.Foreground =
                    [System.Windows.Media.Brushes]::Gray

                $CurrentProgressText.Text =
                    "0 %"

                $CurrentSpeedText.Text =
                    ""

                $CurrentSizeText.Text =
                    ""

                [System.Windows.MessageBox]::Show(
                    "$($CurrentApp.name) installation failed.`n`n$($_.Exception.Message)",
                    "EduDeploy v$Version"
                )
            }

        }.GetNewClosure())

        [System.Windows.Controls.Grid]::SetColumn(
            $InstallButton,
            1
        )

        $CardGrid.Children.Add(
            $Info
        )

        $CardGrid.Children.Add(
            $InstallButton
        )

        $Card.Child =
            $CardGrid

        $AppPanel.Children.Add(
            $Card
        )
    }
}

# ==========================================
# All applications button
# ==========================================

$AllButton =
    New-Object System.Windows.Controls.Button

$AllButton.Content =
    "All Applications"

$AllButton.Height =
    40

$AllButton.HorizontalContentAlignment =
    "Left"

$AllButton.Padding =
    "15,0"

$AllButton.Margin =
    "0,0,0,6"

$AllButton.Add_Click({

    Show-Applications `
        -Category "All"

})

$CategoryPanel.Children.Add(
    $AllButton
)

# ==========================================
# Dynamic categories from config.json
# ==========================================

$Categories =
    @(
        $Config.applications |
        ForEach-Object {
            $_.category
        } |
        Where-Object {
            -not [string]::IsNullOrWhiteSpace($_)
        } |
        Sort-Object -Unique
    )

foreach ($Category in $Categories) {

    $CategoryButton =
        New-Object System.Windows.Controls.Button

    $CategoryButton.Content =
        $Category

    $CategoryButton.Height =
        40

    $CategoryButton.HorizontalContentAlignment =
        "Left"

    $CategoryButton.Padding =
        "15,0"

    $CategoryButton.Margin =
        "0,0,0,6"

    $CurrentCategory =
        $Category

    $CategoryButton.Add_Click({

        Show-Applications `
            -Category $CurrentCategory

    }.GetNewClosure())

    $CategoryPanel.Children.Add(
        $CategoryButton
    )
}

# ==========================================
# Assemble window
# ==========================================

$MainGrid.Children.Add(
    $Sidebar
)

$MainGrid.Children.Add(
    $Content
)

$Window.Content =
    $MainGrid

# ==========================================
# Initial view
# ==========================================

Show-Applications `
    -Category "All"

# ==========================================
# Start
# ==========================================

$Window.ShowDialog() |
    Out-Null