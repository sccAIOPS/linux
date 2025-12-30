#!/bin/bash
#
# analyze_subsystem.sh - Complete architecture analysis for a kernel subsystem
#
# Usage: ./analyze_subsystem.sh [OPTIONS] <subsystem>
#
# SPDX-License-Identifier: GPL-2.0

set -euo pipefail

# Source common library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

# Script-specific variables
OUTPUT_DIR=""
GENERATE_DIAGRAMS=1
GENERATE_RST=1
GENERATE_EXAMPLES=0
SUBSYSTEM=""

# Subsystem path mappings
declare -A SUBSYSTEM_PATHS=(
    ["process"]="kernel/sched kernel/fork.c kernel/exit.c kernel/signal.c"
    ["memory"]="mm/"
    ["filesystem"]="fs/"
    ["network"]="net/"
    ["block"]="block/"
    ["drivers"]="drivers/base/"
    ["security"]="security/"
    ["locking"]="kernel/locking/"
    ["irq"]="kernel/irq/"
    ["time"]="kernel/time/"
)

# Subsystem header paths
declare -A SUBSYSTEM_HEADERS=(
    ["process"]="include/linux/sched.h include/linux/sched/signal.h"
    ["memory"]="include/linux/mm.h include/linux/mm_types.h include/linux/slab.h"
    ["filesystem"]="include/linux/fs.h include/linux/dcache.h include/linux/namei.h"
    ["network"]="include/linux/socket.h include/net/sock.h include/linux/skbuff.h"
    ["block"]="include/linux/blkdev.h include/linux/bio.h include/linux/blk-mq.h"
    ["drivers"]="include/linux/device.h include/linux/driver.h"
    ["security"]="include/linux/security.h include/linux/lsm_hooks.h"
    ["locking"]="include/linux/spinlock.h include/linux/mutex.h include/linux/rwsem.h"
)

usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS] <subsystem>

Perform complete architecture analysis for a Linux kernel subsystem.

Available Subsystems:
    process     - Process management (scheduler, fork, signals)
    memory      - Memory management (page allocator, slab, vmalloc)
    filesystem  - Virtual File System and file operations
    network     - Networking stack
    block       - Block I/O layer
    drivers     - Device driver model
    security    - Security framework (LSM)
    locking     - Synchronization primitives
    irq         - Interrupt handling
    time        - Timekeeping and timers

Options:
    -o, --output DIR      Output directory (default: docs/architecture/<subsystem>)
    --no-diagrams         Skip diagram generation
    --no-rst              Skip RST documentation generation
    --with-examples       Generate code examples
    -v, --verbose         Enable verbose output
    -h, --help            Show this help message

Examples:
    $(basename "$0") memory
    $(basename "$0") -o /tmp/docs process
    $(basename "$0") --with-examples filesystem

Output Structure:
    <output_dir>/
    ├── overview.rst          # High-level architecture overview
    ├── components.rst        # Component breakdown
    ├── data-structures.rst   # Key structures documented
    ├── symbols.txt           # Extracted symbols
    ├── diagrams/
    │   ├── c4-container.puml
    │   ├── c4-component.puml
    │   ├── sequence-*.puml
    │   ├── class-*.puml
    │   └── state-*.puml
    └── examples/             # (if --with-examples)
        └── *.c

EOF
}

# Parse arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -o|--output)
                OUTPUT_DIR="$2"
                shift 2
                ;;
            --no-diagrams)
                GENERATE_DIAGRAMS=0
                shift
                ;;
            --no-rst)
                GENERATE_RST=0
                shift
                ;;
            --with-examples)
                GENERATE_EXAMPLES=1
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
                SUBSYSTEM="$1"
                shift
                ;;
        esac
    done
    
    if [ -z "$SUBSYSTEM" ]; then
        log_error "No subsystem specified"
        usage
        exit 1
    fi
    
    if [ -z "${SUBSYSTEM_PATHS[$SUBSYSTEM]:-}" ]; then
        log_error "Unknown subsystem: $SUBSYSTEM"
        echo "Available subsystems: ${!SUBSYSTEM_PATHS[*]}"
        exit 1
    fi
    
    # Set default output directory
    if [ -z "$OUTPUT_DIR" ]; then
        OUTPUT_DIR="${ARCH_DIR}/${SUBSYSTEM}"
    fi
}

