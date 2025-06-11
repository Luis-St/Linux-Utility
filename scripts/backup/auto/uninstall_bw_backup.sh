#!/bin/bash

# Bitwarden Backup Service Uninstall Script
# Removes the Bitwarden backup service and all associated files

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SERVICE_NAME="bitwarden-backup.service"
TIMER_NAME="bitwarden-backup.timer"
BACKUP_DIR="$HOME/.backup"
TARGET_SCRIPT_PATH="$BACKUP_DIR/bw_backup.sh"
SYSTEMD_USER_DIR="$HOME/.config/systemd/user"
SERVICE_PATH="$SYSTEMD_USER_DIR/$SERVICE_NAME"
TIMER_PATH="$SYSTEMD_USER_DIR/$TIMER_NAME"
ENV_FILE="$BACKUP_DIR/.bitwarden_env"
LOG_FILE="$HOME/.bitwarden_backup.log"
OLD_LOG_FILE="$HOME/.bitwarden_backup.log.old"

# Function to print colored output
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${RED}===================================${NC}"
    echo -e "${RED}  Bitwarden Backup Uninstaller${NC}"
    echo -e "${RED}===================================${NC}"
    echo
}

# Function to check if installation exists
check_installation() {
    print_info "Checking for existing installation..."

    local found_files=0

    if [[ -f "$TARGET_SCRIPT_PATH" ]]; then
        print_info "Found backup script: $TARGET_SCRIPT_PATH"
        found_files=1
    fi

    if [[ -f "$SERVICE_PATH" ]]; then
        print_info "Found service file: $SERVICE_PATH"
        found_files=1
    fi

    if [[ -f "$TIMER_PATH" ]]; then
        print_info "Found timer file: $TIMER_PATH"
        found_files=1
    fi

    if [[ -f "$ENV_FILE" ]]; then
        print_info "Found environment file: $ENV_FILE"
        found_files=1
    fi

    if [[ -f "$LOG_FILE" ]]; then
        print_info "Found log file: $LOG_FILE"
        found_files=1
    fi

    if [[ -f "$OLD_LOG_FILE" ]]; then
        print_info "Found old log file: $OLD_LOG_FILE"
        found_files=1
    fi

    if [[ $found_files -eq 0 ]]; then
        print_warning "No Bitwarden backup installation found"
        echo "Nothing to uninstall."
        exit 0
    fi

    echo
}

# Function to confirm uninstallation
confirm_uninstall() {
    print_warning "This will completely remove the Bitwarden backup service and all associated files."
    echo
    echo "The following will be removed:"
    echo "  - Backup script"
    echo "  - Systemd service"
    echo "  - Environment file (contains credentials)"
    echo
    echo "Optional removals:"
    echo "  - Log files (you will be asked)"
    echo "  - Timer configuration (if exists)"
    echo
    echo -n "Are you sure you want to continue? (y/N): "
    read -n 1 -r
    echo
    echo

    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Uninstallation cancelled"
        exit 0
    fi
}

# Function to stop and disable services
stop_services() {
    print_info "Stopping and disabling services..."

    # Check if timer exists and is active
    if systemctl --user is-enabled "$TIMER_NAME" &>/dev/null; then
        print_info "Stopping and disabling timer..."
        systemctl --user stop "$TIMER_NAME" 2>/dev/null
        systemctl --user disable "$TIMER_NAME" 2>/dev/null
        print_success "Timer stopped and disabled"
    fi

    # Check if service exists and is active
    if systemctl --user is-enabled "$SERVICE_NAME" &>/dev/null; then
        print_info "Stopping and disabling service..."
        systemctl --user stop "$SERVICE_NAME" 2>/dev/null
        systemctl --user disable "$SERVICE_NAME" 2>/dev/null
        print_success "Service stopped and disabled"
    fi

    # Reload systemd to clean up
    systemctl --user daemon-reload
}

# Function to remove script file
remove_script() {
    if [[ -f "$TARGET_SCRIPT_PATH" ]]; then
        print_info "Removing backup script..."
        rm -f "$TARGET_SCRIPT_PATH"

        if [[ $? -eq 0 ]]; then
            print_success "Backup script removed"
        else
            print_error "Failed to remove backup script"
        fi
    fi
}

# Function to remove service files
remove_service_files() {
    if [[ -f "$SERVICE_PATH" ]]; then
        print_info "Removing service file..."
        rm -f "$SERVICE_PATH"

        if [[ $? -eq 0 ]]; then
            print_success "Service file removed"
        else
            print_error "Failed to remove service file"
        fi
    fi

    if [[ -f "$TIMER_PATH" ]]; then
        print_info "Removing timer file..."
        rm -f "$TIMER_PATH"

        if [[ $? -eq 0 ]]; then
            print_success "Timer file removed"
        else
            print_error "Failed to remove timer file"
        fi
    fi

    # Reload systemd after removing service files
    systemctl --user daemon-reload
}

