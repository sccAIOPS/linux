#!/bin/bash
#
# extract_symbols.sh - Extract function and structure symbols from kernel source
#
# Usage: ./extract_symbols.sh [OPTIONS] <path>
#
# SPDX-License-Identifier: GPL-2.0

set -euo pipefail

# Source common library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

# Script-specific variables
OUTPUT_FORMAT="text"  # text, json, rst
OUTPUT_FILE=""
INCLUDE_STATIC=0
FUNCTION_FILTER=""
STRUCT_FILTER=""
VERBOSE=0

usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS] <path>

Extract function and structure symbols from Linux kernel source code.

Arguments:
    path        Relative path to file or directory to analyze

Options:
    -o, --output FILE     Write output to FILE (default: stdout)
    -f, --format FORMAT   Output format: text, json, rst (default: text)
    --function NAME       Extract specific function(s) matching pattern
    --struct NAME         Extract specific struct(s) matching pattern
    --include-static      Include static (non-exported) functions
    -v, --verbose         Enable verbose output
    -h, --help            Show this help message

Examples:
    $(basename "$0") kernel/sched/core.c
    $(basename "$0") -f json -o symbols.json mm/
    $(basename "$0") --function "alloc*" mm/page_alloc.c
    $(basename "$0") --struct task_struct include/linux/sched.h

EOF
}

# Parse arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -o|--output)
                OUTPUT_FILE="$2"
                shift 2
                ;;
            -f|--format)
                OUTPUT_FORMAT="$2"
                shift 2
                ;;
            --function)
                FUNCTION_FILTER="$2"
                shift 2
                ;;
            --struct)
                STRUCT_FILTER="$2"
                shift 2
                ;;
            --include-static)
                INCLUDE_STATIC=1
                shift
                ;;
            -v|--verbose)
                VERBOSE=1
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            -*)
                log_error "Unknown option: $1"
                usage
                exit 1
                ;;
            *)
                TARGET_PATH="$1"
                shift
                ;;
        esac
    done
    
    if [ -z "${TARGET_PATH:-}" ]; then
        log_error "No path specified"
        usage
        exit 1
    fi
}

# Extract symbols using ctags
extract_with_ctags() {
    local path=$1
    local full_path="${PROJECT_ROOT}/${path}"
    
    log_info "Extracting symbols from: $path"
    
    # Determine if path is file or directory
    local find_args=""
    if [ -d "$full_path" ]; then
        find_args="$(find "$full_path" -name '*.c' -o -name '*.h' 2>/dev/null | tr '\n' ' ')"
    else
        find_args="$full_path"
    fi
    
    if [ -z "$find_args" ]; then
        log_error "No C files found in: $path"
        return 1
    fi
    
    # Generate tags
    ctags -x --c-kinds=fstd $find_args 2>/dev/null
}

# Extract functions with details
extract_functions_detailed() {
    local path=$1
    local full_path="${PROJECT_ROOT}/${path}"
    
    if [ -f "$full_path" ]; then
        local files="$full_path"
    else
        local files=$(find "$full_path" -name "*.c" 2>/dev/null)
    fi
    
    for file in $files; do
        local rel_path="${file#$PROJECT_ROOT/}"
        
        # Extract function definitions
        ctags -x --c-kinds=f "$file" 2>/dev/null | while read name type line file_path rest; do
            # Apply filter if specified
            if [ -n "$FUNCTION_FILTER" ]; then
                if [[ ! "$name" == $FUNCTION_FILTER ]]; then
                    continue
                fi
            fi
            
            # Check if exported
            local exported="no"
            if grep -q "EXPORT_SYMBOL.*${name}" "$file" 2>/dev/null; then
                exported="yes"
            fi
            
            # Check if static
            local is_static="no"
            local func_line=$(sed -n "${line}p" "$file" 2>/dev/null)
            if echo "$func_line" | grep -q "^static"; then
                is_static="yes"
                if [ $INCLUDE_STATIC -eq 0 ] && [ "$exported" = "no" ]; then
                    continue
                fi
            fi
            
            # Get signature (simplified)
            local signature=$(sed -n "${line}p" "$file" 2>/dev/null | sed 's/{.*//')
            
            case $OUTPUT_FORMAT in
                json)
                    echo "{\"name\": \"$name\", \"file\": \"$rel_path\", \"line\": $line, \"exported\": \"$exported\", \"static\": \"$is_static\", \"signature\": \"$signature\"}"
                    ;;
                rst)
                    echo ".. c:function:: $signature"
                    echo ""
                    echo "   :file: \`$rel_path\`"
                    echo "   :line: $line"
                    echo "   :exported: $exported"
                    echo ""
                    ;;
                *)
                    printf "%-40s %-50s %5d  exported=%s static=%s\n" "$name" "$rel_path" "$line" "$exported" "$is_static"
                    ;;
            esac
        done
    done
}

