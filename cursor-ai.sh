#!/bin/bash

# ====================================================================================
# Cursor IDE Installation, Uninstallation and Maintenance Script
# 
# This script manages the complete lifecycle of Cursor IDE on Linux, including:
# - Installation with dependency checking
# - Safe uninstallation,
# - Repair of corrupted installations
# - Multiple installation management
# 
# Author: evandrodevbr
# Version: 1.0.0
# ====================================================================================

set -euo pipefail

# Global settings and constants
readonly VERSION="1.0.0"
readonly TEMP_DIR="/tmp/cursor_installer"
readonly MAX_RETRIES=3
readonly TIMEOUT=30

# Directory setup
APP_DIR="${HOME}/Applications"
ICON_DIR="${HOME}/.local/share/icons"
DESKTOP_DIR="${HOME}/.local/share/applications"
BIN_DIR="${HOME}/.local/bin"

# File paths
ICON_DOWNLOAD_URL="https://www.cursor.com/assets/images/logo.svg"
APPIMAGE_NAME="cursor.AppImage"
APPIMAGE_PATH="${APP_DIR}/${APPIMAGE_NAME}"
ICON_PATH="${ICON_DIR}/cursor-icon.svg"
DESKTOP_FILE_PATH="${DESKTOP_DIR}/cursor.desktop"
LAUNCHER_SCRIPT="${BIN_DIR}/cursor"

# Function to clean temporary files
cleanup() {
    local exit_code=$?
    log "Cleaning up temporary files..."
    rm -rf "${TEMP_DIR}" 2>/dev/null || true
    exit $exit_code
}

# Register cleanup function
trap cleanup EXIT

# Enhanced utility functions
log() {
    local level="INFO"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    if [[ $# -gt 1 ]]; then
        level=$1
        shift
    fi
    printf "[%s] [%s] %s\n" "$timestamp" "$level" "$*"
}

error() {
    log "ERROR" "$*" >&2
    exit 1
}

# Enhanced function to ask user with validation
ask() {
    local question=$1
    local default=${2:-""}
    local valid_options=${3:-""}
    local answer
    
    while true; do
        printf "%s" "$question" >&2
        if [[ -n $default ]]; then
            printf " (default: %s)" "$default" >&2
        fi
        printf ": " >&2
        read -r answer </dev/tty
        answer=${answer:-$default}
        answer=$(echo "$answer" | tr '[:upper:]' '[:lower:]')
        
        # If no specific validation, accept any input
        if [[ -z "$valid_options" ]]; then
            echo "$answer"
            return 0
        fi
        
        # Validate against provided options
        if [[ "$valid_options" =~ $answer ]]; then
            echo "$answer"
            return 0
        else
            log "ERROR" "Invalid option. Valid options are: $valid_options" >&2
            continue
        fi
    done
}

# Function for showing progress bar
show_progress() {
    local current=$1
    local total=$2
    local width=50
    local percentage=$((current * 100 / total))
    local filled=$((width * current / total))
    local empty=$((width - filled))
    
    printf "\r["
    printf "%${filled}s" '' | tr ' ' '='
    printf "%${empty}s" '' | tr ' ' ' '
    printf "] %3d%%" "$percentage"
    
    if [ "$current" -eq "$total" ]; then
        printf "\n"
    fi
}

# Enhanced function for download with progress and retry
download_with_progress() {
    local url=$1
    local output=$2
    local description=$3
    local retries=0
    local temp_file="${TEMP_DIR}/$(basename "$output")"
    
    mkdir -p "${TEMP_DIR}"
    
    while [ $retries -lt $MAX_RETRIES ]; do
        log "INFO" "Downloading $description (attempt $((retries + 1))/$MAX_RETRIES)..."

        if curl -L --progress-bar --connect-timeout $TIMEOUT "$url" -o "$temp_file"; then
            if [[ -s "$temp_file" ]]; then
                mv "$temp_file" "$output"
                log "SUCCESS" "Download completed successfully!"
                return 0
            else
                log "ERROR" "Downloaded file is empty or corrupted."
            fi
        else
            log "ERROR" "Download failed with curl."
        fi
        
        retries=$((retries + 1))
        if [ $retries -lt $MAX_RETRIES ]; then
            local wait_time=$((retries * 5))
            log "WARNING" "Download failed. Retrying in $wait_time seconds..."
            sleep $wait_time
        fi
    done

    log "ERROR" "Failed to download $description after $MAX_RETRIES attempts."
    return 1
}

# Function to check disk space
check_disk_space() {
    local required_space=$((500 * 1024)) # 500MB in KB
    local available_space
    
    available_space=$(df -k "${APP_DIR}" | awk 'NR==2 {print $4}')
    
    if [[ $available_space -lt $required_space ]]; then
        error "Insufficient disk space. Required: 500MB, Available: $((available_space / 1024))MB"
    fi
}

# Function to detect Linux distribution and architecture
detect_distribution() {
    local distro=""
    local arch=""
    local recommended_format=""
    
    # Detect architecture
    arch=$(uname -m)
    case "$arch" in
        x86_64) arch="x64" ;;
        aarch64) arch="arm64" ;;
        armv7l) arch="armv7l" ;;
        *) arch="x64" ;; # fallback
    esac
    
    # Detect distribution
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        case "$ID" in
            ubuntu|debian|linuxmint|pop|elementary)
                distro="Ubuntu/Debian"
                recommended_format="deb"
                ;;
            fedora|rhel|centos|rocky|almalinux)
                distro="Red Hat/Fedora"
                recommended_format="rpm"
                ;;
            opensuse*|sles)
                distro="openSUSE"
                recommended_format="rpm"
                ;;
            arch|manjaro|endeavouros)
                distro="Arch"
                recommended_format="appimage"
                ;;
            *)
                distro="Other"
                recommended_format="appimage"
                ;;
        esac
    else
        distro="Unknown"
        recommended_format="appimage"
    fi
    
    # Export for use in other functions
    export DETECTED_DISTRO="$distro"
    export DETECTED_ARCH="$arch"
    export RECOMMENDED_FORMAT="$recommended_format"
    
    log "INFO" "Detected distribution: $distro"
    log "INFO" "Detected architecture: $arch"
    log "INFO" "Recommended format: $recommended_format"
}

