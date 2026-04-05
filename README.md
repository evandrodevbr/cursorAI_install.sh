# Cursor IDE - Smart Linux Installer

[![Version](https://img.shields.io/badge/version-1.0.0-blue.svg)](https://github.com/evandrodevbr/cursorAI_install.sh)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-Linux-lightgrey.svg)](https://www.linux.org/)
[![Bash](https://img.shields.io/badge/language-Bash_4.0+-4EAA25?logo=gnu-bash&logoColor=white)]()

A robust, enterprise-grade bash script designed to manage the entire lifecycle of the [Cursor IDE](https://www.cursor.com/) on Linux systems. It provides intelligent environment detection, native package management, automated desktop integration, and bulletproof safety mechanisms.

## Key Features

- **Smart OS & Architecture Detection:** Automatically routes to `.deb` for Debian/Ubuntu, `.rpm` for Fedora/SUSE, and `.AppImage` for Arch/Others (supports x64, arm64, armv7l).
- **Native Package Integration:** Interfaces directly with `apt`, `dnf`, `zypper`, `rpm`, and `dpkg` for clean, native installations and removals.
- **Fail-Safe Upgrades:** Implements automated backups before updating, with an instant rollback mechanism if the new binary is corrupted.
- **Ghost-Free Uninstallation:** Systematically tracks and purges all traces of the IDE, including native database registries (`dpkg -l`, `rpm -q`) and local `.desktop`/icon assets.
- **Bandwidth-Optimized Validation:** Resolves dynamic download URLs using lightweight HTTP `HEAD` requests (`curl -I`), saving hundreds of megabytes per run.
- **Enterprise Security Standards:**
  - Prevents accidental execution as `root` (prevents `sudo` hijacking of user directories).
  - Uses `mktemp -d` to prevent Symlink/Temp File Hijacking attacks.
  - Enforces `set -euo pipefail` for strict error trapping.

---

## Tech Stack

- **Language:** Bash (Strict POSIX compliant where applicable, requires 4.0+)
- **Core Utilities:** `curl`, `awk`, `grep`, `df`, `mktemp`
- **Package Managers Supported:** `apt`, `dpkg`, `dnf`, `yum`, `zypper`, `rpm`
- **Desktop Integration:** `update-desktop-database`, `gtk-update-icon-cache`, `fusermount`

---

## Prerequisites

- Any modern Linux distribution.
- Bash 4.0 or higher.
- `curl` installed.
- 500MB of free disk space in the target directory (usually `~` or `~/Applications`).
- Standard user account (the script will elevate privileges via `sudo` automatically *only* when strictly necessary for native packages).

---

## Getting Started

### 1. Download the Installer

Clone the repository and make the script executable:

```bash
git clone https://github.com/evandrodevbr/cursorAI_install.sh.git
cd cursorAI_install.sh
chmod +x cursor-ai.sh
```

### 2. Run the Interactive Installer

Execute the script **without** sudo. The script will analyze your system and recommend the best installation path:

```bash
./cursor-ai.sh --install
```

### 3. Alternative Commands

The script provides a clean CLI interface for lifecycle management:

```bash
# Repair a broken installation (missing icons, deleted binaries, broken symlinks)
./cursor-ai.sh --repair

# Safely purge Cursor IDE from the system
./cursor-ai.sh --uninstall

# Show available commands
./cursor-ai.sh --help
```

---

## Architecture Overview

### Execution Flow

1. **Initialization & Safety Gates:** 
   Enforces `set -euo pipefail`, checks `$EUID` to block raw `root` execution, and traps signals (`EXIT INT TERM HUP`) to ensure secure temporary directory cleanup.
2. **Telemetry & Validation:** 
   Detects OS distribution, architecture, and network connectivity. Calculates exact disk space dynamically using `df -kP`.
3. **Package Resolution:** 
   Probes the Cursor update API via `curl -I` to fetch the latest download URLs for AppImage, DEB, and RPM formats.
4. **User Interaction:** 
   Displays available packages and prompts the user for their preferred format, defaulting to the native recommendation.
5. **Execution:** 
   - **AppImage:** Validates FUSE availability, downloads the binary, fetches the SVG logo, and writes `.desktop` and `wrapper` scripts.
   - **DEB/RPM:** Downloads the package and safely escalates privileges (`sudo apt-get install -y` or `sudo dnf install -y`) to handle dependency graphs without breaking the host OS.
6. **Validation:** 
   Checks executable permissions, file integrity, and `$PATH` visibility.

### Directory Structure (AppImage / Local Install)

```text
${HOME}/
├── Applications/
│   └── cursor.AppImage          # Immutable binary (if AppImage selected)
├── .local/
│   ├── bin/
│   │   └── cursor               # Sandbox-aware wrapper script
│   └── share/
│       ├── applications/
│       │   └── cursor.desktop   # System menu entry
│       └── icons/
│           └── cursor-icon.svg  # Extracted vector logo
└── .cursor_log                  # Persistent execution log
```

---

## Environment Variables

While the script runs interactively by default, it relies on and safely parses standard Linux environment variables:

| Variable           | Description                                                                 |
| ------------------ | --------------------------------------------------------------------------- |
| `HOME`             | Target path for `.local` integrations and AppImage binaries.                |
| `EUID`             | Used to prevent the script from running directly as root.                   |
| `SUDO_USER`        | Validated alongside `EUID` to prevent sudo context hijacking.               |
| `PATH`             | Scanned post-installation to warn the user if `~/.local/bin` is not active. |

---

## Troubleshooting

### "FUSE is not installed" (AppImage)

Modern distributions like Ubuntu 22.04+ dropped `libfuse2` by default. If you choose the AppImage format:
```bash
# Ubuntu/Debian
sudo apt-get install libfuse2

# Fedora
sudo dnf install fuse
```

### Installation Verification Failed

If the script fails at the validation step, it means the binary was downloaded but lacks execution permissions, or a native package failed to link in `/usr/bin/cursor`.
**Solution:** Run the built-in repair tool:
```bash
./cursor-ai.sh --repair
```

### "Permission Denied" during Cleanup

The script uses `mktemp -d` to sandbox downloads. If interrupted abruptly (e.g., `SIGKILL`), the OS might lock the temp folder. 
**Solution:** The script handles standard interruptions (`Ctrl+C`), but in severe cases, manually clear `/tmp/cursor_installer.*`.

---

## Contributing

We welcome contributions to make this installer even more robust!

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feat/AmazingFeature`)
3. Commit your Changes (`git commit -m 'feat: Add some AmazingFeature'`)
4. Push to the Branch (`git push origin feat/AmazingFeature`)
5. Open a Pull Request

### Bash Guidelines
- Always use `[[ ]]` over `[ ]`.
- Maintain POSIX compliance in core utilities (e.g., `df -P`).
- Prefix private variables with `local`.
- Ensure new features are tested against ShellCheck.

---

## License

Distributed under the MIT License. See `LICENSE` for more information.

---