# Extract structures with details
extract_structs_detailed() {
    local path=$1
    local full_path="${PROJECT_ROOT}/${path}"
    
    if [ -f "$full_path" ]; then
        local files="$full_path"
    else
        local files=$(find "$full_path" -name "*.h" -o -name "*.c" 2>/dev/null)
    fi
    
    for file in $files; do
        local rel_path="${file#$PROJECT_ROOT/}"
        
        # Extract struct definitions
        ctags -x --c-kinds=s "$file" 2>/dev/null | while read name type line file_path rest; do
            # Apply filter if specified
            if [ -n "$STRUCT_FILTER" ]; then
                if [[ ! "$name" == $STRUCT_FILTER ]]; then
                    continue
                fi
            fi
            
            case $OUTPUT_FORMAT in
                json)
                    echo "{\"name\": \"$name\", \"file\": \"$rel_path\", \"line\": $line, \"type\": \"struct\"}"
                    ;;
                rst)
                    echo ".. c:struct:: $name"
                    echo ""
                    echo "   :file: \`$rel_path\`"
                    echo "   :line: $line"
                    echo ""
                    ;;
                *)
                    printf "struct %-35s %-50s %5d\n" "$name" "$rel_path" "$line"
                    ;;
            esac
        done
    done
}

# Generate summary statistics
generate_summary() {
    local path=$1
    local full_path="${PROJECT_ROOT}/${path}"
    
    local c_files=$(find "$full_path" -name "*.c" 2>/dev/null | wc -l)
    local h_files=$(find "$full_path" -name "*.h" 2>/dev/null | wc -l)
    local total_lines=$(find "$full_path" -name "*.c" -o -name "*.h" 2>/dev/null | xargs wc -l 2>/dev/null | tail -1 | awk '{print $1}')
    local func_count=$(ctags -x --c-kinds=f $(find "$full_path" -name "*.c" 2>/dev/null) 2>/dev/null | wc -l)
    local struct_count=$(ctags -x --c-kinds=s $(find "$full_path" -name "*.h" -o -name "*.c" 2>/dev/null) 2>/dev/null | wc -l)
    
    case $OUTPUT_FORMAT in
        json)
            cat << EOF
{
  "summary": {
    "path": "$path",
    "c_files": $c_files,
    "h_files": $h_files,
    "total_lines": ${total_lines:-0},
    "functions": $func_count,
    "structs": $struct_count
  }
}
EOF
            ;;
        rst)
            cat << EOF
Summary
-------

.. list-table::
   :header-rows: 1

   * - Metric
     - Value
   * - Path
     - \`$path\`
   * - C Files
     - $c_files
   * - Header Files
     - $h_files
   * - Total Lines
     - ${total_lines:-0}
   * - Functions
     - $func_count
   * - Structures
     - $struct_count
EOF
            ;;
        *)
            echo "=============================="
            echo "Summary for: $path"
            echo "=============================="
            echo "C Files:      $c_files"
            echo "Header Files: $h_files"
            echo "Total Lines:  ${total_lines:-0}"
            echo "Functions:    $func_count"
            echo "Structures:   $struct_count"
            echo "=============================="
            ;;
    esac
}

# Main execution
main() {
    parse_args "$@"
    
    print_header "extract_symbols.sh"
    
    # Validate target path
    if ! validate_kernel_path "$TARGET_PATH"; then
        exit 1
    fi
    
    # Check required tools
    if ! check_tool ctags; then
        log_error "ctags is required but not installed"
        log_info "Install with: sudo apt-get install universal-ctags"
        exit 1
    fi
    
    # Redirect output if file specified
    if [ -n "$OUTPUT_FILE" ]; then
        exec > "$OUTPUT_FILE"
        log_info "Writing output to: $OUTPUT_FILE" >&2
    fi
    
    # Generate output based on format
    case $OUTPUT_FORMAT in
        json)
            echo "{"
            echo "  \"extraction_date\": \"$(timestamp)\","
            echo "  \"path\": \"$TARGET_PATH\","
            ;;
        rst)
            rst_header "Symbol Extraction: $TARGET_PATH"
            echo ""
            echo "Generated: $(timestamp)"
            echo ""
            ;;
    esac
    
    # Generate summary
    generate_summary "$TARGET_PATH"
    
    echo ""
    
    # Extract functions
    if [ $VERBOSE -eq 1 ]; then
        log_info "Extracting functions..." >&2
    fi
    
    case $OUTPUT_FORMAT in
        rst)
            rst_section "Functions"
            ;;
        text)
            echo ""
            echo "=== FUNCTIONS ==="
            ;;
    esac
    
    extract_functions_detailed "$TARGET_PATH"
    
    # Extract structures
    if [ $VERBOSE -eq 1 ]; then
        log_info "Extracting structures..." >&2
    fi
    
    case $OUTPUT_FORMAT in
        rst)
            rst_section "Structures"
            ;;
        text)
            echo ""
            echo "=== STRUCTURES ==="
            ;;
    esac
    
    extract_structs_detailed "$TARGET_PATH"
    
    # Close JSON
    if [ "$OUTPUT_FORMAT" = "json" ]; then
        echo "}"
    fi
    
    log_success "Symbol extraction complete" >&2
}

main "$@"
