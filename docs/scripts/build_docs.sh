#!/bin/bash
#
# build_docs.sh - Build final documentation from extracted architecture
#
# Usage: ./build_docs.sh [OPTIONS] [output_format]
#
# SPDX-License-Identifier: GPL-2.0

set -euo pipefail

# Source common library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

# Script-specific variables
OUTPUT_FORMAT="html"  # html, pdf, latex
CLEAN_FIRST=0
OPEN_BROWSER=0
PLANTUML_JAR=""

usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS] [output_format]

Build documentation from extracted kernel architecture.

Output Formats:
    html        HTML documentation (default)
    pdf         PDF documentation (requires LaTeX)
    latex       LaTeX source files

Options:
    -c, --clean           Clean build directory before building
    -o, --open            Open result in browser (HTML only)
    --plantuml PATH       Path to plantuml.jar for diagram rendering
    -v, --verbose         Enable verbose output
    -h, --help            Show this help message

Requirements:
    - Python 3.8+
    - Sphinx (pip install sphinx sphinx-rtd-theme)
    - sphinxcontrib-plantuml (pip install sphinxcontrib-plantuml)
    - PlantUML (for diagram rendering)
    - LaTeX (for PDF output)

Examples:
    $(basename "$0")                    # Build HTML docs
    $(basename "$0") --clean html       # Clean and build HTML
    $(basename "$0") pdf                # Build PDF docs
    $(basename "$0") --open html        # Build and open in browser

EOF
}

# Parse arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -c|--clean)
                CLEAN_FIRST=1
                shift
                ;;
            -o|--open)
                OPEN_BROWSER=1
                shift
                ;;
            --plantuml)
                PLANTUML_JAR="$2"
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
            html|pdf|latex)
                OUTPUT_FORMAT="$1"
                shift
                ;;
            -*)
                log_error "Unknown option: $1"
                usage
                exit 1
                ;;
            *)
                OUTPUT_FORMAT="$1"
                shift
                ;;
        esac
    done
}

# Check for required tools
check_build_requirements() {
    local missing=0
    
    log_info "Checking build requirements..."
    
    # Python
    if ! check_tool python3; then
        log_error "Python 3 is required"
        missing=$((missing + 1))
    fi
    
    # Sphinx
    if ! python3 -c "import sphinx" 2>/dev/null; then
        log_warn "Sphinx not found. Install with: pip install sphinx sphinx-rtd-theme"
        missing=$((missing + 1))
    fi
    
    # PlantUML support
    if ! python3 -c "import sphinxcontrib.plantuml" 2>/dev/null; then
        log_warn "sphinxcontrib-plantuml not found. Install with: pip install sphinxcontrib-plantuml"
    fi
    
    # LaTeX for PDF
    if [ "$OUTPUT_FORMAT" = "pdf" ] || [ "$OUTPUT_FORMAT" = "latex" ]; then
        if ! check_tool pdflatex; then
            log_warn "pdflatex not found. Install texlive for PDF output"
            if [ "$OUTPUT_FORMAT" = "pdf" ]; then
                missing=$((missing + 1))
            fi
        fi
    fi
    
    if [ $missing -gt 0 ]; then
        log_error "Missing $missing required tool(s)"
        return 1
    fi
    
    log_success "All required tools available"
    return 0
}

# Create Sphinx configuration
create_sphinx_conf() {
    local conf_file="${ARCH_DIR}/conf.py"
    
    log_info "Creating Sphinx configuration..."
    
    cat > "$conf_file" << 'EOF'
# Configuration file for the Sphinx documentation builder.
# Linux Kernel Architecture Documentation

import os
import sys

# -- Project information -----------------------------------------------------

project = 'Linux Kernel Architecture'
copyright = '2025, Linux Kernel Community'
author = 'Architecture Extraction Agent'
release = '6.19-rc3'
version = '6.19'

# -- General configuration ---------------------------------------------------

extensions = [
    'sphinx.ext.autodoc',
    'sphinx.ext.viewcode',
    'sphinx.ext.todo',
    'sphinx.ext.graphviz',
]

# Try to enable PlantUML support
try:
    import sphinxcontrib.plantuml
    extensions.append('sphinxcontrib.plantuml')
    
    # Configure PlantUML
    plantuml = 'java -jar /usr/share/plantuml/plantuml.jar'
    plantuml_output_format = 'svg'
except ImportError:
    pass

templates_path = ['_templates']
exclude_patterns = ['_build', 'Thumbs.db', '.DS_Store', 'scripts']

# The master toctree document
master_doc = 'index'

# -- Options for HTML output -------------------------------------------------

html_theme = 'sphinx_rtd_theme'
html_static_path = ['_static']

# Theme options
html_theme_options = {
    'collapse_navigation': False,
    'sticky_navigation': True,
    'navigation_depth': 4,
    'includehidden': True,
    'titles_only': False
}

# -- Options for LaTeX output ------------------------------------------------

latex_elements = {
    'papersize': 'a4paper',
    'pointsize': '11pt',
    'preamble': r'''
\usepackage{charter}
\usepackage[defaultsans]{lato}
\usepackage{inconsolata}
''',
}

latex_documents = [
    (master_doc, 'LinuxKernelArchitecture.tex',
     'Linux Kernel Architecture Documentation',
     'Linux Kernel Community', 'manual'),
]

# -- Extension configuration -------------------------------------------------

todo_include_todos = True

# Graphviz configuration
graphviz_output_format = 'svg'
EOF
    
    log_success "Created: $conf_file"
}

