#!/bin/bash

# Bitwarden Backup Script
# Creates an encrypted backup from self-hosted Bitwarden instance

# Configuration
BW_SERVER="https://bitwarden.luis-st.net"
BASE_BACKUP_DIR="/home/luis/OneDrive/Backup/Passwords"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if required tools are installed
check_dependencies() {
    print_status "Checking dependencies..."

    if ! command -v bw &> /dev/null; then
        print_error "Bitwarden CLI (bw) is not installed. Please install it first."
        echo "Install with: npm install -g @bitwarden/cli"
        exit 1
    fi
}

# Function to read credentials securely
get_credentials() {
    # Get Client ID
    echo -n "Enter your Bitwarden Client ID: "
    read CLIENT_ID

    # Get Client Secret
    echo -n "Enter your Bitwarden Client Secret: "
    read -s CLIENT_SECRET
    echo
}

# Function to get account password securely
get_password() {
    echo -n "Enter your Bitwarden account password for encryption: "
    read -s MASTER_PASSWORD
    echo
}

# Function to create backup directory structure
create_backup_directory() {
    local date_folder=$(date +"%Y-%m-%d")
    BACKUP_DIR="$BASE_BACKUP_DIR/$date_folder"

    if [[ ! -d "$BACKUP_DIR" ]]; then
        mkdir -p "$BACKUP_DIR"
        print_status "Created backup directory: $BACKUP_DIR"
    else
        print_status "Using existing backup directory: $BACKUP_DIR"
    fi
}

# Function to configure Bitwarden CLI
configure_bitwarden() {
    print_status "Configuring Bitwarden CLI..."

    # Set server URL
    bw config server "$BW_SERVER"

    # Set client credentials
    export BW_CLIENTID="$CLIENT_ID"
    export BW_CLIENTSECRET="$CLIENT_SECRET"

    print_status "Bitwarden CLI configured for server: $BW_SERVER"
}

# Function to login to Bitwarden
login_bitwarden() {
    print_status "Logging into Bitwarden..."

    # Login using API key
    BW_SESSION=$(bw login --apikey --raw)

    if [[ $? -eq 0 ]]; then
        export BW_SESSION
        print_status "Successfully logged into Bitwarden"
    else
        print_error "Failed to login to Bitwarden"
        exit 1
    fi
}

# Function to unlock vault
unlock_vault() {
    print_status "Unlocking vault..."

    BW_SESSION=$(echo "$MASTER_PASSWORD" | bw unlock --raw)

    if [[ $? -eq 0 ]]; then
        export BW_SESSION
        print_status "Vault unlocked successfully"
    else
        print_error "Failed to unlock vault. Please check your password."
        exit 1
    fi
}

# Function to create encrypted backup
create_backup() {
    local timestamp=$(date +"%Y%m%d%H%M%S")
    local backup_filename="bitwarden_encrypted_export_${timestamp}.json"
    local backup_path="$BACKUP_DIR/$backup_filename"

    print_status "Creating encrypted backup..."

    # Create encrypted export
    echo "$MASTER_PASSWORD" | bw export --format encrypted_json --raw > "$backup_path"

    if [[ $? -eq 0 && -f "$backup_path" ]]; then
        local file_size=$(du -h "$backup_path" | cut -f1)
        print_status "Backup created successfully: $backup_path"
        print_status "File size: $file_size"
    else
        print_error "Failed to create backup"
        exit 1
    fi
}

# Function to logout from Bitwarden
logout_bitwarden() {
    print_status "Logging out from Bitwarden..."
    bw logout
}

# Function to cleanup sensitive variables
cleanup() {
    unset BW_SESSION
    unset CLIENT_ID
    unset CLIENT_SECRET
    unset MASTER_PASSWORD
    unset BW_CLIENTID
    unset BW_CLIENTSECRET
}

# Main execution
main() {
    print_status "Starting Bitwarden backup process..."

    # Check dependencies
    check_dependencies

    # Get credentials
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

    print_status "Backup process completed successfully!"
}

# Trap to ensure cleanup on script exit
trap cleanup EXIT

# Run main function
main "$@"
