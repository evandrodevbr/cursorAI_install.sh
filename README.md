# Cursor IDE Installer for Linux

**Interactive Bash script that installs, repairs and removes the [Cursor IDE](https://www.cursor.com/) on Linux**, choosing between AppImage, DEB and RPM according to the detected distribution and CPU architecture.

![Bash](https://img.shields.io/badge/bash-4.0%2B-4EAA25?logo=gnu-bash&logoColor=white)
![Platform](https://img.shields.io/badge/platform-Linux-FCC624?logo=linux&logoColor=black)
![License](https://img.shields.io/badge/license-MIT-green)

## About

Installing Cursor on Linux means picking the right artifact for your distribution and architecture, wiring up a desktop entry and a launcher, and then remembering where all those files went when you want to upgrade or remove the app. `cursor-ai.sh` handles that lifecycle:

- detects the distribution through `/etc/os-release` and the architecture through `uname -m`, and recommends the matching package format;
- resolves the current download URL from Cursor's update API (the AppImage, DEB and RPM builds of the same release), so the script never hardcodes a version;
- installs a user-level AppImage without root privileges and integrates it with your desktop, or downloads a DEB/RPM and hands it to your native package manager;
- repairs a broken AppImage setup (missing icon, desktop entry or launcher) and removes the installation afterwards.

It runs as a normal user. Root is only requested, through `sudo`, when you pick a DEB or RPM package.

## How it works

```text
./cursor-ai.sh --install
        |
        |-- detect_distribution()          /etc/os-release + uname -m  ->  deb | rpm | appimage
        |-- check_disk_space()              df -kP                       (500 MB free)
        |-- check_internet_connection()     curl HEAD to the update API
        |-- check_existing_installation()   known install paths, then a prompt
        |-- list_available_packages()       HEAD on api2.cursor.sh -> version + size of each build
        |-- select_package_format()         prompt (default = the recommendation for your distro)
        |
        `-- install_appimage() / install_deb() / install_rpm()
                    |                             |
                    |                             `-- sudo apt-get / dpkg / dnf / yum / zypper / rpm
                    `-- ~/Applications/cursor.AppImage
                        ~/.local/bin/cursor                  (launcher)
                        ~/.local/share/applications/cursor.desktop
                        ~/.local/share/icons/cursor-icon.svg
```

The download URL is resolved with a lightweight `curl -I` against `https://api2.cursor.sh/updates/download/golden/linux-<arch>-<format>/cursor/`, which answers with a redirect to the real artifact. The script follows it and only then downloads the file.

## Stack

| Layer | Choice |
|---|---|
| Language | Bash 4+ (single script, `set -euo pipefail`) |
| HTTP | `curl` (URL resolution, downloads, connectivity check) |
| Package sources | Cursor update API (`api2.cursor.sh`) |
| Install methods | AppImage (user level), DEB (`apt-get`/`dpkg`), RPM (`dnf`/`yum`/`zypper`/`rpm`) |
| Desktop integration | `.desktop` entry, SVG icon, launcher in `~/.local/bin` |
| License | MIT |

## Requirements

- Linux with Bash 4.0 or newer.
- `curl` installed (every network call goes through it).
- An interactive terminal: all questions are read from `/dev/tty`, so the script cannot be driven from a pipe or from CI.
- About 500 MB of free space in the target directory (`~/Applications`, or `$HOME` while it does not exist).
- `sudo` available and working, only if you choose the DEB or RPM format.
- Optional, used when present: `update-desktop-database`, `gtk-update-icon-cache`, `fusermount`/`fusermount3` (missing FUSE produces a warning, since AppImages need it).

## Quick start

```bash
git clone https://github.com/evandrodevbr/cursorAI_install.sh.git
cd cursorAI_install.sh
chmod +x cursor-ai.sh

./cursor-ai.sh --install
```

Run it as your normal user, never with `sudo`: the script refuses to run inside a sudo session on purpose, and asks for the password itself when a native package needs root.

The interactive install asks three questions:

| Prompt | Default | Notes |
|---|---|---|
| Package format (1-3) | the format recommended for your distribution | `1` AppImage, `2` DEB, `3` RPM |
| Application installation directory | `~/Applications` | only asked for AppImage (the answer is kept verbatim) |
| Run Cursor with sandbox? (y/n) | `y` | answering `n` writes `--no-sandbox` into the launcher |

When it finishes, the script prints the installed Cursor version, the installer version, and warns if `~/.local/bin` is not in your `PATH`.

## Usage

```bash
./cursor-ai.sh --install      # install (this is also the default when no argument is given)
./cursor-ai.sh --repair       # recreate missing AppImage files (binary, icon, .desktop, launcher)
./cursor-ai.sh --uninstall    # remove the installation, asking for confirmation first
./cursor-ai.sh --help         # list the flags and the supported distributions
```

Short flags `-i`, `-r`, `-u` and `-h` are accepted as well. An unknown flag prints the help and exits with status 1.

### What an AppImage install creates

| Path | Content |
|---|---|
| `~/Applications/cursor.AppImage` | the downloaded, executable AppImage |
| `~/.local/bin/cursor` | launcher that forwards arguments and appends its output to the log |
| `~/.local/share/applications/cursor.desktop` | desktop entry (menu entry, `cursor://` MIME handler) |
| `~/.local/share/icons/cursor-icon.svg` | icon fetched from cursor.com |
| `~/.cursor_log` | launcher log (timestamped start line plus the app output) |

### Existing installations

When an installation is already present, the script lists every path it knows about (`~/Applications/cursor.AppImage`, `~/applications/cursor.AppImage`, `~/.local/bin/cursor`, `/usr/local/bin/cursor`, `/usr/bin/cursor`, `/opt/cursor/cursor.AppImage`) and offers to update it, remove one, remove all, keep it, or cancel:

- **Update** works for AppImage installs only: it renames the current file to `.backup`, downloads the newest release, and restores the backup if the new file looks corrupted.
- **Remove** deletes the selected path, and for an AppImage also the icon, desktop entry, launcher and log.
- DEB and RPM are removed through the native package manager instead.

`--repair` checks the four AppImage files, downloads or recreates whatever is missing, and reports `All files are intact, no repair needed.` when there is nothing to do. With a native package installed it offers to reinstall through the normal format selection.

## Deploy

There is nothing to build: the script is the artifact. On another machine, copy the single file and run it as the user who will use Cursor:

```bash
scp cursor-ai.sh user@host:~/
ssh -t user@host 'chmod +x ~/cursor-ai.sh && ~/cursor-ai.sh --install'
```

It writes only inside `$HOME` for AppImage installs; the DEB/RPM paths are the only ones that escalate with `sudo`.

## Project structure

```text
.
├── cursor-ai.sh   the whole installer: detection, download, install, repair, uninstall
├── README.md
└── LICENSE        MIT
```

`cursor-ai.sh` is a single file; the main entry points are `detect_distribution`, `list_available_packages`, `install_appimage` / `install_deb` / `install_rpm`, `repair_installation`, `update_cursor_appimage` and `uninstall_cursor`, with helpers such as `ask`, `download_with_progress` and `log`.

## Verification

This repository has **no automated test suite and no CI**.

| Check | Result |
|---|---|
| `bash -n cursor-ai.sh` | exit 0, no syntax errors |
| `shellcheck` 0.10.0 | 0 errors (8 style warnings SC2155, 2 notes) |
| `./cursor-ai.sh --help` | exit 0, prints the flag reference |
| `./cursor-ai.sh --bogus` | exit 1, `Unknown option` |
| Full AppImage install into a throwaway `$HOME` | exit 0, the four files created, version resolved as Cursor 3.20.17 |
| Installed launcher run with `--appimage-version` | AppImage runtime answered; the log file received both the timestamp line and the app output |
| `--repair` with everything in place | `All files are intact, no repair needed.` (exit 0) |
| `--repair` after deleting the icon and the desktop entry | both recreated, exit 0 |
| `--uninstall` | every installed file removed, exit 0 |

To repeat the smoke test:

```bash
bash -n cursor-ai.sh
./cursor-ai.sh --help
FAKE_HOME=$(mktemp -d)
HOME="$FAKE_HOME" ./cursor-ai.sh --install   # then inspect $FAKE_HOME and remove it
```

## Current state and limitations

- No automated tests and no CI. Regressions can only be caught by hand.
- Interactive only: every question is read from `/dev/tty`, so the script cannot run unattended (a run without a terminal dies at the first prompt).
- The DEB and RPM paths were not exercised in the last review, because the audit machine is Arch based and has no `apt`, `dnf`, `yum`, `zypper` or `rpm`. Only their download URL resolution was verified. On Arch, `dpkg` can exist without `apt`, in which case a DEB install falls back to `dpkg -i` with no dependency resolution.
- A requested `armv7l` build is answered by Cursor's API with the `aarch64` AppImage, so the 32-bit ARM branch effectively installs an incompatible binary. x64 and arm64 resolve to the matching builds.
- There is no checksum or signature verification: the script trusts the HTTPS download and only checks that the file is non-empty and executable.
- `--uninstall` and `--repair` only look at the known paths listed above. If you answer a custom directory at the install prompt, the AppImage will live outside that list and the removal step will not find it.
- Updates are AppImage-only; DEB and RPM are updated by installing the new package over the old one.
- The root guard blocks `sudo ./cursor-ai.sh` (it detects `EUID 0` with `SUDO_USER` set). Running the script directly as root is not blocked and would create the integration files under `/root`.
- The version shown during installation comes from the download URL, so the script always installs the current release and cannot pin an older one.

## Documentation

There is no `docs/` directory. This README and the header comments inside `cursor-ai.sh` are the documentation; `./cursor-ai.sh --help` is the command line reference.

## License

MIT. See [`LICENSE`](LICENSE).