# Generate overview RST document
generate_overview() {
    local subsystem=$1
    local output_file="${OUTPUT_DIR}/overview.rst"
    
    log_info "Generating overview document..."
    
    local title
    case $subsystem in
        process) title="Process Management Architecture" ;;
        memory) title="Memory Management Architecture" ;;
        filesystem) title="Virtual File System Architecture" ;;
        network) title="Networking Stack Architecture" ;;
        block) title="Block I/O Layer Architecture" ;;
        drivers) title="Device Driver Model Architecture" ;;
        security) title="Linux Security Module Architecture" ;;
        locking) title="Synchronization Primitives Architecture" ;;
        irq) title="Interrupt Handling Architecture" ;;
        time) title="Timekeeping Architecture" ;;
        *) title="${subsystem^} Architecture" ;;
    esac
    
    cat > "$output_file" << EOF
$(rst_header "$title")

.. contents:: Table of Contents
   :depth: 3
   :local:

Overview
--------

This document describes the architecture of the Linux kernel's ${subsystem} subsystem.

**Source Paths:**

$(for path in ${SUBSYSTEM_PATHS[$subsystem]}; do echo "* \`\`$path\`\`"; done)

**Key Headers:**

$(for header in ${SUBSYSTEM_HEADERS[$subsystem]:-}; do echo "* \`\`$header\`\`"; done)

Architecture Diagram
--------------------

.. uml:: diagrams/c4-container.puml

Components
----------

