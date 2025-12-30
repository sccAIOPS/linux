#!/bin/bash
#
# Linux Kernel Architecture Extraction - Common Library
# Provides shared functions for all extraction scripts
#
# SPDX-License-Identifier: GPL-2.0

# Color definitions for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Project root detection
# Don't override SCRIPT_DIR if already set by the calling script
_COMMON_SH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${_COMMON_SH_DIR}/../../.." && pwd)"

# Default paths
DOCS_DIR="${PROJECT_ROOT}/docs"
ARCH_DIR="${DOCS_DIR}/architecture"
DIAGRAMS_DIR="${DOCS_DIR}/diagrams"
EXAMPLES_DIR="${DOCS_DIR}/examples"
BUILD_DIR="${DOCS_DIR}/build"

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

# Check if required tools are installed
check_tool() {
    local tool=$1
    if ! command -v "$tool" &> /dev/null; then
        log_error "Required tool '$tool' is not installed"
        return 1
    fi
    return 0
}

check_required_tools() {
    local tools=("ctags" "cscope" "grep" "awk" "sed")
    local missing=0
    
    for tool in "${tools[@]}"; do
        if ! check_tool "$tool"; then
            missing=$((missing + 1))
        fi
    done
    
    if [ $missing -gt 0 ]; then
        log_error "$missing required tool(s) missing"
        return 1
    fi
    
    log_success "All required tools are available"
    return 0
}

# Ensure directory exists
ensure_dir() {
    local dir=$1
    if [ ! -d "$dir" ]; then
        mkdir -p "$dir"
        log_info "Created directory: $dir"
    fi
}

# Initialize documentation directories
init_docs_structure() {
    ensure_dir "${ARCH_DIR}"
    ensure_dir "${DIAGRAMS_DIR}/c4"
    ensure_dir "${DIAGRAMS_DIR}/sequence"
    ensure_dir "${DIAGRAMS_DIR}/class"
    ensure_dir "${DIAGRAMS_DIR}/state"
    ensure_dir "${EXAMPLES_DIR}"
    ensure_dir "${BUILD_DIR}"
}

# Validate path is within kernel source
validate_kernel_path() {
    local path=$1
    local full_path="${PROJECT_ROOT}/${path}"
    
    if [ ! -e "$full_path" ]; then
        log_error "Path does not exist: $path"
        return 1
    fi
    
    # Ensure it's within project root (security check)
    case "$(realpath "$full_path")" in
        "${PROJECT_ROOT}"*)
            return 0
            ;;
        *)
            log_error "Path is outside project root: $path"
            return 1
            ;;
    esac
}

# Extract subsystem name from path
get_subsystem_name() {
    local path=$1
    # Remove leading/trailing slashes and get first component
    echo "$path" | sed 's|^/||;s|/$||' | cut -d'/' -f1
}

# Generate safe filename from path
path_to_filename() {
    local path=$1
    echo "$path" | sed 's|/|_|g;s|\.c$||;s|\.h$||'
}

# Count lines of code (excluding comments and blanks)
count_code_lines() {
    local file=$1
    if [ -f "$file" ]; then
        grep -v '^\s*$' "$file" | grep -v '^\s*//' | grep -v '^\s*\*' | wc -l
    else
        echo 0
    fi
}

# Extract copyright header from file
extract_copyright() {
    local file=$1
    head -20 "$file" | grep -i "copyright\|SPDX" | head -3
}

# Find all .c files in a directory
find_c_files() {
    local dir=$1
    find "${PROJECT_ROOT}/${dir}" -name "*.c" -type f 2>/dev/null
}

# Find all .h files in a directory
find_h_files() {
    local dir=$1
    find "${PROJECT_ROOT}/${dir}" -name "*.h" -type f 2>/dev/null
}

# Extract function names from a C file
extract_functions() {
    local file=$1
    ctags -x --c-kinds=f "$file" 2>/dev/null | awk '{print $1}'
}

# Extract struct names from a C/H file
extract_structs() {
    local file=$1
    ctags -x --c-kinds=s "$file" 2>/dev/null | awk '{print $1}'
}

# Extract macro definitions
extract_macros() {
    local file=$1
    ctags -x --c-kinds=d "$file" 2>/dev/null | awk '{print $1}'
}

# Check if function is exported
is_exported_symbol() {
    local func=$1
    local file=$2
    grep -q "EXPORT_SYMBOL.*${func}" "$file" 2>/dev/null
}

# Get function signature from file
get_function_signature() {
    local func=$1
    local file=$2
    # Use ctags to get line number, then extract signature
    local line=$(ctags -x --c-kinds=f "$file" 2>/dev/null | grep "^${func}\s" | awk '{print $3}')
    if [ -n "$line" ]; then
        sed -n "${line}p" "$file" | sed 's/{.*//'
    fi
}

# Generate timestamp for output
timestamp() {
    date "+%Y-%m-%d %H:%M:%S"
}

# Print script header
print_header() {
    local script_name=$1
    echo "============================================================"
    echo " Linux Kernel Architecture Extractor"
    echo " Script: $script_name"
    echo " Time: $(timestamp)"
    echo "============================================================"
    echo
}

# Print usage for a script
print_usage() {
    local script=$1
    local usage=$2
    echo "Usage: $script $usage"
    echo
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo "  -v, --verbose  Enable verbose output"
    echo "  -q, --quiet    Suppress non-essential output"
}

# Parse common arguments
parse_common_args() {
    VERBOSE=0
    QUIET=0
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -v|--verbose)
                VERBOSE=1
                shift
                ;;
            -q|--quiet)
                QUIET=1
                shift
                ;;
            -h|--help)
                return 2  # Signal to show help
                ;;
            *)
                shift
                ;;
        esac
    done
    return 0
}

# Create RST header
rst_header() {
    local title=$1
    local char=${2:-=}
    local len=${#title}
    printf '%*s\n' "$len" '' | tr ' ' "$char"
    echo "$title"
    printf '%*s\n' "$len" '' | tr ' ' "$char"
}

# Create RST section header
rst_section() {
    local title=$1
    local char=${2:--}
    local len=${#title}
    echo
    echo "$title"
    printf '%*s\n' "$len" '' | tr ' ' "$char"
    echo
}

# Export functions for use by sourcing scripts
export -f log_info log_success log_warn log_error
export -f check_tool check_required_tools
export -f ensure_dir init_docs_structure
export -f validate_kernel_path get_subsystem_name path_to_filename
export -f count_code_lines extract_copyright
export -f find_c_files find_h_files
export -f extract_functions extract_structs extract_macros
export -f is_exported_symbol get_function_signature
export -f timestamp print_header print_usage parse_common_args
export -f rst_header rst_section
