# Linux Kernel Architecture Documentation Scripts

This directory contains scripts for extracting and documenting Linux kernel architecture.

## Overview

These scripts automate the process of:
1. Extracting symbols (functions, structures) from kernel source
2. Generating call graphs and dependency maps
3. Creating PlantUML diagrams (C4, sequence, state, class, ERD)
4. Building final documentation in HTML/PDF format

## Quick Start

```bash
# 1. Check that required tools are installed
./check_requirements.sh

# 2. Analyze a kernel subsystem (e.g., memory management)
./analyze_subsystem.sh memory

# 3. Build HTML documentation
./build_docs.sh html

# 4. Open in browser
firefox ../build/html/index.html
```

## Scripts Reference

### Core Scripts

| Script | Purpose | Example |
|--------|---------|---------|
| `analyze_subsystem.sh` | Complete subsystem analysis | `./analyze_subsystem.sh process` |
| `extract_symbols.sh` | Extract functions/structs | `./extract_symbols.sh kernel/fork.c` |
| `extract_structures.py` | Parse C structures | `./extract_structures.py include/linux/sched.h` |
| `generate_call_graph.sh` | Function call graphs | `./generate_call_graph.sh -r do_fork kernel/fork.c` |
| `generate_diagrams.py` | PlantUML diagrams | `./generate_diagrams.py --type c4-container --subsystem memory` |
| `build_docs.sh` | Build final documentation | `./build_docs.sh html` |
| `check_requirements.sh` | Verify tool availability | `./check_requirements.sh` |

### Library Files

| File | Purpose |
|------|---------|
| `lib/common.sh` | Shared bash functions |
| `lib/parser_utils.py` | Python parsing utilities |

## Available Subsystems

The following kernel subsystems are supported:

| Subsystem | Description | Source Paths |
|-----------|-------------|--------------|
| `process` | Process management | `kernel/sched/`, `kernel/fork.c` |
| `memory` | Memory management | `mm/` |
| `filesystem` | Virtual File System | `fs/` |
| `network` | Networking stack | `net/` |
| `block` | Block I/O layer | `block/` |
| `drivers` | Device driver model | `drivers/base/` |
| `security` | Security modules | `security/` |
| `locking` | Synchronization | `kernel/locking/` |
| `irq` | Interrupt handling | `kernel/irq/` |
| `time` | Timekeeping | `kernel/time/` |

## Diagram Types

### C4 Model Diagrams
- **Context**: High-level system view
- **Container**: Subsystem breakdown
- **Component**: Internal components

### Behavioral Diagrams
- **Sequence**: Function call flows (syscall, fork, page_fault, file_read, network_send)
- **State**: Entity state machines (task, page, socket, request)

### Structural Diagrams
- **Class**: Data structure definitions
- **ERD**: Entity relationships

## Output Structure

```
docs/
├── architecture/              # Generated documentation
│   ├── index.rst             # Main index
│   ├── introduction.rst      # Overview
│   ├── conf.py               # Sphinx configuration
│   ├── {subsystem}/          # Per-subsystem docs
│   │   ├── overview.rst
│   │   ├── components.rst
│   │   ├── data-structures.rst
│   │   ├── symbols.txt
│   │   └── diagrams/
│   │       ├── c4-container.puml
│   │       ├── c4-component.puml
│   │       ├── sequence-*.puml
│   │       ├── state-*.puml
│   │       └── class-*.puml
│   └── examples/             # Code examples
├── diagrams/                 # Standalone diagrams
├── build/                    # Built documentation
│   ├── html/
│   └── pdf/
└── scripts/                  # This directory
```

## Requirements

### Required Tools
- `ctags` (universal-ctags recommended)
- `grep`, `awk`, `sed`
- `python3` (>= 3.8)

### Optional Tools
- `cscope` - Code navigation
- `cflow` - Call graph generation
- `plantuml` - Diagram rendering
- `sphinx` - Documentation building
- `texlive` - PDF generation

### Installation

```bash
# Debian/Ubuntu
sudo apt-get install universal-ctags cscope cflow plantuml graphviz
sudo apt-get install python3-pip
pip3 install sphinx sphinx-rtd-theme sphinxcontrib-plantuml

# For PDF output
sudo apt-get install texlive-latex-base texlive-latex-extra
```

## Usage Examples

### Extract Symbols from a File
```bash
# Text output
./extract_symbols.sh kernel/fork.c

# JSON output
./extract_symbols.sh -f json -o fork_symbols.json kernel/fork.c

# RST output with all functions
./extract_symbols.sh -f rst --include-static mm/page_alloc.c
```

### Generate Call Graphs
```bash
# DOT format (for GraphViz)
./generate_call_graph.sh -f dot -o fork.dot kernel/fork.c

# PlantUML sequence diagram
./generate_call_graph.sh -f plantuml -r do_fork kernel/fork.c

# Text tree format
./generate_call_graph.sh -f text mm/
```

### Extract Structure Definitions
```bash
# Simple text list
./extract_structures.py include/linux/sched.h

# PlantUML class diagram
./extract_structures.py -f plantuml -o sched.puml include/linux/sched.h

# JSON with relationships
./extract_structures.py -f json --recursive mm/

# Filter by pattern
./extract_structures.py --filter "vm_*" include/linux/mm_types.h
```

### Generate Architecture Diagrams
```bash
# C4 Context (entire kernel)
./generate_diagrams.py --type c4-context

# C4 Container (specific subsystem)
./generate_diagrams.py --type c4-container --subsystem memory

# Sequence diagram
./generate_diagrams.py --type sequence --flow fork

# State machine
./generate_diagrams.py --type state --entity task

# Entity-Relationship
./generate_diagrams.py --type erd --subsystem process
```

### Full Subsystem Analysis
```bash
# Basic analysis
./analyze_subsystem.sh memory

# With code examples
./analyze_subsystem.sh --with-examples process

# Custom output directory
./analyze_subsystem.sh -o /tmp/kernel-docs filesystem
```

### Build Documentation
```bash
# Build HTML
./build_docs.sh html

# Clean and build
./build_docs.sh --clean html

# Build and open in browser
./build_docs.sh --open html

# Build PDF
./build_docs.sh pdf
```

## Customization

### Adding New Subsystems

Edit `analyze_subsystem.sh` and add entries to:
- `SUBSYSTEM_PATHS` - Source file paths
- `SUBSYSTEM_HEADERS` - Header file paths

### Adding New Diagram Types

Edit `generate_diagrams.py` and:
1. Add new methods to `DiagramGenerator` class
2. Update the `main()` function to expose new diagram types

### Custom Templates

Modify files in `lib/` to change output templates:
- `parser_utils.py`: PlantUML and RST generation
- `common.sh`: Bash helper functions

## Troubleshooting

### "ctags not found"
Install universal-ctags (not exuberant-ctags):
```bash
sudo apt-get install universal-ctags
```

### "Sphinx build fails"
Ensure all Python dependencies are installed:
```bash
pip3 install sphinx sphinx-rtd-theme sphinxcontrib-plantuml
```

### "PlantUML diagrams not rendering"
Install PlantUML and Java:
```bash
sudo apt-get install plantuml default-jre
```

### "PDF build fails"
Install LaTeX:
```bash
sudo apt-get install texlive-latex-base texlive-latex-extra texlive-fonts-recommended
```

## License

These scripts are licensed under GPL-2.0, consistent with the Linux kernel.

## Contributing

1. Follow kernel coding style for shell scripts
2. Use Python type hints where applicable
3. Document new functions and scripts
4. Test with multiple kernel versions

---

*Part of the Linux Kernel Architecture Documentation Project*