# Function to check package manager availability
check_package_manager() {
    local format=$1
    local has_manager=false
    
    case "$format" in
        "deb")
            if command -v dpkg >/dev/null 2>&1; then
                has_manager=true
                log "SUCCESS" "✓ dpkg available"
            fi
            if command -v apt >/dev/null 2>&1 || command -v apt-get >/dev/null 2>&1; then
                log "SUCCESS" "✓ apt available"
            fi
            ;;
        "rpm")
            if command -v rpm >/dev/null 2>&1; then
                has_manager=true
                log "SUCCESS" "✓ rpm available"
            fi
            if command -v dnf >/dev/null 2>&1 || command -v yum >/dev/null 2>&1 || command -v zypper >/dev/null 2>&1; then
                log "SUCCESS" "✓ RPM package manager available"
            fi
            ;;
        "appimage")
            has_manager=true
            log "SUCCESS" "✓ AppImage does not require package manager"
            ;;
    esac
    
    if [[ "$has_manager" = false ]]; then
        log "WARNING" "Package manager for $format not found"
        return 1
    fi
    
    return 0
}

# Function to get download URL for specific format and architecture
get_download_url() {
    local format=$1
    local arch=$2
    local api_url="https://api2.cursor.sh/updates/download/golden/linux-${arch}-${format}/cursor/"
    local final_url=""
    
    log "INFO" "Getting download URL for $format ($arch)..." >&2
    
    # Get the redirect URL
    final_url=$(curl -sI "$api_url" 2>/dev/null | grep -i "location:" | cut -d' ' -f2 | tr -d '\r\n')
    
    if [[ -n "$final_url" ]]; then
        log "SUCCESS" "URL obtained: $final_url" >&2
        echo "$final_url"
    else
        log "ERROR" "Failed to get download URL" >&2
        return 1
    fi
}

