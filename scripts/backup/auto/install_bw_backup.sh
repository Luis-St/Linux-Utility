#!/bin/bash

# Bitwarden Backup Service Install Script
# Installs and configures the Bitwarden backup service

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_NAME="bw_backup.sh"
SERVICE_NAME="bitwarden-backup.service"
BACKUP_DIR="$HOME/.backup"
TARGET_SCRIPT_PATH="$BACKUP_DIR/bw_backup.sh"
SYSTEMD_USER_DIR="$HOME/.config/systemd/user"
SERVICE_PATH="$SYSTEMD_USER_DIR/$SERVICE_NAME"
ENV_FILE="$BACKUP_DIR/.bitwarden_env"

# Global flags
UPDATE_MODE=false

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
    if [[ "$UPDATE_MODE" == true ]]; then
        echo -e "${BLUE}================================${NC}"
        echo -e "${BLUE}  Bitwarden Backup Updater${NC}"
        echo -e "${BLUE}================================${NC}"
    else
        echo -e "${BLUE}================================${NC}"
        echo -e "${BLUE}  Bitwarden Backup Installer${NC}"
        echo -e "${BLUE}================================${NC}"
    fi
    echo
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "OPTIONS:"
    echo "  -u, --update    Update mode - only update script and service files"
    echo "  -h, --help      Show this help message"
    echo
    echo "EXAMPLES:"
    echo "  $0              Full installation with credential setup"
    echo "  $0 --update     Update existing installation without changing credentials"
}

# Function to parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -u|--update)
                UPDATE_MODE=true
                shift
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
}

# Function to check if script is run from correct directory
check_files() {
    print_info "Checking for required files..."

    if [[ ! -f "$SCRIPT_NAME" ]]; then
        print_error "$SCRIPT_NAME not found in current directory"
        echo "Please run this installer from the directory containing $SCRIPT_NAME"
        exit 1
    fi

    print_success "Found $SCRIPT_NAME"
}

# Function to check dependencies
check_dependencies() {
    print_info "Checking dependencies..."

    if ! command -v bw &> /dev/null; then
        print_error "Bitwarden CLI (bw) is not installed"
        echo "Please install it with: npm install -g @bitwarden/cli"
        exit 1
    fi

    if ! command -v systemctl &> /dev/null; then
        print_error "systemctl is not available. This installer requires systemd."
        exit 1
    fi

    # Detect bw installation path for systemd service
    BW_PATH=$(which bw)
    BW_DIR=$(dirname "$BW_PATH")

    print_success "All dependencies satisfied"
    print_info "Bitwarden CLI found at: $BW_PATH"
}

# Function to check for existing installation
check_existing_installation() {
    if [[ "$UPDATE_MODE" == true ]]; then
        # In update mode, require existing installation
        if [[ ! -f "$TARGET_SCRIPT_PATH" ]] && [[ ! -f "$SERVICE_PATH" ]]; then
            print_error "No existing installation found. Run without --update flag for initial installation."
            exit 1
        fi

        if [[ ! -f "$ENV_FILE" ]]; then
            print_error "Environment file not found at $ENV_FILE"
            print_error "Cannot update without existing credentials. Run without --update flag to reconfigure."
            exit 1
        fi

        print_info "Existing installation found - proceeding with update"
    else
        # In install mode, warn about overwriting
        if [[ -f "$TARGET_SCRIPT_PATH" ]] || [[ -f "$SERVICE_PATH" ]]; then
            print_warning "Existing installation detected"
            echo -n "Do you want to continue and overwrite? (y/N): "
            read -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                print_info "Installation cancelled"
                exit 0
            fi
            echo
        fi
    fi
}

# Function to get credentials from user
get_credentials() {
    print_info "Please provide your Bitwarden credentials:"
    echo

    echo -n "Enter your Bitwarden Client ID: "
    read CLIENT_ID

    if [[ -z "$CLIENT_ID" ]]; then
        print_error "Client ID cannot be empty"
        exit 1
    fi

    echo -n "Enter your Bitwarden Client Secret: "
    read -s CLIENT_SECRET
    echo

    if [[ -z "$CLIENT_SECRET" ]]; then
        print_error "Client Secret cannot be empty"
        exit 1
    fi

    echo -n "Enter your Bitwarden Master Password: "
    read -s MASTER_PASSWORD
    echo

    if [[ -z "$MASTER_PASSWORD" ]]; then
        print_error "Master Password cannot be empty"
        exit 1
    fi

    print_success "Credentials collected"
}

