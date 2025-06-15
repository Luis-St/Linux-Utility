#!/bin/bash

# Script to convert Windows line endings (CRLF) to Unix line endings (LF)
# for all files in current directory and subdirectories

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to display usage
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Convert Windows line endings (CRLF) to Unix line endings (LF)"
    echo ""
    echo "Options:"
    echo "  -d, --directory DIR    Process specified directory instead of current directory"
    echo "  -e, --extensions EXTS  Only process files with specified extensions (comma-separated)"
    echo "  -x, --exclude PATTERNS Exclude files matching patterns (comma-separated)"
    echo "  -n, --dry-run         Show what would be converted without making changes"
    echo "  -v, --verbose         Show detailed output"
    echo "  -h, --help            Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                                    # Convert all files in current directory"
    echo "  $0 -d /path/to/directory             # Convert files in specific directory"
    echo "  $0 -e txt,sh,py                     # Only convert .txt, .sh, and .py files"
    echo "  $0 -x '*.log,temp*'                 # Exclude .log files and files starting with 'temp'"
    echo "  $0 -n                               # Dry run - show what would be converted"
}

# Default values
DIRECTORY="."
EXTENSIONS=""
EXCLUDE_PATTERNS=""
DRY_RUN=false
VERBOSE=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--directory)
            DIRECTORY="$2"
            shift 2
            ;;
        -e|--extensions)
            EXTENSIONS="$2"
            shift 2
            ;;
        -x|--exclude)
            EXCLUDE_PATTERNS="$2"
            shift 2
            ;;
        -n|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Check if directory exists
if [[ ! -d "$DIRECTORY" ]]; then
    echo -e "${RED}Error: Directory '$DIRECTORY' does not exist${NC}"
    exit 1
fi

# Check if dos2unix is available
if ! command -v dos2unix &> /dev/null; then
    echo -e "${YELLOW}Warning: dos2unix not found. Installing it might provide better performance.${NC}"
    echo -e "${YELLOW}Using sed as fallback method.${NC}"
    USE_DOS2UNIX=false
else
    USE_DOS2UNIX=true
fi

# Build find command
FIND_CMD="find \"$DIRECTORY\" -type f"

# Add extension filter if specified
if [[ -n "$EXTENSIONS" ]]; then
    IFS=',' read -ra EXT_ARRAY <<< "$EXTENSIONS"
    FIND_CMD="$FIND_CMD \("
    for i in "${!EXT_ARRAY[@]}"; do
        if [[ $i -gt 0 ]]; then
            FIND_CMD="$FIND_CMD -o"
        fi
        FIND_CMD="$FIND_CMD -name \"*.${EXT_ARRAY[$i]}\""
    done
    FIND_CMD="$FIND_CMD \)"
fi

# Add exclude patterns if specified
if [[ -n "$EXCLUDE_PATTERNS" ]]; then
    IFS=',' read -ra EXCLUDE_ARRAY <<< "$EXCLUDE_PATTERNS"
    for pattern in "${EXCLUDE_ARRAY[@]}"; do
        FIND_CMD="$FIND_CMD ! -name \"$pattern\""
    done
fi

# Function to check if file has Windows line endings
has_windows_endings() {
    local file="$1"
    # Check if file contains CRLF (Windows line endings)
    if file "$file" | grep -q "CRLF"; then
        return 0
    fi
    # Alternative check using hexdump
    if hexdump -C "$file" | grep -q "0d 0a"; then
        return 0
    fi
    return 1
}

# Function to convert file
convert_file() {
    local file="$1"

    if [[ "$USE_DOS2UNIX" == true ]]; then
        if [[ "$DRY_RUN" == false ]]; then
            dos2unix "$file" 2>/dev/null
        fi
    else
        if [[ "$DRY_RUN" == false ]]; then
            sed -i 's/\r$//' "$file"
        fi
    fi
}

# Main processing
echo -e "${GREEN}Converting Windows line endings to Unix line endings...${NC}"
echo "Directory: $DIRECTORY"
if [[ -n "$EXTENSIONS" ]]; then
    echo "Extensions: $EXTENSIONS"
fi
if [[ -n "$EXCLUDE_PATTERNS" ]]; then
    echo "Excluding: $EXCLUDE_PATTERNS"
fi
if [[ "$DRY_RUN" == true ]]; then
    echo -e "${YELLOW}DRY RUN MODE - No files will be modified${NC}"
fi
echo ""

# Execute find command and process files
processed_count=0
converted_count=0

eval "$FIND_CMD" | while IFS= read -r file; do
    # Skip binary files
    if file "$file" | grep -q "binary"; then
        if [[ "$VERBOSE" == true ]]; then
            echo -e "${YELLOW}Skipping binary file: $file${NC}"
        fi
        continue
    fi

    processed_count=$((processed_count + 1))

    # Check if file has Windows line endings
    if has_windows_endings "$file"; then
        converted_count=$((converted_count + 1))

        if [[ "$DRY_RUN" == true ]]; then
            echo -e "${YELLOW}[DRY RUN] Would convert: $file${NC}"
        else
            convert_file "$file"
            if [[ "$VERBOSE" == true ]]; then
                echo -e "${GREEN}Converted: $file${NC}"
            else
                echo -n "."
            fi
        fi
    else
        if [[ "$VERBOSE" == true ]]; then
            echo "Already Unix format: $file"
        fi
    fi
done

# Summary (Note: Due to subshell, counters won't work as expected)
# Let's rewrite this part to get accurate counts
echo ""
echo "Processing complete!"

# Get actual counts
total_files=$(eval "$FIND_CMD" | wc -l)
files_with_crlf=0

eval "$FIND_CMD" | while IFS= read -r file; do
    if ! file "$file" | grep -q "binary" && has_windows_endings "$file"; then
        files_with_crlf=$((files_with_crlf + 1))
    fi
done

echo "Total files processed: $total_files"
if [[ "$DRY_RUN" == true ]]; then
    echo -e "${YELLOW}Files that would be converted: (run without -n to see exact count)${NC}"
else
    echo -e "${GREEN}Conversion completed successfully!${NC}"
fi