# Function to list available packages
list_available_packages() {
    local arch="$DETECTED_ARCH"
    local packages=()
    local formats=("appimage" "deb" "rpm")
    
    log "INFO" "Fetching available packages for architecture $arch..."
    
    # First, collect all data
    log "INFO" "Collecting package information..."
    for format in "${formats[@]}"; do
        log "INFO" "Checking $format package availability..."
        local url
        local version=""
        local size=""
        
        url=$(get_download_url "$format" "$arch")
        if [[ -n "$url" ]]; then
            # Extract version from filename
            version=$(echo "$url" | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+' | head -1)
            
            # Get file size
            log "INFO" "Getting file size for $format package..."
            size=$(curl -sI "$url" 2>/dev/null | grep -i "content-length" | cut -d' ' -f2 | tr -d '\r\n')
            if [[ -n "$size" ]]; then
                size=$((size / 1024 / 1024))
                size="${size}MB"
            else
                size="N/A"
            fi
            
            packages+=("$format|$version|$size|$url")
            log "SUCCESS" "✓ $format package available (v$version, $size)"
        else
            packages+=("$format|N/A|N/A|")
            log "WARNING" "✗ $format package not available"
        fi
    done
    
    # Now display the formatted table
    log "INFO" "Displaying available packages..."
    echo ""
    echo "┌─────────────────────────────────────────────────────────────┐"
    echo "│                    AVAILABLE PACKAGES                       │"
    echo "├─────────────────────────────────────────────────────────────┤"
    echo "│ Architecture: $arch"
    echo "│"
    
    for package in "${packages[@]}"; do
        IFS='|' read -r format version size url <<< "$package"
        if [[ -n "$url" ]]; then
            printf "│ %-10s │ v%-8s │ %-8s │ Available ✓\n" "$format" "$version" "$size"
        else
            printf "│ %-10s │ %-8s │ %-8s │ Unavailable ✗\n" "$format" "N/A" "N/A"
        fi
    done
    
    echo "└─────────────────────────────────────────────────────────────┘"
    echo ""
    
    # Export packages for selection
    export AVAILABLE_PACKAGES=("${packages[@]}")
}

# Function to check internet connection
check_internet_connection() {
    if ! ping -c 1 8.8.8.8 &>/dev/null; then
        error "No internet connection. Please check your connection and try again."
    fi
}

# Function to remove a specific installation
remove_specific_installation() {
    local install_path=$1
    local success=true
    
    log "INFO" "Removing installation: $install_path"
    
    # Remove the main file
    if [[ -f "$install_path" ]]; then
        if rm -f "$install_path"; then
            log "SUCCESS" "✓ Removed: $install_path"
        else
            log "ERROR" "✗ Failed to remove: $install_path"
            success=false
        fi
    fi
    
    # Remove associated files if it's a complete installation
    if [[ "$install_path" == *"cursor.AppImage" ]]; then
        local associated_files=(
            "${install_path%/*}/cursor-icon.svg"
            "${HOME}/.local/share/applications/cursor.desktop"
            "${HOME}/.local/bin/cursor"
            "${HOME}/.cursor_log"
        )
        
        for file in "${associated_files[@]}"; do
            if [[ -f "$file" ]]; then
                if rm -f "$file"; then
                    log "SUCCESS" "✓ Removed associated file: $file"
                else
                    log "ERROR" "✗ Failed to remove associated file: $file"
                    success=false
                fi
            fi
        done
        
        # Update system cache
        update-desktop-database "${DESKTOP_DIR}" 2>/dev/null || true
        gtk-update-icon-cache -f -t ~/.local/share/icons 2>/dev/null || true
    fi
    
    if [[ "$success" = true ]]; then
        log "SUCCESS" "✨ Installation removed successfully! ✨"
    else
        log "WARNING" "Removal completed with some errors. Please check above messages."
    fi
    
    return $success
}

# Function to update the Cursor AppImage
update_cursor_appimage() {
    local install_path=$1
    local success=true
    local backup_path="${install_path}.backup"
    
    log "INFO" "Starting Cursor update..."
    
    # Create backup of current AppImage
    if [[ -f "$install_path" ]]; then
        log "INFO" "Creating backup of current version..."
        if mv "$install_path" "$backup_path"; then
            log "SUCCESS" "✓ Backup created: $backup_path"
        else
            log "ERROR" "✗ Failed to create backup"
            return 1
        fi
    fi
    
    # Download new version
    log "INFO" "Downloading new Cursor version..."
    if download_with_progress "${DOWNLOAD_URL}" "$install_path" "new Cursor version"; then
        chmod +x "$install_path"
        log "SUCCESS" "✓ New version downloaded and configured"
        
        # Test if the new file is valid
        if [[ -x "$install_path" ]] && [[ -s "$install_path" ]]; then
            log "SUCCESS" "✨ Update completed successfully! ✨"
            rm -f "$backup_path"  # Remove backup if everything went well
            return 0
        else
            log "ERROR" "New version seems corrupted"
            success=false
        fi
    else
        log "ERROR" "Failed to download new version"
        success=false
    fi
    
    # Restore backup in case of failure
    if [[ "$success" = false ]] && [[ -f "$backup_path" ]]; then
        log "WARNING" "Restoring previous version..."
        if mv "$backup_path" "$install_path"; then
            log "SUCCESS" "✓ Previous version restored"
        else
            log "ERROR" "✗ Failed to restore previous version"
        fi
        return 1
    fi
}

# Function to check existing installation
check_existing_installation() {
    local possible_paths=(
        "${HOME}/Applications/cursor.AppImage"
        "${HOME}/.local/bin/cursor"
        "/usr/local/bin/cursor"
        "/opt/cursor/cursor.AppImage"
    )
    
    local found=false
    local installations=()
    local valid_paths=()
    
    log "INFO" "Checking existing Cursor installations..."
    
    # Find all existing installations
    for path in "${possible_paths[@]}"; do
        if [[ -f "$path" ]]; then
            found=true
            installations+=("$path")
            valid_paths+=("$path")
        fi
    done
    
    if [[ "$found" = true ]]; then
        local num_installations=${#installations[@]}
        
        log "WARNING" "Existing Cursor installations found:"
        for ((i=0; i<num_installations; i++)); do
            log "WARNING" "  $((i+1)). ${installations[$i]}"
        done
        
        # Show options to user
        cat << EOF

Available options:
[U] - Update existing installation
[R] - Remove specific installation
[A] - Remove all installations
[S] - Replace keeping existing
[C] - Cancel installation

EOF
        
        local action=$(ask "Enter your choice" "c" "urascdURASDC")
        case "$action" in
            u)
                if [[ $num_installations -gt 1 ]]; then
                    while true; do
                        log "INFO" "Enter the number of the installation you want to update (1-$num_installations):"
                        local choice
                        read -r choice
                        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "$num_installations" ]; then
                            local target_path="${installations[$((choice-1))]}"
                            if [[ "$target_path" == *"cursor.AppImage" ]]; then
                                if update_cursor_appimage "$target_path"; then
                                    log "INFO" "Update completed. No need to continue with installation."
                                    exit 0
                                else
                                    error "Update failed. Please try again or choose another option."
                                fi
                            else
                                log "ERROR" "Only AppImage installations can be updated."
                                local try_again=$(ask "Do you want to choose another installation? (y/n)" "y" "ynYN")
                                if [[ "${try_again,,}" != "y" ]]; then
                                    break
                                fi
                            fi
                        else
                            log "ERROR" "Invalid choice. Please enter a number between 1 and $num_installations."
                        fi
                    done
                else
                    if [[ "${installations[0]}" == *"cursor.AppImage" ]]; then
                        if update_cursor_appimage "${installations[0]}"; then
                            log "INFO" "Update completed. No need to continue with installation."
                            exit 0
                        else
                            error "Update failed. Please try again or choose another option."
                        fi
                    else
                        log "ERROR" "Only AppImage installations can be updated."
                    fi
                fi
                ;;
            r)
                if [[ $num_installations -gt 1 ]]; then
                    while true; do
                        log "INFO" "Enter the number of the installation you want to remove (1-$num_installations):"
                        local choice
                        read -r choice
                        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "$num_installations" ]; then
                            remove_specific_installation "${installations[$((choice-1))]}"
                            break
                        else
                            log "ERROR" "Invalid choice. Please enter a number between 1 and $num_installations."
                        fi
                    done
                else
                    remove_specific_installation "${installations[0]}"
                fi
                
                local continue_install=$(ask "Do you want to continue with the Cursor installation? (y/n)" "y" "ynYN")
                if [[ "${continue_install,,}" = "y" ]]; then
                    log "INFO" "Continuing with installation..."
                    return 0
                else
                    log "INFO" "Installation cancelled by user."
                    exit 0
                fi
                ;;
            a)
                log "WARNING" "Removing all existing installations..."
                local all_success=true
                for install in "${installations[@]}"; do
                    if ! remove_specific_installation "$install"; then
                        all_success=false
                    fi
                done
                
                if [[ "$all_success" = true ]]; then
                    local continue_install=$(ask "All installations have been removed. Do you want to continue with the new installation? (y/n)" "y" "ynYN")
                    if [[ "${continue_install,,}" = "y" ]]; then
                        log "INFO" "Continuing with installation..."
                        return 0
                    else
                        log "INFO" "Installation cancelled by user."
                        exit 0
                    fi
                else
                    error "There were errors during removal of installations. Please check and try again."
                fi
                ;;
            s)
                log "INFO" "Keeping existing installations and continuing with new installation..."
                return 0
                ;;
            *)
                log "INFO" "Installation cancelled by user."
                exit 0
                ;;
        esac
    fi
}

