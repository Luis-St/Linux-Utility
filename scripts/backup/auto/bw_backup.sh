#!/bin/bash

# Bitwarden Backup Script - Service Version
# Creates an encrypted backup from self-hosted Bitwarden instance
# Designed to run as a systemd user service

# Configuration
BW_SERVER="https://bitwarden.luis-st.net"
BASE_BACKUP_DIR="/home/luis/OneDrive/Backup/Passwords"
LOG_FILE="/home/luis/.bitwarden_backup.log"

# Function to log messages
log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
}

log_info() {
    log_message "INFO" "$1"
}

log_warning() {
    log_message "WARNING" "$1"
}

log_error() {
    log_message "ERROR" "$1"
}

# Function to check if required tools are installed
check_dependencies() {
    log_info "Checking dependencies..."

    if ! command -v bw &> /dev/null; then
        log_error "Bitwarden CLI (bw) is not installed. Please install it first."
        log_error "Install with: npm install -g @bitwarden/cli"
        exit 1
    fi

    log_info "All dependencies satisfied"
}

# Function to read credentials from environment variables
get_credentials() {
    log_info "Reading credentials from environment variables..."

    if [[ -z "$BW_CLIENT_ID" ]]; then
        log_error "BW_CLIENT_ID environment variable is not set"
        exit 1
    fi

    if [[ -z "$BW_CLIENT_SECRET" ]]; then
        log_error "BW_CLIENT_SECRET environment variable is not set"
        exit 1
    fi

    if [[ -z "$BW_MASTER_PASSWORD" ]]; then
        log_error "BW_MASTER_PASSWORD environment variable is not set"
        exit 1
    fi

    CLIENT_ID="$BW_CLIENT_ID"
    CLIENT_SECRET="$BW_CLIENT_SECRET"
    MASTER_PASSWORD="$BW_MASTER_PASSWORD"

    log_info "Credentials loaded from environment variables"
}

# Function to get account password securely
get_password() {
    # Password is now read from environment variable in get_credentials()
    log_info "Master password loaded from environment"
}

# Function to create backup directory structure
create_backup_directory() {
    local date_folder=$(date +"%Y-%m-%d")
    BACKUP_DIR="$BASE_BACKUP_DIR/$date_folder"

    if [[ ! -d "$BACKUP_DIR" ]]; then
        mkdir -p "$BACKUP_DIR"
        if [[ $? -eq 0 ]]; then
            log_info "Created backup directory: $BACKUP_DIR"
        else
            log_error "Failed to create backup directory: $BACKUP_DIR"
            exit 1
        fi
    else
        log_info "Using existing backup directory: $BACKUP_DIR"
    fi
}

# Function to configure Bitwarden CLI
configure_bitwarden() {
    log_info "Configuring Bitwarden CLI..."

    # Set server URL
    bw config server "$BW_SERVER" >> "$LOG_FILE" 2>&1

    # Set client credentials
    export BW_CLIENTID="$CLIENT_ID"
    export BW_CLIENTSECRET="$CLIENT_SECRET"

    log_info "Bitwarden CLI configured for server: $BW_SERVER"
}

# Function to login to Bitwarden
login_bitwarden() {
    log_info "Logging into Bitwarden..."

    # Login using client credentials
    BW_SESSION=$(bw login --apikey --raw 2>>"$LOG_FILE")

    if [[ $? -eq 0 && -n "$BW_SESSION" ]]; then
        export BW_SESSION
        log_info "Successfully logged into Bitwarden"
    else
        log_error "Failed to login to Bitwarden"
        exit 1
    fi
}

# Function to unlock vault
unlock_vault() {
    log_info "Unlocking vault..."

    BW_SESSION=$(echo "$MASTER_PASSWORD" | bw unlock --raw 2>>"$LOG_FILE")

    if [[ $? -eq 0 && -n "$BW_SESSION" ]]; then
        export BW_SESSION
        log_info "Vault unlocked successfully"
    else
        log_error "Failed to unlock vault. Please check your password."
        exit 1
    fi
}

# Function to create encrypted backup
create_backup() {
    local timestamp=$(date +"%Y%m%d%H%M%S")
    local backup_filename="bitwarden_encrypted_export_${timestamp}.json"
    local backup_path="$BACKUP_DIR/$backup_filename"

    log_info "Creating encrypted backup..."

    # Create encrypted export
    echo "$MASTER_PASSWORD" | bw export --format encrypted_json --raw > "$backup_path" 2>>"$LOG_FILE"

    if [[ $? -eq 0 && -f "$backup_path" ]]; then
        local file_size=$(du -h "$backup_path" | cut -f1)
        log_info "Backup created successfully: $backup_path"
        log_info "File size: $file_size"
    else
        log_error "Failed to create backup"
        exit 1
    fi
}

# Function to logout from Bitwarden
logout_bitwarden() {
    log_info "Logging out from Bitwarden..."
    bw logout >> "$LOG_FILE" 2>&1
}

# Function to cleanup sensitive variables
cleanup() {
    unset BW_SESSION
    unset CLIENT_ID
    unset CLIENT_SECRET
    unset MASTER_PASSWORD
    unset BW_CLIENTID
    unset BW_CLIENTSECRET
    unset BW_CLIENT_ID
    unset BW_CLIENT_SECRET
    unset BW_MASTER_PASSWORD
}

# Function to rotate log file if it gets too large
rotate_log() {
    if [[ -f "$LOG_FILE" ]]; then
        local log_size=$(stat -c%s "$LOG_FILE" 2>/dev/null || echo 0)
        # Rotate if log file is larger than 10MB
        if [[ $log_size -gt 10485760 ]]; then
            mv "$LOG_FILE" "${LOG_FILE}.old"
            log_info "Log file rotated due to size"
        fi
    fi
}

# Main execution
main() {
    # Rotate log if needed
    rotate_log

    log_info "=== Starting Bitwarden backup process ==="

    # Check dependencies
    check_dependencies

    # Get credentials from environment
    get_credentials
    get_password

    # Create backup directory
    create_backup_directory

    # Configure and login to Bitwarden
    configure_bitwarden
    login_bitwarden
    unlock_vault

    # Create the backup
    create_backup

    # Cleanup
    logout_bitwarden
    cleanup

    log_info "=== Backup process completed successfully ==="
}

# Trap to ensure cleanup on script exit
trap cleanup EXIT

# Run main function
main "$@"
