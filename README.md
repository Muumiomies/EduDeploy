# EduDeploy

**EduDeploy** is a centralized Windows software deployment tool designed for students and educational environments.

It provides a simple way to download and install commonly used 3D, CAD and other technical software from a single application.

The goal is to make software setup easier for students by removing the need to manually find, download and install every application separately.

## ✨ Features

* 🖥️ Simple Windows graphical user interface
* 📦 Download and install applications from one place
* 📊 Download progress tracking
* ⚙️ Installation status and progress
* 🔧 MSI and EXE installer support
* 🌐 Website-based installation support
* 🔐 Installations can run with administrator privileges
* 📝 MSI installation logging
* 🗂️ Application categories
* 📁 Temporary installer storage
* ⚙️ Application configuration through `config.json`

## 🛠️ Supported Applications

| Application     | Category | Version | Installation Method |
| --------------- | -------- | ------: | ------------------- |
| Blender         | 3D       |  4.5.13 | MSI                 |
| Autodesk Fusion | CAD      |    2026 | Website             |
| Rhino           | 3D       |       8 | Website             |
| SolidWorks      | CAD      |    2026 | Website             |

> Application versions, download URLs and installation settings are defined in `config.json`.

## 🚀 Getting Started

### Requirements

* Windows 10 or Windows 11
* PowerShell
* Internet connection
* Administrator privileges for software installation

### Run EduDeploy

Clone or download the repository and open a PowerShell window in the project directory.

Run:

```powershell
powershell -ExecutionPolicy Bypass -File .\EduDeploy.ps1
```

### Recommended Directory Structure

```text
C:\EduDeploy\
├── EduDeploy.ps1
├── config.json
├── README.md
├── LICENSE
└── .gitignore
```

## ⚙️ Configuration

Applications are managed through the `config.json` file.

This allows applications to be added or modified without changing the main installer logic.

### Example Configuration

```json
{
  "name": "Blender",
  "description": "3D modeling, animation and rendering",
  "category": "3D",
  "version": "4.5.13",
  "downloadUrl": "https://download.blender.org/release/Blender4.5/blender-4.5.13-windows-x64.msi",
  "installerType": "msi",
  "installerArguments": "/qn /norestart",
  "installedCheck": "blender.exe"
}
```

### Installer Types

EduDeploy currently supports three installation types:

| Type      | Description                                         |
| --------- | --------------------------------------------------- |
| `msi`     | Downloads and automatically installs an MSI package |
| `exe`     | Downloads and launches an EXE installer             |
| `website` | Opens the application's website or download page    |

## 📦 Temporary Files

Downloaded installer files are temporarily stored in:

```text
%TEMP%\EduDeploy\
```

For example:

```text
%TEMP%\EduDeploy\Blender.msi
```

MSI installations also generate a log file:

```text
%TEMP%\EduDeploy\Blender-install.log
```

These logs can be used to troubleshoot MSI installation problems.

## 🔐 Administrator Privileges

Applications that require elevated permissions are launched with Windows administrator privileges.

Windows may display a User Account Control (UAC) confirmation before starting an installation.

## 📈 Installation Process

For supported installers, EduDeploy handles the basic installation process:

```text
Select application
       ↓
Download installer
       ↓
Show download progress
       ↓
Start installation
       ↓
Show installation status
       ↓
Installation complete
```

Applications using the `website` installer type are opened in the default web browser instead.

## 🧪 Development Status

EduDeploy is currently under active development.

### v0.1

* Initial user interface
* Application categories
* Application cards
* Basic project structure

### v0.2

* Blender MSI download
* MSI installation
* Administrator privileges
* MSI installation logging
* Successful Blender installation

### v0.3

* Generic installation system
* MSI support
* EXE support
* Website support
* Installation methods defined through `config.json`
* Blender no longer requires application-specific installation code

### v0.4.1

* Download progress indicator
* Installation status and progress
* Improved installation experience
* Responsive installation handling
* English user interface
* English application configuration
* Improved download and installer handling

## 🗺️ Roadmap

Planned features:

* [ ] Automatic installation detection
* [ ] Detect already installed applications
* [ ] `INSTALLED` state when EduDeploy starts
* [ ] Improved download progress information
* [ ] Download speed display
* [ ] More 3D and CAD applications
* [ ] Improved EXE installer support
* [ ] Software update management
* [ ] Student-specific authentication
* [ ] Centralized software management
* [ ] Ready-to-use Windows distribution package

## 🎓 Project Goal

EduDeploy is designed to simplify software deployment in educational environments.

Instead of requiring students to search for every application individually, EduDeploy aims to provide a single place where the required software can be installed.

From a student's perspective, the process should be simple:

```text
Open EduDeploy
       ↓
Select an application
       ↓
Click INSTALL
       ↓
EduDeploy downloads the installer
       ↓
EduDeploy installs the application
       ↓
Done
```

## 📄 License

Copyright (c) 2026 Johannes Loponen

All rights reserved.

The source code is publicly available for viewing and educational purposes.

See the [LICENSE](LICENSE) file for the complete license terms.