# Function to repair installation
repair_installation() {
    log "INFO" "Starting repair of Cursor installation..."
    
    # Verify file integrity
    local files_to_check=(
        "${APPIMAGE_PATH}"
        "${ICON_PATH}"
        "${DESKTOP_FILE_PATH}"
        "${LAUNCHER_SCRIPT}"
    )
    
    local needs_repair=false
    
    for file in "${files_to_check[@]}"; do
        if [[ ! -f "$file" ]]; then
            log "WARNING" "Missing file: $file"
            needs_repair=true
        elif [[ ! -x "$file" && "${file##*.}" != "svg" ]]; then
            log "WARNING" "Incorrect permissions: $file"
            needs_repair=true
        fi
    done
    
    if [[ "$needs_repair" = true ]]; then
        log "INFO" "Starting repair process..."
        
        # Download missing files
        if [[ ! -f "${APPIMAGE_PATH}" ]]; then
            local download_url
            download_url=$(get_download_url "appimage" "x64")
            download_with_progress "$download_url" "${APPIMAGE_PATH}" "Cursor AppImage"
            chmod +x "${APPIMAGE_PATH}"
        fi
        
        if [[ ! -f "${ICON_PATH}" ]]; then
            download_with_progress "${ICON_DOWNLOAD_URL}" "${ICON_PATH}" "Cursor icon"
        fi
        
        # Recreate configuration files
        create_desktop_file
        create_launcher_script
        
        # Update system cache
        update-desktop-database "${DESKTOP_DIR}" 2>/dev/null || true
        gtk-update-icon-cache -f -t ~/.local/share/icons 2>/dev/null || true
        
        log "SUCCESS" "✨ Repair completed successfully! ✨"
    else
        log "SUCCESS" "All files are intact, no repair needed."
    fi
}

