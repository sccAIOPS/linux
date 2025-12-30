#!/bin/bash
#
# check_requirements.sh - Verify all required tools are installed
#
# Usage: ./check_requirements.sh
#
# SPDX-License-Identifier: GPL-2.0

set -euo pipefail

# Source common library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

print_header "check_requirements.sh"

echo "Checking required tools for Linux Kernel Architecture Extraction..."
echo ""

# Tool categories
declare -A REQUIRED_TOOLS=(
    ["ctags"]="Symbol extraction"
    ["grep"]="Pattern searching"
    ["awk"]="Text processing"
    ["sed"]="Stream editing"
    ["python3"]="Python scripts"
)

declare -A OPTIONAL_TOOLS=(
    ["cscope"]="Code navigation and cross-referencing"
    ["cflow"]="Call graph generation"
    ["plantuml"]="UML diagram rendering (or java with plantuml.jar)"
    ["sphinx-build"]="Documentation building"
    ["pdflatex"]="PDF generation"
    ["dot"]="GraphViz diagram rendering"
)

declare -A PYTHON_PACKAGES=(
    ["sphinx"]="Documentation builder"
    ["sphinx_rtd_theme"]="Read the Docs theme"
    ["sphinxcontrib.plantuml"]="PlantUML integration"
)

# Check required tools
echo "=== Required Tools ==="
required_missing=0

for tool in "${!REQUIRED_TOOLS[@]}"; do
    desc="${REQUIRED_TOOLS[$tool]}"
    if command -v "$tool" &> /dev/null; then
        version=$(${tool} --version 2>&1 | head -1 || echo "unknown version")
        log_success "$tool - $desc"
        echo "         Version: $version"
    else
        log_error "$tool - $desc [NOT FOUND]"
        required_missing=$((required_missing + 1))
    fi
done

echo ""
echo "=== Optional Tools ==="

for tool in "${!OPTIONAL_TOOLS[@]}"; do
    desc="${OPTIONAL_TOOLS[$tool]}"
    if command -v "$tool" &> /dev/null; then
        version=$(${tool} --version 2>&1 | head -1 || echo "unknown version")
        log_success "$tool - $desc"
        echo "         Version: $version"
    else
        log_warn "$tool - $desc [NOT FOUND]"
    fi
done

echo ""
echo "=== Python Packages ==="

for package in "${!PYTHON_PACKAGES[@]}"; do
    desc="${PYTHON_PACKAGES[$package]}"
    if python3 -c "import ${package}" 2>/dev/null; then
        version=$(python3 -c "import ${package}; print(getattr(${package}, '__version__', 'unknown'))" 2>/dev/null || echo "unknown")
        log_success "$package - $desc"
        echo "         Version: $version"
    else
        log_warn "$package - $desc [NOT FOUND]"
    fi
done

echo ""
echo "=== Summary ==="

if [ $required_missing -gt 0 ]; then
    log_error "$required_missing required tool(s) missing!"
    echo ""
    echo "Install missing tools:"
    echo "  Debian/Ubuntu: sudo apt-get install universal-ctags cscope cflow"
    echo "  Fedora/RHEL:   sudo dnf install ctags cscope cflow"
    echo ""
    exit 1
else
    log_success "All required tools are available!"
fi

echo ""
echo "To install optional tools:"
echo ""
echo "  # Debian/Ubuntu"
echo "  sudo apt-get install universal-ctags cscope cflow plantuml graphviz"
echo "  sudo apt-get install texlive-latex-base texlive-latex-extra"
echo ""
echo "  # Python packages"
echo "  pip3 install sphinx sphinx-rtd-theme sphinxcontrib-plantuml"
echo ""

exit 0