# Function to create environment file
create_env_file() {
    print_info "Creating secure environment file..."

    # Ensure backup directory exists
    mkdir -p "$BACKUP_DIR"

    cat > "$ENV_FILE" << EOF
BW_CLIENT_ID=$CLIENT_ID
BW_CLIENT_SECRET=$CLIENT_SECRET
BW_MASTER_PASSWORD=$MASTER_PASSWORD
EOF

    # Secure the environment file
    chmod 600 "$ENV_FILE"

    print_success "Environment file created at $ENV_FILE"
}

# Function to copy backup script
install_script() {
    if [[ "$UPDATE_MODE" == true ]]; then
        print_info "Updating backup script..."
    else
        print_info "Installing backup script..."
    fi

    # Create backup directory if it doesn't exist
    mkdir -p "$BACKUP_DIR"

    if [[ $? -ne 0 ]]; then
        print_error "Failed to create directory $BACKUP_DIR"
        exit 1
    fi

    # Copy the script to target location
    cp "$SCRIPT_NAME" "$TARGET_SCRIPT_PATH"

    if [[ $? -ne 0 ]]; then
        print_error "Failed to copy script to $TARGET_SCRIPT_PATH"
        exit 1
    fi

    # Make it executable
    chmod +x "$TARGET_SCRIPT_PATH"

    if [[ "$UPDATE_MODE" == true ]]; then
        print_success "Backup script updated at $TARGET_SCRIPT_PATH"
    else
        print_success "Backup script installed to $TARGET_SCRIPT_PATH"
    fi
}

# Function to create systemd service
create_service() {
    if [[ "$UPDATE_MODE" == true ]]; then
        print_info "Updating systemd user service..."
    else
        print_info "Creating systemd user service..."
    fi

    # Create systemd user directory if it doesn't exist
    mkdir -p "$SYSTEMD_USER_DIR"

    # Create the service file
    cat > "$SERVICE_PATH" << EOF
[Unit]
Description=Bitwarden Backup Service
After=graphical-session.target onedriver.service
Wants=graphical-session.target onedriver.service

[Service]
Type=oneshot
ExecStart=/bin/bash -c "/bin/sleep 15 && $TARGET_SCRIPT_PATH"
EnvironmentFile=$ENV_FILE
WorkingDirectory=$HOME
Environment="PATH=$BW_DIR:/usr/local/bin:/usr/bin:/bin"
StandardOutput=append:$HOME/.bitwarden_backup.log
StandardError=append:$HOME/.bitwarden_backup.log

[Install]
WantedBy=default.target
EOF

    # Secure the service file
    chmod 600 "$SERVICE_PATH"

    if [[ "$UPDATE_MODE" == true ]]; then
        print_success "Service file updated at $SERVICE_PATH"
    else
        print_success "Service file created at $SERVICE_PATH"
    fi
    print_info "Configured PATH: $BW_DIR:/usr/local/bin:/usr/bin:/bin"
}

# Function to enable and start the service
setup_service() {
    if [[ "$UPDATE_MODE" == true ]]; then
        print_info "Reloading systemd service..."
    else
        print_info "Setting up systemd service..."
    fi

    # Reload systemd user daemon
    systemctl --user daemon-reload

    if [[ $? -ne 0 ]]; then
        print_error "Failed to reload systemd user daemon"
        exit 1
    fi

    if [[ "$UPDATE_MODE" == false ]]; then
        # Enable the service only during initial installation
        systemctl --user enable "$SERVICE_NAME"

        if [[ $? -ne 0 ]]; then
            print_error "Failed to enable service"
            exit 1
        fi

        print_success "Service enabled and configured"
    else
        print_success "Service configuration reloaded"
    fi
}