# Function to create .desktop file
create_desktop_file() {
    log "INFO" "Creating .desktop file..."
    cat > "${DESKTOP_FILE_PATH}" << EOF
[Desktop Entry]
Name=Cursor
Exec=${LAUNCHER_SCRIPT} %F
Terminal=false
Type=Application
Icon=${ICON_PATH}
StartupWMClass=Cursor
X-AppImage-Version=latest
Comment=Cursor is an AI-first coding environment.
MimeType=x-scheme-handler/cursor;
Categories=Utility;Development
EOF
    chmod +x "${DESKTOP_FILE_PATH}"
    log "SUCCESS" "Desktop file created in: ${DESKTOP_FILE_PATH}"
}

# Function to create launcher script
create_launcher_script() {
    log "INFO" "Creating launcher script..."
    cat > "${LAUNCHER_SCRIPT}" << EOF
#!/bin/bash

# Configurations
CURSOR_APP="${APPIMAGE_PATH}"
LOG_FILE="\${HOME}/.cursor_log"
SANDBOX_FLAG="$([ "$SANDBOX_MODE" = "s" ] && echo "--no-sandbox" || echo "")"

# Logging function
log_msg() {
    echo "\$(date '+%Y-%m-%d %H:%M:%S') - \$1" >> "\$LOG_FILE"
}

# Cursor main function
run_cursor() {
    local target="\$1"
    
    if [ "\$target" = "." ] || [ -z "\$target" ]; then
        log_msg "Starting Cursor in current directory: \$(pwd)"
        nohup "\$CURSOR_APP" \$SANDBOX_FLAG "\$(pwd)" > "\$LOG_FILE" 2>&1 &
    else
        log_msg "Starting Cursor with arguments: \$*"
        nohup "\$CURSOR_APP" \$SANDBOX_FLAG "\$@" > "\$LOG_FILE" 2>&1 &
    fi
}

run_cursor "\$@"
EOF
    chmod +x "${LAUNCHER_SCRIPT}"
    log "SUCCESS" "Launcher script created in: ${LAUNCHER_SCRIPT}"
}

