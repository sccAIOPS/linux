#!/bin/bash
#
# generate_call_graph.sh - Generate function call graphs for kernel code
#
# Usage: ./generate_call_graph.sh [OPTIONS] <path>
#
# SPDX-License-Identifier: GPL-2.0

set -euo pipefail

# Source common library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

# Script-specific variables
OUTPUT_FILE=""
OUTPUT_FORMAT="dot"  # dot, text, plantuml
ROOT_FUNCTION=""
MAX_DEPTH=5
INCLUDE_STATIC=0
EXCLUDE_PATTERN=""

usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS] <path>

Generate function call graphs for Linux kernel source code.

Arguments:
    path        Relative path to file or directory to analyze

Options:
    -o, --output FILE     Write output to FILE (default: stdout)
    -f, --format FORMAT   Output format: dot, text, plantuml (default: dot)
    -r, --root FUNC       Start call graph from specific function
    -d, --depth N         Maximum depth for call graph (default: 5)
    --include-static      Include static functions
    --exclude PATTERN     Exclude functions matching pattern
    -v, --verbose         Enable verbose output
    -h, --help            Show this help message

Examples:
    $(basename "$0") kernel/fork.c
    $(basename "$0") -r do_fork -d 3 kernel/fork.c
    $(basename "$0") -f plantuml -o fork_calls.puml kernel/fork.c
    $(basename "$0") --exclude "__.*" mm/page_alloc.c

Output Formats:
    dot       - GraphViz DOT format (can be rendered with 'dot -Tpng')
    text      - Simple text tree format
    plantuml  - PlantUML sequence diagram

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
            -r|--root)
                ROOT_FUNCTION="$2"
                shift 2
                ;;
            -d|--depth)
                MAX_DEPTH="$2"
                shift 2
                ;;
            --include-static)
                INCLUDE_STATIC=1
                shift
                ;;
            --exclude)
                EXCLUDE_PATTERN="$2"
                shift 2
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

# Generate call graph using cflow (if available)
generate_cflow_graph() {
    local path=$1
    local full_path="${PROJECT_ROOT}/${path}"
    
    log_info "Generating call graph with cflow..."
    
    local files=""
    if [ -f "$full_path" ]; then
        files="$full_path"
    else
        files=$(find "$full_path" -name "*.c" 2>/dev/null | head -50)  # Limit files
    fi
    
    if [ -z "$files" ]; then
        log_error "No C files found"
        return 1
    fi
    
    local cflow_opts="--depth=$MAX_DEPTH"
    
    if [ -n "$ROOT_FUNCTION" ]; then
        cflow_opts="$cflow_opts --main=$ROOT_FUNCTION"
    fi
    
    if [ $INCLUDE_STATIC -eq 0 ]; then
        cflow_opts="$cflow_opts --omit-arguments"
    fi
    
    # Generate the call graph
    cflow $cflow_opts $files 2>/dev/null
}

