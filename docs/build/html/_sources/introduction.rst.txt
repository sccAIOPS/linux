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
