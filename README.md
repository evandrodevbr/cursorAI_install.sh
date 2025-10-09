# Cursor IDE - Smart Installation Script

[![Version](https://img.shields.io/badge/version-1.0.0-blue.svg)](https://github.com/evandrodevbr/cursorAI_install.sh)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-Linux-lightgrey.svg)](https://www.linux.org/)
[![Status](https://img.shields.io/badge/status-active-brightgreen.svg)](https://github.com/truuta/cursorAI_install.sh)

An elegant and robust bash script for managing Cursor IDE on Linux, providing a smooth and interactive installation experience.

## Table of Contents

- [Features](#features)
- [Prerequisites](#prerequisites)
- [Quick Installation](#quick-installation)
- [Usage Guide](#usage-guide)
- [Technical Architecture](#technical-architecture)
- [FAQ](#faq)
- [Troubleshooting](#troubleshooting)
- [Advanced Examples](#advanced-examples)
- [Contributing](#contributing)
- [License](#license)

## Features

### Smart Installation

- Automatic verification of existing installations
- Available disk space detection
- Internet connectivity testing
- Automatic directory structure creation
- Shortcuts and system integrations configuration

### Installation Management

- Automatic backup system during updates
- Safe and complete removal
- Corrupted installation repair
- Support for parallel multiple installations
- Rollback system in case of failure

### User Interface

- Visual progress bar during downloads
- Colored and user-friendly interface
- Detailed and informative logs
- Real-time success/failure indicators

## Prerequisites

### Operating System

- Linux (any modern distribution)
- Bash 4.0 or higher
- Internet connection
- 500MB free disk space
- Appropriate user permissions

### System Dependencies

- `curl` - For downloads
- `gtk-update-icon-cache` - For icon updates
- `update-desktop-database` - For application updates

> **Note:** Most Linux distributions already have these dependencies installed by default.

## Quick Installation

### 1. Download the Script

```bash
git clone https://github.com/truuta/cursorAI_install.sh.git
cd cursorAI_install.sh
chmod +x cursor-ai.sh
```

### 2. Basic Installation

```bash
./cursor-ai.sh --install
```

### 3. Other Options

```bash
./cursor-ai.sh --help      # Show help
./cursor-ai.sh --repair    # Repair installation
./cursor-ai.sh --uninstall # Uninstall Cursor
```

## Usage Guide

### Command Line Options

| Option            | Description         | Example                      |
| ----------------- | ------------------- | ---------------------------- |
| `-i, --install`   | Install Cursor IDE  | `./cursor-ai.sh --install`   |
| `-u, --uninstall` | Remove Cursor IDE   | `./cursor-ai.sh --uninstall` |
| `-r, --repair`    | Repair installation | `./cursor-ai.sh --repair`    |
| `-h, --help`      | Show help           | `./cursor-ai.sh --help`      |

### Existing Installation Management

When the script detects existing installations, it offers the following options:

#### **U - Update**

- Creates automatic backup of current version
- Downloads new version with integrity verification
- Automatic rollback system in case of failure
- Post-download validation

#### **R - Remove Specific**

- Removes selected installation
- Cleans all associated files
- Updates system cache
- Removes application entries

#### **A - Remove All**

- Complete system cleanup
- Removes all found versions
- Cleans cache and registries

#### **S - Substitute**

- Keeps existing installations
- Adds new installation in parallel
- Preserves previous versions

### Update System

The script implements a robust update system:

- **Download with Retry**: Up to 3 attempts with 30-second timeout
- **Integrity Verification**: Validation of downloaded files
- **Automatic Backup**: Preserves previous version during update
- **Smart Rollback**: Restores previous version in case of failure
- **Progress Bar**: Visual feedback during download

## Technical Architecture

### Directory Structure

The script organizes files as follows:

```
${HOME}/
├── Applications/
│   └── cursor.AppImage          # Main executable
├── .local/
│   ├── bin/
│   │   └── cursor              # Launcher script
│   └── share/
│       ├── applications/
│       │   └── cursor.desktop   # Desktop file
│       └── icons/
│           └── cursor-icon.svg  # Application icon
└── .cursor_log                  # Execution log
```

### System Components

#### **AppImage**

- Portable Cursor IDE executable
- Downloaded from: `https://downloader.cursor.sh/linux/appImage/x64`
- Execution permissions configured automatically

#### **Launcher Script**

- Wrapper script in `~/.local/bin/cursor`
- Manages logs and command line arguments
- Configurable sandbox mode support

#### **Desktop File**

- Desktop environment integration
- Appropriate icon and categorization
- MIME types for code files

### Execution Flow

1. **Preliminary Checks**

   - Available disk space
   - Internet connectivity
   - Existing installations

2. **Download and Installation**

   - Download with automatic retry
   - Integrity verification
   - Permission configuration

3. **System Integration**
   - Desktop file creation
   - Icon configuration
   - System cache update

## Logs and Diagnostics

The script maintains detailed logs in:

- `~/.cursor_log` - Execution logs
- Colored messages in terminal
- Real-time progress information

### Log Verification

```bash
# View recent logs
tail -f ~/.cursor_log

# Check last execution
tail -20 ~/.cursor_log
```

## Troubleshooting

### Common Issues

#### **Insufficient Space**

```bash
# Check available space
df -h

# Clear cache if necessary
rm -rf /tmp/cursor_installer
```

#### **Download Failure**

- The script automatically tries 3 times
- Verifies connectivity with `ping 8.8.8.8`
- Timeout configured for 30 seconds

#### **Permission Issues**

```bash
# Check launcher permissions
ls -l ~/.local/bin/cursor

# Fix permissions if necessary
chmod +x ~/.local/bin/cursor
```

#### **Corrupted Installation**

```bash
# Run automatic repair
./cursor-ai.sh --repair
```

## FAQ

### How does the automatic backup system work?

The script automatically creates a backup of the current version before any update. If the new version fails, the system automatically restores the previous version, ensuring you never end up without a functional installation.

### Can I have multiple versions of Cursor installed?

Yes! The script supports parallel installations. You can choose the "S - Substitute" option to keep existing versions and add a new installation.

### What to do if download fails repeatedly?

The script automatically tries 3 times with a 30-second timeout. If it continues to fail:

1. Check your internet connection
2. Test connectivity: `ping 8.8.8.8`
3. Check if there's a firewall blocking the download
4. Try running the script again

### How to choose between sandbox and no-sandbox mode?

During installation, the script will ask about sandbox mode:

- **Sandbox (recommended)**: Higher security, resource isolation
- **No-sandbox**: Better performance, direct system access

### Where are the logs stored?

Logs are saved in `~/.cursor_log` and include:

- Timestamp of each operation
- Download status
- Errors and warnings
- Debug information

### How to update manually?

```bash
# Check existing installations
./cursor-ai.sh --install

# Choose "U - Update" option when prompted
```

### Is it safe to use this script?

Yes! The script implements several security measures:

- Download integrity verification
- Automatic backup before changes
- Permission validation
- Detailed logs for auditing

### Compatibility with different Linux distributions

The script is compatible with all modern Linux distributions that support:

- Bash 4.0+
- curl
- gtk-update-icon-cache
- update-desktop-database

Tested on: Ubuntu, Debian, Fedora, Arch Linux, openSUSE.

## Advanced Examples

### Automation with Scripts

#### Silent Installation

```bash
#!/bin/bash
# Automatic installation without interaction
echo "s" | ./cursor-ai.sh --install
```

#### Automatic Update Script

```bash
#!/bin/bash
# Check and update Cursor automatically
if [ -f ~/Applications/cursor.AppImage ]; then
    echo "Updating Cursor..."
    ./cursor-ai.sh --install
fi
```

### CI/CD Integration

#### GitHub Actions

```yaml
name: Install Cursor
on: [push, pull_request]
jobs:
  install-cursor:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Install Cursor
        run: |
          chmod +x cursor-ai.sh
          ./cursor-ai.sh --install
```

### Installation on Multiple Machines

#### Deploy Script

```bash
#!/bin/bash
# Deploy to multiple machines via SSH
for host in server1 server2 server3; do
    scp cursor-ai.sh user@$host:/tmp/
    ssh user@$host "chmod +x /tmp/cursor-ai.sh && /tmp/cursor-ai.sh --install"
done
```

### Directory Customization

#### Installation in Custom Directory

```bash
# During installation, when prompted:
# Enter the desired directory (e.g., /opt/cursor)
```

### Corporate Environment Usage

#### Installation with Proxy

```bash
# Configure proxy before execution
export http_proxy=http://proxy.company.com:8080
export https_proxy=http://proxy.company.com:8080
./cursor-ai.sh --install
```

## Contributing

### How to Contribute

1. **Fork** the repository
2. **Clone** your fork locally
3. **Create** a branch for your feature: `git checkout -b feature/new-functionality`
4. **Commit** your changes: `git commit -m 'Add new functionality'`
5. **Push** to your branch: `git push origin feature/new-functionality`
6. **Open** a Pull Request

### Guidelines for Contributors

- Keep code clean and documented
- Follow existing naming conventions
- Test your changes on different Linux distributions
- Add tests when appropriate
- Document new features in the README

### How to Report Bugs

When reporting bugs, include:

- Linux distribution and version
- Script version
- Complete logs (`~/.cursor_log`)
- Steps to reproduce the problem
- Expected vs. actual behavior

### Code Structure

```
cursor-ai.sh
├── Global settings
├── Utility functions
├── System checks
├── Download and installation
├── Installation management
└── Main function
```

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Cursor IDE Community
- Project contributors
- Users who provide valuable feedback

---

**Developed with ❤️ by evandrodevbr**