See :doc:\`components\` for detailed component breakdown.

Data Structures
---------------

See :doc:\`data-structures\` for key data structure documentation.

.. toctree::
   :maxdepth: 2
   :caption: Contents:

   components
   data-structures

Generated
---------

This documentation was auto-generated on $(date "+%Y-%m-%d %H:%M:%S").

EOF
    
    log_success "Created: $output_file"
}

# Generate components RST document
generate_components() {
    local subsystem=$1
    local output_file="${OUTPUT_DIR}/components.rst"
    
    log_info "Generating components document..."
    
    cat > "$output_file" << EOF
$(rst_header "${subsystem^} Components" "=")

.. contents:: Table of Contents
   :depth: 2
   :local:

Component Overview
------------------

.. uml:: diagrams/c4-component.puml

EOF
    
    # Add component sections based on subsystem
    for path in ${SUBSYSTEM_PATHS[$subsystem]}; do
        local name=$(basename "$path" .c)
        echo "" >> "$output_file"
        echo "$name" >> "$output_file"
        printf '%*s\n' ${#name} '' | tr ' ' '-' >> "$output_file"
        echo "" >> "$output_file"
        echo "**Path:** \`\`$path\`\`" >> "$output_file"
        echo "" >> "$output_file"
        
        # Add function count if file exists
        local full_path="${PROJECT_ROOT}/${path}"
        if [ -f "$full_path" ]; then
            local func_count=$(ctags -x --c-kinds=f "$full_path" 2>/dev/null | wc -l)
            echo "**Functions:** $func_count" >> "$output_file"
            echo "" >> "$output_file"
        fi
    done
    
    log_success "Created: $output_file"
}

# Generate data structures RST document
generate_data_structures() {
    local subsystem=$1
    local output_file="${OUTPUT_DIR}/data-structures.rst"
    
    log_info "Generating data structures document..."
    
    cat > "$output_file" << EOF
$(rst_header "${subsystem^} Data Structures" "=")

.. contents:: Table of Contents
   :depth: 2
   :local:

Key Structures
--------------

EOF
    
    # Extract structures from headers
    for header in ${SUBSYSTEM_HEADERS[$subsystem]:-}; do
        local full_path="${PROJECT_ROOT}/${header}"
        if [ -f "$full_path" ]; then
            local header_name=$(basename "$header" .h)
            echo "" >> "$output_file"
            echo "From \`\`$header\`\`:" >> "$output_file"
            echo "" >> "$output_file"
            echo ".. uml:: diagrams/class-${header_name}.puml" >> "$output_file"
            echo "" >> "$output_file"
            
            ctags -x --c-kinds=s "$full_path" 2>/dev/null | head -20 | while read name rest; do
                echo "* \`\`struct $name\`\`" >> "$output_file"
            done
        fi
    done
    
    log_success "Created: $output_file"
}

# Generate PlantUML diagrams
generate_diagrams() {
    local subsystem=$1
    local diagrams_dir="${OUTPUT_DIR}/diagrams"
    
    log_info "Generating diagrams..."
    
    ensure_dir "$diagrams_dir"
    
    # C4 Container diagram
    "${SCRIPT_DIR}/generate_diagrams.py" \
        --type c4-container \
        --subsystem "$subsystem" \
        --output "${diagrams_dir}/c4-container.puml" 2>/dev/null || true
    
    # C4 Component diagram
    "${SCRIPT_DIR}/generate_diagrams.py" \
        --type c4-component \
        --subsystem "$subsystem" \
        --output "${diagrams_dir}/c4-component.puml" 2>/dev/null || true
    
    # State diagrams (subsystem-specific)
    case $subsystem in
        process)
            "${SCRIPT_DIR}/generate_diagrams.py" \
                --type state --entity task \
                --output "${diagrams_dir}/state-task.puml" 2>/dev/null || true
            "${SCRIPT_DIR}/generate_diagrams.py" \
                --type sequence --flow fork \
                --output "${diagrams_dir}/sequence-fork.puml" 2>/dev/null || true
            "${SCRIPT_DIR}/generate_diagrams.py" \
                --type erd --subsystem process \
                --output "${diagrams_dir}/erd-process.puml" 2>/dev/null || true
            ;;
        memory)
            "${SCRIPT_DIR}/generate_diagrams.py" \
                --type state --entity page \
                --output "${diagrams_dir}/state-page.puml" 2>/dev/null || true
            "${SCRIPT_DIR}/generate_diagrams.py" \
                --type sequence --flow page_fault \
                --output "${diagrams_dir}/sequence-page-fault.puml" 2>/dev/null || true
            "${SCRIPT_DIR}/generate_diagrams.py" \
                --type erd --subsystem memory \
                --output "${diagrams_dir}/erd-memory.puml" 2>/dev/null || true
            ;;
        filesystem)
            "${SCRIPT_DIR}/generate_diagrams.py" \
                --type sequence --flow file_read \
                --output "${diagrams_dir}/sequence-file-read.puml" 2>/dev/null || true
            "${SCRIPT_DIR}/generate_diagrams.py" \
                --type erd --subsystem filesystem \
                --output "${diagrams_dir}/erd-filesystem.puml" 2>/dev/null || true
            ;;
        network)
            "${SCRIPT_DIR}/generate_diagrams.py" \
                --type state --entity socket \
                --output "${diagrams_dir}/state-socket.puml" 2>/dev/null || true
            "${SCRIPT_DIR}/generate_diagrams.py" \
                --type sequence --flow network_send \
                --output "${diagrams_dir}/sequence-network-send.puml" 2>/dev/null || true
            ;;
        block)
            "${SCRIPT_DIR}/generate_diagrams.py" \
                --type state --entity request \
                --output "${diagrams_dir}/state-request.puml" 2>/dev/null || true
            ;;
    esac
    
    # Structure diagrams
    for header in ${SUBSYSTEM_HEADERS[$subsystem]:-}; do
        local header_name=$(basename "$header" .h)
        "${SCRIPT_DIR}/extract_structures.py" \
            --format plantuml \
            --output "${diagrams_dir}/class-${header_name}.puml" \
            "$header" 2>/dev/null || true
    done
    
    log_success "Diagrams generated in: $diagrams_dir"
}

# Extract symbols to text file
extract_symbols() {
    local subsystem=$1
    local output_file="${OUTPUT_DIR}/symbols.txt"
    
    log_info "Extracting symbols..."
    
    echo "# Symbols for ${subsystem} subsystem" > "$output_file"
    echo "# Generated: $(timestamp)" >> "$output_file"
    echo "" >> "$output_file"
    
    for path in ${SUBSYSTEM_PATHS[$subsystem]}; do
        "${SCRIPT_DIR}/extract_symbols.sh" "$path" >> "$output_file" 2>/dev/null || true
    done
    
    log_success "Created: $output_file"
}

# Generate example code files
generate_examples() {
    local subsystem=$1
    local examples_dir="${OUTPUT_DIR}/examples"
    
    log_info "Generating example code..."
    
    ensure_dir "$examples_dir"
    
    case $subsystem in
        process)
            cat > "${examples_dir}/fork_example.c" << 'EOF'
/*
 * fork_example.c - Demonstrate process creation
 *
 * This example shows basic fork() usage and process lifecycle.
 *
 * Compile: gcc -o fork_example fork_example.c
 * Run: ./fork_example
 */

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/wait.h>
#include <sys/types.h>

int main(void)
{
    pid_t pid;
    int status;

    printf("Parent process: PID=%d\n", getpid());

    /* Create child process */
    pid = fork();

    if (pid < 0) {
        /* Fork failed */
        perror("fork");
        exit(EXIT_FAILURE);
    } else if (pid == 0) {
        /* Child process */
        printf("Child process: PID=%d, PPID=%d\n", getpid(), getppid());
        
        /* Do some work */
        sleep(1);
        
        printf("Child exiting\n");
        exit(EXIT_SUCCESS);
    } else {
        /* Parent process */
        printf("Parent: created child with PID=%d\n", pid);
        
        /* Wait for child to complete */
        if (waitpid(pid, &status, 0) == -1) {
            perror("waitpid");
            exit(EXIT_FAILURE);
        }

        if (WIFEXITED(status)) {
            printf("Parent: child exited with status %d\n", 
                   WEXITSTATUS(status));
        }
    }

    return 0;
}
EOF
            ;;
        memory)
            cat > "${examples_dir}/mmap_example.c" << 'EOF'
/*
 * mmap_example.c - Demonstrate memory mapping
 *
 * This example shows basic mmap() usage for anonymous and file mappings.
 *
 * Compile: gcc -o mmap_example mmap_example.c
 * Run: ./mmap_example
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <sys/stat.h>

#define PAGE_SIZE 4096

int main(void)
{
    void *addr;
    int fd;
    struct stat sb;

    /* Anonymous mapping example */
    printf("=== Anonymous Mapping ===\n");
    
    addr = mmap(NULL, PAGE_SIZE, 
                PROT_READ | PROT_WRITE,
                MAP_PRIVATE | MAP_ANONYMOUS,
                -1, 0);
    
    if (addr == MAP_FAILED) {
        perror("mmap anonymous");
        exit(EXIT_FAILURE);
    }

    printf("Anonymous mapping at: %p\n", addr);
    
    /* Write to the mapping */
    strcpy(addr, "Hello from mmap!");
    printf("Content: %s\n", (char *)addr);

    /* Unmap */
    if (munmap(addr, PAGE_SIZE) == -1) {
        perror("munmap");
    }

    /* File mapping example */
    printf("\n=== File Mapping ===\n");
    
    fd = open("/etc/passwd", O_RDONLY);
    if (fd == -1) {
        perror("open");
        exit(EXIT_FAILURE);
    }

    if (fstat(fd, &sb) == -1) {
        perror("fstat");
        close(fd);
        exit(EXIT_FAILURE);
    }

    addr = mmap(NULL, sb.st_size,
                PROT_READ,
                MAP_PRIVATE,
                fd, 0);

    if (addr == MAP_FAILED) {
        perror("mmap file");
        close(fd);
        exit(EXIT_FAILURE);
    }

    printf("File mapping at: %p, size: %ld\n", addr, sb.st_size);
    printf("First 50 bytes: %.50s...\n", (char *)addr);

    munmap(addr, sb.st_size);
    close(fd);

    return 0;
}
EOF
            ;;
        filesystem)
            cat > "${examples_dir}/vfs_example.c" << 'EOF'
/*
 * vfs_example.c - Demonstrate VFS operations
 *
 * This example shows basic file operations that interact with VFS.
 *
 * Compile: gcc -o vfs_example vfs_example.c
 * Run: ./vfs_example
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/stat.h>
#include <dirent.h>

#define BUFFER_SIZE 256

int main(void)
{
    int fd;
    char buffer[BUFFER_SIZE];
    ssize_t bytes;
    struct stat sb;
    DIR *dir;
    struct dirent *entry;

    /* File creation and writing */
    printf("=== File Operations ===\n");
    
    fd = open("test_file.txt", O_CREAT | O_WRONLY | O_TRUNC, 0644);
    if (fd == -1) {
        perror("open for write");
        exit(EXIT_FAILURE);
    }

    const char *message = "Hello from VFS example!\n";
    bytes = write(fd, message, strlen(message));
    printf("Wrote %zd bytes\n", bytes);
    close(fd);

    /* File reading */
    fd = open("test_file.txt", O_RDONLY);
    if (fd == -1) {
        perror("open for read");
        exit(EXIT_FAILURE);
    }

    bytes = read(fd, buffer, sizeof(buffer) - 1);
    buffer[bytes] = '\0';
    printf("Read %zd bytes: %s", bytes, buffer);
    close(fd);

    /* File stat */
    printf("\n=== File Stat ===\n");
    
    if (stat("test_file.txt", &sb) == -1) {
        perror("stat");
    } else {
        printf("Size: %ld bytes\n", sb.st_size);
        printf("Inode: %ld\n", sb.st_ino);
        printf("Mode: %o\n", sb.st_mode & 0777);
    }

    /* Directory listing */
    printf("\n=== Directory Listing ===\n");
    
    dir = opendir(".");
    if (dir == NULL) {
        perror("opendir");
        exit(EXIT_FAILURE);
    }

    printf("Contents of current directory:\n");
    while ((entry = readdir(dir)) != NULL) {
        printf("  %s", entry->d_name);
        if (entry->d_type == DT_DIR) {
            printf("/");
        }
        printf("\n");
    }
    closedir(dir);

    /* Cleanup */
    unlink("test_file.txt");

    return 0;
}
EOF
            ;;
        network)
            cat > "${examples_dir}/socket_example.c" << 'EOF'
/*
 * socket_example.c - Demonstrate socket operations
 *
 * This example shows basic TCP client socket usage.
 *
 * Compile: gcc -o socket_example socket_example.c
 * Run: ./socket_example
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <netdb.h>

#define BUFFER_SIZE 4096

int main(void)
{
    int sockfd;
    struct sockaddr_in server_addr;
    struct hostent *server;
    char buffer[BUFFER_SIZE];
    ssize_t bytes;

    printf("=== Socket Example ===\n");

    /* Create socket */
    sockfd = socket(AF_INET, SOCK_STREAM, 0);
    if (sockfd < 0) {
        perror("socket");
        exit(EXIT_FAILURE);
    }
    printf("Socket created: fd=%d\n", sockfd);

    /* Resolve hostname */
    server = gethostbyname("example.com");
    if (server == NULL) {
        fprintf(stderr, "gethostbyname failed\n");
        close(sockfd);
        exit(EXIT_FAILURE);
    }

    /* Setup server address */
    memset(&server_addr, 0, sizeof(server_addr));
    server_addr.sin_family = AF_INET;
    memcpy(&server_addr.sin_addr.s_addr, server->h_addr, server->h_length);
    server_addr.sin_port = htons(80);

    /* Connect to server */
    printf("Connecting to example.com:80...\n");
    if (connect(sockfd, (struct sockaddr *)&server_addr, 
                sizeof(server_addr)) < 0) {
        perror("connect");
        close(sockfd);
        exit(EXIT_FAILURE);
    }
    printf("Connected!\n");

    /* Send HTTP request */
    const char *request = "GET / HTTP/1.0\r\nHost: example.com\r\n\r\n";
    bytes = send(sockfd, request, strlen(request), 0);
    printf("Sent %zd bytes\n", bytes);

    /* Receive response */
    printf("\n=== Response (first 500 bytes) ===\n");
    bytes = recv(sockfd, buffer, sizeof(buffer) - 1, 0);
    if (bytes > 0) {
        buffer[bytes] = '\0';
        /* Print first 500 chars */
        printf("%.500s", buffer);
        if (bytes > 500) {
            printf("...\n[truncated]");
        }
        printf("\n");
    }

    /* Close socket */
    close(sockfd);
    printf("\nSocket closed\n");

    return 0;
}
EOF
            ;;
    esac
    
    log_success "Examples generated in: $examples_dir"
}

# Main execution
main() {
    parse_args "$@"
    
    print_header "analyze_subsystem.sh"
    
    log_info "Analyzing subsystem: $SUBSYSTEM"
    log_info "Output directory: $OUTPUT_DIR"
    
    # Initialize documentation structure
    init_docs_structure
    ensure_dir "$OUTPUT_DIR"
    
    # Generate documentation
    if [ $GENERATE_RST -eq 1 ]; then
        generate_overview "$SUBSYSTEM"
        generate_components "$SUBSYSTEM"
        generate_data_structures "$SUBSYSTEM"
    fi
    
    # Extract symbols
    extract_symbols "$SUBSYSTEM"
    
    # Generate diagrams
    if [ $GENERATE_DIAGRAMS -eq 1 ]; then
        generate_diagrams "$SUBSYSTEM"
    fi
    
    # Generate examples
    if [ $GENERATE_EXAMPLES -eq 1 ]; then
        generate_examples "$SUBSYSTEM"
    fi
    
    echo ""
    log_success "Analysis complete!"
    echo ""
    echo "Output location: $OUTPUT_DIR"
    echo ""
    echo "Generated files:"
    ls -la "$OUTPUT_DIR"
    
    if [ -d "${OUTPUT_DIR}/diagrams" ]; then
        echo ""
        echo "Diagrams:"
        ls -la "${OUTPUT_DIR}/diagrams"
    fi
}

main "$@"
