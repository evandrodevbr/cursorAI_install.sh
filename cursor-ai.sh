#!/bin/bash

# ====================================================================================
# Cursor IDE Installation, Uninstallation and Maintenance Script
# 
# This script manages the complete lifecycle of Cursor IDE on Linux, including:
# - Installation with dependency checking
# - Safe uninstallation
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
DOWNLOAD_URL="https://downloader.cursor.sh/linux/appImage/x64"
ICON_DOWNLOAD_URL="https://www.cursor.com/assets/images/logo.svg"
APPIMAGE_NAME="cursor.AppImage"
APPIMAGE_PATH="${APP_DIR}/${APPIMAGE_NAME}"
ICON_PATH="${ICON_DIR}/cursor-icon.svg"
DESKTOP_FILE_PATH="${DESKTOP_DIR}/cursor.desktop"
LAUNCHER_SCRIPT="${BIN_DIR}/cursor"

# Color and style configuration
declare -A COLORS=(
    ["INFO"]="\033[0;34m"     # Blue
    ["SUCCESS"]="\033[0;32m"  # Green
    ["WARNING"]="\033[0;33m"  # Yellow
    ["ERROR"]="\033[0;31m"    # Red
    ["RESET"]="\033[0m"       # Reset
    ["BOLD"]="\033[1m"        # Bold
    ["PROGRESS"]="\033[0;36m" # Cyan
)

# Function to clean temporary files
cleanup() {
    local exit_code=$?
    log "INFO" "Cleaning up temporary files..."
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
    printf "[%s] ${COLORS[$level]}${COLORS[BOLD]}[%s]${COLORS[RESET]} %s\n" "$timestamp" "$level" "$*"
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
        printf "${COLORS[INFO]}${question}${COLORS[RESET]}"
        if [[ -n $default ]]; then
            printf " (default: ${COLORS[BOLD]}%s${COLORS[RESET]})" "$default"
        fi
        if [[ -n $valid_options ]]; then
            printf " [%s]" "$valid_options"
        fi
        printf ": "
        read -r answer
        answer=${answer:-$default}
        
        # Response validation
        if [[ -n $valid_options ]]; then
            if [[ $answer =~ ^[$valid_options]$ ]]; then
                break
            else
                log "ERROR" "Invalid option. Please choose one of: [$valid_options]"
                continue
            fi
        else
            # If no specific valid options, accept any non-empty response
            if [[ -n $answer ]]; then
                break
            else
                log "ERROR" "Please provide a valid response."
                continue
            fi
        fi
    done
    
    echo "$answer"
}