# Function to install AppImage
install_appimage() {
    local download_url=$1
    local appimage_path=$2
    
    log "INFO" "Installing Cursor AppImage..."
    
    # Download AppImage
    download_with_progress "$download_url" "$appimage_path" "Cursor AppImage"
    chmod +x "$appimage_path"
    
    # Download icon if not exists
    if [ ! -f "${ICON_PATH}" ]; then
        download_with_progress "${ICON_DOWNLOAD_URL}" "${ICON_PATH}" "Cursor icon"
    fi
    
    create_desktop_file
    create_launcher_script
    
    log "SUCCESS" "✓ AppImage installed successfully!"
}

# Function to install DEB package
install_deb() {
    local download_url=$1
    local temp_deb="${TEMP_DIR}/cursor.deb"
    
    log "INFO" "Installing Cursor DEB package..."
    
    # Download DEB package
    download_with_progress "$download_url" "$temp_deb" "Cursor DEB package"
    
    # Check if sudo is required
    if [[ $EUID -ne 0 ]]; then
        log "INFO" "Installing DEB package (may require sudo password)..."
        if sudo dpkg -i "$temp_deb"; then
            log "SUCCESS" "✓ DEB package installed successfully!"
        else
            log "WARNING" "dpkg installation failed, trying apt..."
            sudo apt-get update && sudo apt-get install -f
            if sudo dpkg -i "$temp_deb"; then
                log "SUCCESS" "✓ DEB package installed successfully!"
            else
                error "Failed to install DEB package"
            fi
        fi
    else
        if dpkg -i "$temp_deb"; then
            log "SUCCESS" "✓ DEB package installed successfully!"
        else
            error "Failed to install DEB package"
        fi
    fi
    
    # Clean up
    rm -f "$temp_deb"
}

# Function to install RPM package
install_rpm() {
    local download_url=$1
    local temp_rpm="${TEMP_DIR}/cursor.rpm"
    
    log "INFO" "Installing Cursor RPM package..."
    
    # Download RPM package
    download_with_progress "$download_url" "$temp_rpm" "Cursor RPM package"
    
    # Check if sudo is required
    if [[ $EUID -ne 0 ]]; then
        log "INFO" "Installing RPM package (may require sudo password)..."
        
        # Try different package managers
        if command -v dnf >/dev/null 2>&1; then
            sudo dnf install -y "$temp_rpm"
        elif command -v yum >/dev/null 2>&1; then
            sudo yum install -y "$temp_rpm"
        elif command -v zypper >/dev/null 2>&1; then
            sudo zypper install -y "$temp_rpm"
        else
            sudo rpm -i "$temp_rpm"
        fi
        
        if [[ $? -eq 0 ]]; then
            log "SUCCESS" "✓ RPM package installed successfully!"
        else
            error "Failed to install RPM package"
        fi
    else
        if rpm -i "$temp_rpm"; then
            log "SUCCESS" "✓ RPM package installed successfully!"
        else
            error "Failed to install RPM package"
        fi
    fi
    
    # Clean up
    rm -f "$temp_rpm"
}