# Parse cflow output to DOT format
cflow_to_dot() {
    local title="${1:-Call Graph}"
    
    echo "digraph CallGraph {"
    echo "    rankdir=TB;"
    echo "    node [shape=box, style=filled, fillcolor=lightblue];"
    echo "    label=\"$title\";"
    echo "    labelloc=t;"
    echo ""
    
    local prev_indent=0
    local stack=()
    
    while IFS= read -r line; do
        # Skip empty lines
        [ -z "$line" ] && continue
        
        # Count leading spaces (indentation level)
        local stripped="${line#"${line%%[![:space:]]*}"}"
        local indent=$(( (${#line} - ${#stripped}) / 4 ))
        
        # Extract function name
        local func=$(echo "$stripped" | sed 's/().*//;s/ .*//')
        
        # Skip excluded functions
        if [ -n "$EXCLUDE_PATTERN" ] && [[ "$func" =~ $EXCLUDE_PATTERN ]]; then
            continue
        fi
        
        # Update stack based on indentation
        while [ ${#stack[@]} -gt $indent ]; do
            unset 'stack[-1]'
        done
        
        # Add edge from parent to this function
        if [ ${#stack[@]} -gt 0 ] && [ -n "${stack[-1]:-}" ]; then
            echo "    \"${stack[-1]}\" -> \"$func\";"
        fi
        
        # Push current function onto stack
        stack+=("$func")
        
    done
    
    echo "}"
}

# Parse cflow output to PlantUML sequence diagram
cflow_to_plantuml() {
    local title="${1:-Call Sequence}"
    
    echo "@startuml"
    echo "title $title"
    echo ""
    echo "skinparam sequenceArrowThickness 2"
    echo "skinparam roundcorner 20"
    echo ""
    
    # Collect unique functions first
    local -A participants
    local -a call_stack
    local prev_indent=0
    
    while IFS= read -r line; do
        [ -z "$line" ] && continue
        
        local stripped="${line#"${line%%[![:space:]]*}"}"
        local indent=$(( (${#line} - ${#stripped}) / 4 ))
        local func=$(echo "$stripped" | sed 's/().*//;s/ .*//')
        
        [ -n "$EXCLUDE_PATTERN" ] && [[ "$func" =~ $EXCLUDE_PATTERN ]] && continue
        
        participants["$func"]=1
    done
    
    # Declare participants
    for func in "${!participants[@]}"; do
        echo "participant \"$func\" as ${func//[^a-zA-Z0-9_]/_}"
    done
    echo ""
    
    # Reset and generate calls
    call_stack=()
    
    while IFS= read -r line; do
        [ -z "$line" ] && continue
        
        local stripped="${line#"${line%%[![:space:]]*}"}"
        local indent=$(( (${#line} - ${#stripped}) / 4 ))
        local func=$(echo "$stripped" | sed 's/().*//;s/ .*//')
        
        [ -n "$EXCLUDE_PATTERN" ] && [[ "$func" =~ $EXCLUDE_PATTERN ]] && continue
        
        # Adjust call stack
        while [ ${#call_stack[@]} -gt $indent ]; do
            local last="${call_stack[-1]}"
            unset 'call_stack[-1]'
            if [ ${#call_stack[@]} -gt 0 ]; then
                echo "return"
            fi
        done
        
        # Generate call
        if [ ${#call_stack[@]} -gt 0 ]; then
            local caller="${call_stack[-1]}"
            echo "${caller//[^a-zA-Z0-9_]/_} -> ${func//[^a-zA-Z0-9_]/_}: $func()"
            echo "activate ${func//[^a-zA-Z0-9_]/_}"
        fi
        
        call_stack+=("$func")
        
    done
    
    # Close remaining activations
    while [ ${#call_stack[@]} -gt 1 ]; do
        echo "return"
        unset 'call_stack[-1]'
    done
    
    echo "@enduml"
}

# Simple grep-based call extraction (fallback)
extract_calls_grep() {
    local file=$1
    local func=$2
    
    # Find function body and extract called functions
    awk -v func="$func" '
        BEGIN { in_func = 0; brace_count = 0 }
        
        # Match function start
        $0 ~ "^[a-zA-Z_].*" func "\\(" { in_func = 1 }
        
        in_func {
            # Count braces
            gsub(/[^{}]/, "")
            brace_count += gsub(/{/, "{")
            brace_count -= gsub(/}/, "}")
            
            # Extract function calls
            if (match($0, /[a-zA-Z_][a-zA-Z0-9_]*\s*\(/)) {
                call = substr($0, RSTART, RLENGTH-1)
                gsub(/\s*$/, "", call)
                if (call != func && call !~ /^(if|while|for|switch|sizeof|return)$/) {
                    print call
                }
            }
            
            if (brace_count == 0 && in_func) { in_func = 0 }
        }
    ' "$file" | sort -u
}

# Generate simple text tree
generate_text_tree() {
    local path=$1
    local full_path="${PROJECT_ROOT}/${path}"
    
    if command -v cflow &> /dev/null; then
        generate_cflow_graph "$path"
    else
        log_warn "cflow not found, using simplified extraction"
        
        local files=""
        if [ -f "$full_path" ]; then
            files="$full_path"
        else
            files=$(find "$full_path" -name "*.c" 2>/dev/null)
        fi
        
        for file in $files; do
            local rel_path="${file#$PROJECT_ROOT/}"
            echo "=== $rel_path ==="
            
            # Get all functions in file
            ctags -x --c-kinds=f "$file" 2>/dev/null | while read name rest; do
                echo "$name"
                extract_calls_grep "$file" "$name" | while read call; do
                    echo "    -> $call"
                done
            done
            echo ""
        done
    fi
}

# Main execution
main() {
    parse_args "$@"
    
    print_header "generate_call_graph.sh"
    
    # Validate target path
    if ! validate_kernel_path "$TARGET_PATH"; then
        exit 1
    fi
    
    # Redirect output if file specified
    if [ -n "$OUTPUT_FILE" ]; then
        exec > "$OUTPUT_FILE"
        log_info "Writing output to: $OUTPUT_FILE" >&2
    fi
    
    local title="Call Graph: $TARGET_PATH"
    if [ -n "$ROOT_FUNCTION" ]; then
        title="Call Graph: $ROOT_FUNCTION in $TARGET_PATH"
    fi
    
    case $OUTPUT_FORMAT in
        dot)
            if command -v cflow &> /dev/null; then
                generate_cflow_graph "$TARGET_PATH" | cflow_to_dot "$title"
            else
                log_error "cflow required for DOT output"
                log_info "Install with: sudo apt-get install cflow"
                exit 1
            fi
            ;;
        plantuml)
            if command -v cflow &> /dev/null; then
                generate_cflow_graph "$TARGET_PATH" | cflow_to_plantuml "$title"
            else
                log_error "cflow required for PlantUML output"
                exit 1
            fi
            ;;
        text)
            generate_text_tree "$TARGET_PATH"
            ;;
        *)
            log_error "Unknown output format: $OUTPUT_FORMAT"
            exit 1
            ;;
    esac
    
    log_success "Call graph generation complete" >&2
}

main "$@"