# Create main index.rst
create_index() {
    local index_file="${ARCH_DIR}/index.rst"
    
    log_info "Creating main index..."
    
    cat > "$index_file" << 'EOF'
=========================================
Linux Kernel Architecture Documentation
=========================================

.. toctree::
   :maxdepth: 2
   :caption: Overview

   introduction

.. toctree::
   :maxdepth: 2
   :caption: Core Subsystems

EOF
    
    # Add discovered subsystems
    for subsys_dir in "${ARCH_DIR}"/*/; do
        if [ -d "$subsys_dir" ] && [ -f "${subsys_dir}/overview.rst" ]; then
            local subsys=$(basename "$subsys_dir")
            echo "   ${subsys}/overview" >> "$index_file"
        fi
    done
    
    cat >> "$index_file" << 'EOF'

Indices and tables
==================

* :ref:`genindex`
* :ref:`search`
EOF
    
    log_success "Created: $index_file"
}

# Create introduction page
create_introduction() {
    local intro_file="${ARCH_DIR}/introduction.rst"
    
    log_info "Creating introduction..."
    
    cat > "$intro_file" << 'EOF'
============
Introduction
============

This documentation provides a comprehensive architectural overview of the Linux
kernel. It is automatically generated from source code analysis and aims to help
developers understand the internal structure and design of the kernel.

Document Structure
==================

The documentation is organized by kernel subsystem:

* **Process Management** - Scheduling, process lifecycle, signals
* **Memory Management** - Page allocation, virtual memory, caching
* **File Systems** - VFS layer, file operations, caching
* **Networking** - Protocol stack, socket layer, device interface
* **Block Layer** - Block I/O, request processing, schedulers
* **Device Drivers** - Driver model, device tree, buses

Each subsystem section includes:

* High-level architecture overview
* Component breakdown and relationships
* Key data structures
* Important code flows (sequence diagrams)
* State machines for stateful components

How to Read
===========

1. Start with the subsystem overview for high-level understanding
2. Examine component diagrams for structural relationships
3. Review sequence diagrams for dynamic behavior
4. Reference data structure documentation for implementation details

Diagram Types
=============

This documentation uses several UML diagram types:

C4 Diagrams
-----------

* **Context** - System-level view showing external interactions
* **Container** - Major subsystem breakdown
* **Component** - Internal component structure

Behavioral Diagrams
-------------------

* **Sequence** - Function call flows for key operations
* **State Machine** - State transitions for stateful entities

Structural Diagrams
-------------------

* **Class/Structure** - Data structure relationships
* **Entity-Relationship** - Database-style relationships

Generation
==========

This documentation was generated using custom extraction scripts that analyze:

* Source code structure and symbols
* Header file definitions
* Function signatures and call relationships
* Data structure definitions

For more information on the extraction process, see the ``docs/scripts/`` directory.
EOF
    
    log_success "Created: $intro_file"
}

# Ensure static directories exist
setup_static_dirs() {
    ensure_dir "${ARCH_DIR}/_static"
    ensure_dir "${ARCH_DIR}/_templates"
    
    # Create a minimal CSS file
    cat > "${ARCH_DIR}/_static/custom.css" << 'EOF'
/* Custom styles for kernel architecture documentation */

.rst-content .highlight pre {
    font-size: 0.85em;
}

.rst-content table.docutils td {
    vertical-align: top;
}
EOF
}

# Build documentation
build_docs() {
    local format=$1
    local output_dir="${BUILD_DIR}/${format}"
    
    log_info "Building $format documentation..."
    
    # Clean if requested
    if [ $CLEAN_FIRST -eq 1 ] && [ -d "$output_dir" ]; then
        log_info "Cleaning previous build..."
        rm -rf "$output_dir"
    fi
    
    ensure_dir "$output_dir"
    
    # Change to architecture directory
    cd "${ARCH_DIR}"
    
    # Run Sphinx
    local sphinx_opts=""
    if [ $VERBOSE -eq 1 ]; then
        sphinx_opts="-v"
    fi
    
    case $format in
        html)
            sphinx-build -b html $sphinx_opts . "$output_dir"
            ;;
        pdf)
            sphinx-build -b latex $sphinx_opts . "$output_dir"
            # Build PDF from LaTeX
            cd "$output_dir"
            make
            ;;
        latex)
            sphinx-build -b latex $sphinx_opts . "$output_dir"
            ;;
        *)
            log_error "Unknown format: $format"
            return 1
            ;;
    esac
    
    log_success "Build complete: $output_dir"
}

# Open in browser
open_result() {
    local index="${BUILD_DIR}/html/index.html"
    
    if [ -f "$index" ]; then
        log_info "Opening in browser..."
        
        if command -v xdg-open &> /dev/null; then
            xdg-open "$index"
        elif command -v open &> /dev/null; then
            open "$index"
        else
            log_warn "No browser opener found. Open manually: $index"
        fi
    else
        log_error "Index file not found: $index"
    fi
}

# Main execution
main() {
    parse_args "$@"
    
    print_header "build_docs.sh"
    
    log_info "Output format: $OUTPUT_FORMAT"
    log_info "Build directory: $BUILD_DIR"
    
    # Check requirements
    if ! check_build_requirements; then
        exit 1
    fi
    
    # Initialize structure
    init_docs_structure
    
    # Create Sphinx configuration files
    create_sphinx_conf
    create_index
    create_introduction
    setup_static_dirs
    
    # Build documentation
    build_docs "$OUTPUT_FORMAT"
    
    # Open in browser if requested
    if [ $OPEN_BROWSER -eq 1 ] && [ "$OUTPUT_FORMAT" = "html" ]; then
        open_result
    fi
    
    echo ""
    log_success "Documentation build complete!"
    echo ""
    echo "Output: ${BUILD_DIR}/${OUTPUT_FORMAT}/"
    
    if [ "$OUTPUT_FORMAT" = "html" ]; then
        echo "View: file://${BUILD_DIR}/html/index.html"
    fi
}

main "$@"