# Function to select package format
select_package_format() {
    local choice=""
    local valid_formats=("appimage" "deb" "rpm")
    
    echo ""
    echo "┌─────────────────────────────────────────────────────────────┐"
    echo "│                    PACKAGE SELECTION                      │"
    echo "├─────────────────────────────────────────────────────────────┤"
    echo "│ Distribution: $DETECTED_DISTRO"
    echo "│ Architecture: $DETECTED_ARCH"
    echo "│ Recommended: $RECOMMENDED_FORMAT"
    echo "│"
    echo "│ Available options:"
    echo "│ [1] AppImage - Universal, no root privileges required"
    echo "│ [2] DEB      - For Ubuntu/Debian (may require sudo)"
    echo "│ [3] RPM      - For Fedora/openSUSE (may require sudo)"
    echo "└─────────────────────────────────────────────────────────────┘"
    echo ""
    
    while true; do
        printf "Choose package format (1-3) [default: %s]: " "$RECOMMENDED_FORMAT" >&2
        read -r choice </dev/tty
        
        # Set default if empty
        if [[ -z "$choice" ]]; then
            case "$RECOMMENDED_FORMAT" in
                "appimage") choice="1" ;;
                "deb") choice="2" ;;
                "rpm") choice="3" ;;
                *) choice="1" ;;
            esac
        fi
        
        case "$choice" in
            1)
                SELECTED_FORMAT="appimage"
                return 0
                ;;
            2)
                SELECTED_FORMAT="deb"
                return 0
                ;;
            3)
                SELECTED_FORMAT="rpm"
                return 0
                ;;
            *)
                log "ERROR" "Invalid option. Choose 1, 2, or 3."
                ;;
        esac
    done
}

# Installation function
install_cursor() {
    log "INFO" "Starting Cursor IDE v${VERSION} installation..."
    
    # Preliminary checks
    detect_distribution
    check_disk_space
    check_internet_connection
    check_existing_installation
    
    # List available packages and get user selection
    list_available_packages
    local selected_format
    select_package_format
    selected_format="$SELECTED_FORMAT"
    
    # Validate package manager for selected format
    if ! check_package_manager "$selected_format"; then
        log "WARNING" "Package manager for $selected_format not available"
        local fallback=$(ask "Do you want to use AppImage as alternative? (y/n)" "y" "ynYN")
        if [[ "${fallback,,}" = "y" ]]; then
            selected_format="appimage"
            log "INFO" "Switching to AppImage format"
        else
            error "Installation cancelled"
        fi
    fi
    
    # Get download URL for selected format
    log "INFO" "Getting download URL for selected format: $selected_format"
    local download_url
    download_url=$(get_download_url "$selected_format" "$DETECTED_ARCH")
    
    if [[ -z "$download_url" ]]; then
        error "Failed to get download URL for $selected_format"
    fi
    
    # Configure installation paths (only for AppImage)
    if [[ "$selected_format" = "appimage" ]]; then
        APP_DIR=$(ask "Enter the application installation directory" "${HOME}/Applications")
        SANDBOX_MODE=$(ask "Do you want to run Cursor with sandbox?" "y" "ynYN")
        
        # Create necessary directories
        mkdir -p "${APP_DIR}" "${ICON_DIR}" "${DESKTOP_DIR}" "${BIN_DIR}" || error "Failed to create directories"
        
        # Update paths
        APPIMAGE_PATH="${APP_DIR}/cursor.AppImage"
        LAUNCHER_SCRIPT="${BIN_DIR}/cursor"
    fi
    
    # Install based on format
    case "$selected_format" in
        "appimage")
            install_appimage "$download_url" "$APPIMAGE_PATH"
            ;;
        "deb")
            install_deb "$download_url"
            ;;
        "rpm")
            install_rpm "$download_url"
            ;;
    esac
    
    # Verify installation
    verify_installation
    
    log "SUCCESS" "✨ Cursor installed successfully! ✨"
    show_post_install_message
}

# Function to verify installation
verify_installation() {
    local verification_failed=false
    
    log "INFO" "Verifying installation..."
    
    # Verify essential files
    for file in "${APPIMAGE_PATH}" "${ICON_PATH}" "${DESKTOP_FILE_PATH}" "${LAUNCHER_SCRIPT}"; do
        if [[ ! -f "$file" ]]; then
            log "ERROR" "Missing file: $file"
            verification_failed=true
        elif [[ ! -x "$file" && "${file##*.}" != "svg" ]]; then
            log "ERROR" "Incorrect permissions: $file"
            verification_failed=true
        fi
    done
    
    if [[ "$verification_failed" = true ]]; then
        error "Installation verification failed. Please execute repair."
    fi
}