# Function to test the service
test_service() {
    if [[ "$UPDATE_MODE" == true ]]; then
        print_info "Testing updated service..."
    else
        print_info "Testing the service..."
    fi

    # Start the service
    systemctl --user start "$SERVICE_NAME"

    if [[ $? -eq 0 ]]; then
        print_success "Service test completed successfully"

        # Check if log file was created
        if [[ -f "$HOME/.bitwarden_backup.log" ]]; then
            print_info "Log file created. Recent entries:"
            tail -5 "$HOME/.bitwarden_backup.log" | sed 's/^/  /'
        fi
    else
        print_warning "Service test failed. Check the status with:"
        echo "  systemctl --user status $SERVICE_NAME"
        echo "  tail $HOME/.bitwarden_backup.log"
    fi
}

# Function to show post-install information
show_completion_info() {
    echo
    if [[ "$UPDATE_MODE" == true ]]; then
        print_success "Update completed successfully!"
    else
        print_success "Installation completed successfully!"
    fi
    echo
    echo -e "${BLUE}Service Information:${NC}"
    echo "  Service Name: $SERVICE_NAME"
    echo "  Script Location: $TARGET_SCRIPT_PATH"
    echo "  Log File: $HOME/.bitwarden_backup.log"
    echo "  Environment File: $ENV_FILE"
    echo "  Bitwarden CLI Path: $BW_PATH"
    echo
    echo -e "${BLUE}Useful Commands:${NC}"
    echo "  Check status:     systemctl --user status $SERVICE_NAME"
    echo "  Start backup:     systemctl --user start $SERVICE_NAME"
    echo "  View logs:        tail -f $HOME/.bitwarden_backup.log"
    echo "  Disable service:  systemctl --user disable $SERVICE_NAME"
    echo "  Update:           $0 --update"
    echo

    if [[ "$UPDATE_MODE" == false ]]; then
        echo -e "${BLUE}Optional: Enable Lingering${NC}"
        echo "  To run backups even when not logged in:"
        echo "  sudo loginctl enable-linger $USER"
        echo
        echo -e "${BLUE}Optional: Set up Timer for Regular Backups${NC}"
        echo "  Create a timer to run backups daily:"
        echo "  cat > $SYSTEMD_USER_DIR/bitwarden-backup.timer << 'EOF'"
        echo "  [Unit]"
        echo "  Description=Run Bitwarden Backup Daily"
        echo "  Requires=bitwarden-backup.service"
        echo "  "
        echo "  [Timer]"
        echo "  OnCalendar=daily"
        echo "  Persistent=true"
        echo "  "
        echo "  [Install]"
        echo "  WantedBy=timers.target"
        echo "  EOF"
        echo "  systemctl --user enable bitwarden-backup.timer"
        echo "  systemctl --user start bitwarden-backup.timer"
        echo
    fi
}

# Function to cleanup on error
cleanup_on_error() {
    print_warning "Cleaning up due to error..."

    # Remove files if they were created (only in install mode)
    if [[ "$UPDATE_MODE" == false ]]; then
        [[ -f "$TARGET_SCRIPT_PATH" ]] && rm -f "$TARGET_SCRIPT_PATH"
        [[ -f "$SERVICE_PATH" ]] && rm -f "$SERVICE_PATH"
        [[ -f "$ENV_FILE" ]] && rm -f "$ENV_FILE"
    fi

    # Reload systemd to remove any partial service
    systemctl --user daemon-reload 2>/dev/null
}

# Main installation function
main() {
    # Parse command line arguments first
    parse_arguments "$@"

    print_header

    # Set up error handling
    trap cleanup_on_error ERR

    # Check for existing installation
    check_existing_installation

    # Installation steps
    check_files
    check_dependencies

    if [[ "$UPDATE_MODE" == false ]]; then
        # Full installation - get credentials and create env file
        get_credentials
        create_env_file
    else
        # Update mode - skip credential collection
        print_info "Update mode: Skipping credential collection"
        print_info "Using existing environment file: $ENV_FILE"
    fi

    install_script
    create_service
    setup_service
    test_service

    # Clear sensitive variables (only if they were set)
    if [[ "$UPDATE_MODE" == false ]]; then
        unset CLIENT_ID CLIENT_SECRET MASTER_PASSWORD
    fi

    show_completion_info
}

# Run main function
main "$@"
