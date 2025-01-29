# 🚀 Cursor IDE - Smart Installation Script

An elegant and robust bash script for managing Cursor IDE on Linux, providing a smooth and interactive installation experience.

## ✨ Features

- 🎯 Smart and interactive installation
- 🔄 Automatic backup update system
- 🧹 Safe and complete uninstallation
- 🛠️ Repair and maintenance tools
- 📊 Visual progress bar
- 🎨 User-friendly colored interface
- 🔒 Backup and recovery system

## 📋 Prerequisites

- Linux operating system
- Bash 4.0 or higher
- Internet connection
- 500MB free disk space
- Appropriate user permissions

## 🚀 Quick Start

### Basic Installation

```bash
./cursor-ai.sh --install
```

### Other Options

```bash
./cursor-ai.sh --help      # Show help
./cursor-ai.sh --repair    # Repair installation
./cursor-ai.sh --uninstall # Uninstall Cursor
```

## 🎯 Detailed Features

### 1. Smart Installation
- Checks for existing installations
- Detects available disk space
- Tests internet connection
- Creates necessary directory structure
- Configures shortcuts and system integrations

### 2. Existing Installation Management
When finding existing installations, offers the following options:

- **U - Update**: Updates an existing installation
  - Creates automatic backup
  - Downloads new version
  - Rollback system in case of failure
  
- **R - Remove**: Removes a specific installation
  - Removes all associated files
  - Cleans system entries
  - Updates system cache
  
- **A - Remove All**: Removes all found installations
  - Complete system cleanup
  - Removal of all versions
  
- **S - Substitute**: Keeps existing installations and adds new one
  - Parallel installation
  - Keeps previous versions

### 3. Update System
- Progress bar download
- Integrity verification
- Automatic backup of current version
- Automatic restoration in case of failure
- Post-download validation

### 4. Security Features
- Dependency checking
- Download validation
- Backup and restore system
- Error handling
- Detailed logging

### 5. User-Friendly Interface
- 🎨 Colored output
- ⏳ Progress bars
- ✅ Success/failure indicators
- 📝 Informative logs
- 🔄 Real-time status

## 🛠️ Command Line Options

| Option | Description |
|--------|-------------|
| `-i, --install` | Install Cursor IDE |
| `-u, --uninstall` | Remove Cursor IDE |
| `-r, --repair` | Repair installation |
| `-h, --help` | Show help message |

## 📝 Logs and Diagnostics

The script maintains detailed logs in:
- \`~/.cursor_log\` for execution logs
- Colored messages in terminal
- Real-time progress information

## 🔧 Troubleshooting

### Insufficient Space
```bash
# Check available space
df -h
```

### Update Failure
- Script maintains automatic backup
- Automatic restoration on failure
- Detailed diagnostic logs

### Permission Issues
```bash
# Check permissions
ls -l ~/.local/bin/cursor
```

## 🤝 Contributing

Feel free to:
1. Open issues
2. Submit pull requests
3. Suggest improvements
4. Report bugs

## 📜 License

This script is distributed under the MIT license.

## ✨ Acknowledgments

- Cursor IDE Community
- Project contributors
- Users providing feedback

## 🔍 Advanced Usage

### Custom Installation Directory
You can specify a custom installation directory:
```bash
./cursor-ai.sh --install
# Then follow the prompts to set custom directory
```

### Multiple Installations
The script can handle multiple installations:
- Different versions
- Different locations
- Different configurations

### Sandbox Mode
Choose between:
- Sandboxed mode for enhanced security
- No-sandbox mode for better performance

### Update Management
- Selective updates
- Version control
- Backup management

## 🛡️ Security Features

1. **Download Security**
   - Integrity checks
   - Secure connections
   - Validation of binaries

2. **System Protection**
   - Safe file operations
   - Permission management
   - Error prevention

3. **Data Safety**
   - Automatic backups
   - Safe updates
   - Rollback capability

## 📚 Technical Details

### Directory Structure
```
${HOME}/
├── Applications/
│   └── cursor.AppImage
├── .local/
│   ├── bin/
│   │   └── cursor
│   └── share/
│       ├── applications/
│       │   └── cursor.desktop
│       └── icons/
│           └── cursor-icon.svg
└── .cursor_log
```

### System Requirements
- **CPU**: Any modern processor
- **RAM**: Minimal usage
- **Disk**: 500MB free space
- **Network**: Active internet connection

### Dependencies
- curl
- gtk-update-icon-cache
- update-desktop-database

---
Made with ❤️ by Truuta 