# Function to show post-installation message
show_post_install_message() {
    cat << EOF

┌─────────────────────────────────────────────────────────────┐
│                    INSTALLATION COMPLETED!                  │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│ To run Cursor, you can:                                     │
│                                                             │
│ 1. Search for 'Cursor' in your application launcher        │
│ 2. Run in terminal: cursor                                 │
│ 3. Run directly: ${APPIMAGE_PATH}                          │
│ 4. Open files/directories: cursor <file_or_directory>     │
│                                                             │
│ Important notes:                                           │
│                                                             │
│ • You may need to logout/login for all changes to take     │
│   effect                                                   │
│ • Execution logs are saved in ~/.cursor_log                │
│ • To repair installation: $0 --repair                       │
│ • To uninstall: $0 --uninstall                              │
│                                                             │
│ Installed version: ${VERSION}                              │
│ Distribution: $DETECTED_DISTRO                             │
│ Architecture: $DETECTED_ARCH                               │
│                                                             │
└─────────────────────────────────────────────────────────────┘

EOF
}

# Function to uninstall the Cursor
uninstall_cursor() {
    log "WARNING" "Starting uninstallation process of Cursor..."
    
    # Confirm uninstallation
    local confirm=$(ask "Are you sure you want to uninstall Cursor? (y/n)" "n" "ynYN")
    if [[ $confirm != "y" ]]; then
        log "INFO" "Uninstallation cancelled by user."
        exit 0
    fi
    
    local files_to_remove=(
        "${APPIMAGE_PATH}"
        "${ICON_PATH}"
        "${DESKTOP_FILE_PATH}"
        "${LAUNCHER_SCRIPT}"
        "${HOME}/.cursor_log"
    )
    
    local success=true
    
    for file in "${files_to_remove[@]}"; do
        if [[ -f "$file" ]]; then
            log "INFO" "Removing: $file"
            if rm -f "$file"; then
                log "SUCCESS" "✓ Removed: $file"
            else
                log "ERROR" "✗ Failed to remove: $file"
                success=false
            fi
        fi
    done
    
    # Update system cache
    update-desktop-database "${DESKTOP_DIR}" 2>/dev/null || true
    gtk-update-icon-cache -f -t ~/.local/share/icons 2>/dev/null || true
    
    if [[ "$success" = true ]]; then
        log "SUCCESS" "✨ Cursor uninstalled successfully! ✨"
    else
        log "WARNING" "Uninstallation completed with some errors. Please check above messages."
    fi
}

# Help function
show_help() {
    cat << EOF
Usage: $0 [OPTION]

Cursor IDE Installation Script v${VERSION}
Intelligent script for Cursor IDE installation on multiple Linux distributions

Options:
  -i, --install     Install Cursor (default)
  -u, --uninstall   Uninstall Cursor
  -r, --repair      Repair existing installation
  -h, --help        Show this help message

Features:
  • Automatic distribution detection (Ubuntu, Debian, Fedora, openSUSE, Arch)
  • Multiple format support: AppImage, DEB, RPM
  • Automatic architecture detection (x64, arm64, armv7l)
  • Installation without root privileges (AppImage)
  • Existing installation management
  • Backup and rollback system
  • Integrity verification

Supported distributions:
  • Ubuntu/Debian → DEB (recommended)
  • Fedora/RHEL/CentOS → RPM (recommended)
  • openSUSE → RPM (recommended)
  • Arch Linux → AppImage (recommended)
  • Others → AppImage (universal)

Examples:
  $0 --install          # Interactive installation
  $0 --uninstall        # Uninstall Cursor
  $0 --repair           # Repair corrupted installation

EOF
}

# Main function
main() {
    local action="install"
    
    # Process command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -i|--install)
                action="install"
                shift
                ;;
            -u|--uninstall)
                action="uninstall"
                shift
                ;;
            -r|--repair)
                action="repair"
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                log "ERROR" "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    case $action in
        "install")
            install_cursor
            ;;
        "uninstall")
            uninstall_cursor
            ;;
        "repair")
            repair_installation
            ;;
    esac
}

# Execute the script
mkdir -p "${APP_DIR}" || error "Failed to create application directory: ${APP_DIR}"
main "$@"