# Function for showing progress bar
show_progress() {
    local current=$1
    local total=$2
    local width=50
    local percentage=$((current * 100 / total))
    local filled=$((width * current / total))
    local empty=$((width - filled))
    
    printf "\r${COLORS[PROGRESS]}["
    printf "%${filled}s" '' | tr ' ' '='
    printf "%${empty}s" '' | tr ' ' ' '
    printf "] %3d%%${COLORS[RESET]}" "$percentage"
    
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
        
        if curl -L --progress-bar --connect-timeout $TIMEOUT "$url" -o "$temp_file" 2>&1 | \
        stdbuf -o0 tr '\r' '\n' | grep -o "[0-9]*\.[0-9]%" | while read -r percent; do
            percent=${percent%.*}
            show_progress "$percent" 100
        done; then
            # Verify download integrity
            if [[ -s "$temp_file" ]]; then
                mv "$temp_file" "$output"
                log "SUCCESS" "Download completed successfully!"
                return 0
            else
                log "ERROR" "Downloaded file is empty or corrupted."
            fi
        fi
        
        retries=$((retries + 1))
        if [ $retries -lt $MAX_RETRIES ]; then
            local wait_time=$((retries * 5))
            log "WARNING" "Download failed. Retrying in $wait_time seconds..."
            sleep $wait_time
        fi
    done
    
    error "Failed to download $description after $MAX_RETRIES attempts."
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

${COLORS[INFO]}Available options:${COLORS[RESET]}
${COLORS[WARNING]}U${COLORS[RESET]} - Update existing installation
${COLORS[WARNING]}R${COLORS[RESET]} - Remove specific installation
${COLORS[WARNING]}A${COLORS[RESET]} - Remove all installations
${COLORS[WARNING]}S${COLORS[RESET]} - Replace keeping existing
${COLORS[WARNING]}C${COLORS[RESET]} - Cancel installation

EOF
        
        local action=$(ask "What do you want to do?" "C" "UuRrAaSsCc")
        case "${action,,}" in
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
                                local try_again=$(ask "Do you want to choose another installation? (s/n)" "s" "sn")
                                if [[ "${try_again,,}" != "s" ]]; then
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
                
                local continue_install=$(ask "Do you want to continue with the Cursor installation? (s/n)" "s" "sn")
                if [[ "${continue_install,,}" = "s" ]]; then
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
                    local continue_install=$(ask "All installations have been removed. Do you want to continue with the new installation? (s/n)" "s" "sn")
                    if [[ "${continue_install,,}" = "s" ]]; then
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
            download_with_progress "${DOWNLOAD_URL}" "${APPIMAGE_PATH}" "Cursor AppImage"
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

# Installation function
install_cursor() {
    log "INFO" "Starting Cursor IDE v${VERSION} installation..."
    
    # Preliminary checks
    check_disk_space
    check_internet_connection
    check_existing_installation
    
    # Ask user about installation directories
    APP_DIR=$(ask "Enter the application installation directory" "${HOME}/Applications")
    SANDBOX_MODE=$(ask "Do you want to run Cursor without sandbox?" "s" "sn")
    
    # Create necessary directories
    mkdir -p "${APP_DIR}" "${ICON_DIR}" "${DESKTOP_DIR}" "${BIN_DIR}" || error "Failed to create directories"
    
    # Downloads with retry and verification
    download_with_progress "${DOWNLOAD_URL}" "${APPIMAGE_PATH}" "Cursor AppImage"
    chmod +x "${APPIMAGE_PATH}"
    
    if [ ! -f "${ICON_PATH}" ]; then
        download_with_progress "${ICON_DOWNLOAD_URL}" "${ICON_PATH}" "Cursor icon"
    fi
    
    create_desktop_file
    create_launcher_script
    
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

${COLORS[SUCCESS]}${COLORS[BOLD]}Installation Completed!${COLORS[RESET]}

${COLORS[INFO]}To run Cursor, you can:${COLORS[RESET]}
1. Search for 'Cursor' in your application launcher
2. Run in terminal: cursor
3. Run directly: ${APPIMAGE_PATH}
4. Open files/directories: cursor <file_or_directory>

${COLORS[WARNING]}Notes:${COLORS[RESET]}
- You may need to logout and login again for all changes to take effect
- Execution logs are saved in ~/.cursor_log
- To repair the installation: $0 --repair
- To uninstall: $0 --uninstall

${COLORS[INFO]}Installed version: ${VERSION}${COLORS[RESET]}
EOF
}

# Function to uninstall the Cursor
uninstall_cursor() {
    log "WARNING" "Starting uninstallation process of Cursor..."
    
    # Confirm uninstallation
    local confirm=$(ask "Are you sure you want to uninstall Cursor? (s/n)" "n")
    if [[ $confirm != "s" ]]; then
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
${COLORS[BOLD]}Usage: $0 [OPTION]${COLORS[RESET]}

Options:
  ${COLORS[INFO]}-i, --install${COLORS[RESET]}     Install Cursor (default)
  ${COLORS[WARNING]}-u, --uninstall${COLORS[RESET]}   Uninstall Cursor
  ${COLORS[INFO]}-r, --repair${COLORS[RESET]}      Repair existing installation
  ${COLORS[INFO]}-h, --help${COLORS[RESET]}        Show this help message

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
main "$@"