# Function to remove environment file
remove_env_file() {
    if [[ -f "$ENV_FILE" ]]; then
        print_info "Removing environment file (contains credentials)..."

        # Securely overwrite the file before removing
        if command -v shred &> /dev/null; then
            shred -vfz -n 3 "$ENV_FILE" 2>/dev/null
        else
            # Fallback: overwrite with random data
            dd if=/dev/urandom of="$ENV_FILE" bs=$(stat -c%s "$ENV_FILE" 2>/dev/null || echo 1024) count=1 2>/dev/null
        fi

        rm -f "$ENV_FILE"

        if [[ $? -eq 0 ]]; then
            print_success "Environment file securely removed"
        else
            print_error "Failed to remove environment file"
        fi
    fi
}

# Function to ask about log files
remove_log_files() {
    local log_files_exist=0

    if [[ -f "$LOG_FILE" ]] || [[ -f "$OLD_LOG_FILE" ]]; then
        log_files_exist=1
    fi

    if [[ $log_files_exist -eq 1 ]]; then
        echo
        print_info "Log files found:"
        [[ -f "$LOG_FILE" ]] && echo "  - $LOG_FILE"
        [[ -f "$OLD_LOG_FILE" ]] && echo "  - $OLD_LOG_FILE"
        echo
        echo -n "Do you want to remove log files? (y/N): "
        read -n 1 -r
        echo

        if [[ $REPLY =~ ^[Yy]$ ]]; then
            print_info "Removing log files..."

            [[ -f "$LOG_FILE" ]] && rm -f "$LOG_FILE"
            [[ -f "$OLD_LOG_FILE" ]] && rm -f "$OLD_LOG_FILE"

            print_success "Log files removed"
        else
            print_info "Log files preserved"
        fi
    fi
}

# Function to check for remaining files
check_cleanup() {
    print_info "Checking for any remaining files..."

    local remaining_files=0

    if [[ -f "$TARGET_SCRIPT_PATH" ]]; then
        print_warning "Script file still exists: $TARGET_SCRIPT_PATH"
        remaining_files=1
    fi

    if [[ -f "$SERVICE_PATH" ]]; then
        print_warning "Service file still exists: $SERVICE_PATH"
        remaining_files=1
    fi

    if [[ -f "$TIMER_PATH" ]]; then
        print_warning "Timer file still exists: $TIMER_PATH"
        remaining_files=1
    fi

    if [[ -f "$ENV_FILE" ]]; then
        print_warning "Environment file still exists: $ENV_FILE"
        remaining_files=1
    fi

    # Check if backup directory is empty and can be removed
    if [[ -d "$BACKUP_DIR" ]]; then
        if [[ -z "$(ls -A "$BACKUP_DIR" 2>/dev/null)" ]]; then
            print_info "Backup directory is empty, removing it..."
            rmdir "$BACKUP_DIR" 2>/dev/null
            if [[ $? -eq 0 ]]; then
                print_success "Empty backup directory removed"
            fi
        fi
    fi

    if [[ $remaining_files -eq 0 ]]; then
        print_success "All installation files successfully removed"
    else
        print_warning "Some files could not be removed. Manual cleanup may be required."
    fi
}

# Function to show completion information
show_completion_info() {
    echo
    print_success "Uninstallation completed!"
    echo
    echo -e "${BLUE}What was removed:${NC}"
    echo "  ✓ Backup script"
    echo "  ✓ Systemd service and timer"
    echo "  ✓ Environment file (credentials)"
    echo "  ✓ Service registrations"
    echo

    if [[ -f "$LOG_FILE" ]] || [[ -f "$OLD_LOG_FILE" ]]; then
        echo -e "${BLUE}Preserved files:${NC}"
        [[ -f "$LOG_FILE" ]] && echo "  - $LOG_FILE"
        [[ -f "$OLD_LOG_FILE" ]] && echo "  - $OLD_LOG_FILE"
        echo
    fi

    echo -e "${BLUE}Cleanup verification:${NC}"
    echo "  Run 'systemctl --user status bitwarden-backup.service' to verify removal"
    echo

    # Check if lingering is still enabled
    if loginctl show-user "$USER" --property=Linger --value 2>/dev/null | grep -q "yes"; then
        echo -e "${YELLOW}Note:${NC} User lingering is still enabled."
        echo "  To disable: sudo loginctl disable-linger $USER"
        echo
    fi
}

# Function to handle errors during uninstall
handle_error() {
    print_error "An error occurred during uninstallation"
    echo "Some files may not have been removed completely."
    echo "You may need to manually remove remaining files."
    exit 1
}

# Main uninstallation function
main() {
    print_header

    # Set up error handling
    trap handle_error ERR

    # Check what's installed
    check_installation

    # Confirm with user
    confirm_uninstall

    # Uninstallation steps
    stop_services
    remove_service_files
    remove_script
    remove_env_file
    remove_log_files

    # Verify cleanup
    check_cleanup

    # Show completion info
    show_completion_info
}

# Run main function
main "$@"
