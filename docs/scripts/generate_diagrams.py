#!/usr/bin/env python3
"""
generate_diagrams.py - Generate PlantUML diagrams from kernel source analysis

This script generates various types of architecture diagrams:
- C4 Container/Component diagrams
- Sequence diagrams
- Class/Structure diagrams
- State machine diagrams
- Entity-Relationship diagrams

Usage:
    ./generate_diagrams.py [OPTIONS] <subsystem>

SPDX-License-Identifier: GPL-2.0
"""

import argparse
import json
import os
import re
import sys
from pathlib import Path
from typing import Dict, List, Optional, Tuple
from dataclasses import dataclass, field

# Add lib directory to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'lib'))
from parser_utils import CParser, PlantUMLGenerator, RSTGenerator


@dataclass
class Component:
    """Represents a kernel component for C4 diagrams."""
    name: str
    description: str
    technology: str = "C"
    path: str = ""
    dependencies: List[str] = field(default_factory=list)


@dataclass
class Subsystem:
    """Represents a kernel subsystem."""
    name: str
    path: str
    components: List[Component] = field(default_factory=list)
    description: str = ""


# Predefined kernel subsystem mappings
KERNEL_SUBSYSTEMS = {
    'process': Subsystem(
        name='Process Management',
        path='kernel/',
        description='Process creation, scheduling, and lifecycle management',
        components=[
            Component('Scheduler', 'CFS and other scheduling classes', path='kernel/sched/'),
            Component('Fork', 'Process creation via fork/clone', path='kernel/fork.c'),
            Component('Exit', 'Process termination', path='kernel/exit.c'),
            Component('Signal', 'Signal delivery and handling', path='kernel/signal.c'),
            Component('Ptrace', 'Process tracing', path='kernel/ptrace.c'),
        ]
    ),
    'memory': Subsystem(
        name='Memory Management',
        path='mm/',
        description='Physical and virtual memory management',
        components=[
            Component('Page Allocator', 'Buddy allocator for pages', path='mm/page_alloc.c'),
            Component('Slab Allocator', 'SLUB/SLAB object allocator', path='mm/slub.c'),
            Component('VMAlloc', 'Virtual memory allocation', path='mm/vmalloc.c'),
            Component('Memory Mapping', 'mmap and VMA management', path='mm/mmap.c'),
            Component('Page Cache', 'File-backed page cache', path='mm/filemap.c'),
            Component('Swap', 'Swap space management', path='mm/swap.c'),
        ]
    ),
    'filesystem': Subsystem(
        name='File Systems',
        path='fs/',
        description='Virtual File System and file operations',
        components=[
            Component('VFS', 'Virtual File System layer', path='fs/'),
            Component('Namei', 'Path lookup', path='fs/namei.c'),
            Component('Open', 'File open operations', path='fs/open.c'),
            Component('Read/Write', 'I/O operations', path='fs/read_write.c'),
            Component('Buffer', 'Buffer cache', path='fs/buffer.c'),
        ]
    ),
    'network': Subsystem(
        name='Networking',
        path='net/',
        description='Network protocol stack',
        components=[
            Component('Socket', 'Socket layer', path='net/socket.c'),
            Component('TCP', 'TCP protocol', path='net/ipv4/tcp.c'),
            Component('UDP', 'UDP protocol', path='net/ipv4/udp.c'),
            Component('IP', 'IP layer', path='net/ipv4/ip_output.c'),
            Component('Netfilter', 'Packet filtering', path='net/netfilter/'),
        ]
    ),
    'block': Subsystem(
        name='Block Layer',
        path='block/',
        description='Block I/O and device management',
        components=[
            Component('Block Core', 'Core block layer', path='block/blk-core.c'),
            Component('BIO', 'Block I/O structure handling', path='block/bio.c'),
            Component('MQ', 'Multi-queue block layer', path='block/blk-mq.c'),
            Component('Elevator', 'I/O schedulers', path='block/elevator.c'),
        ]
    ),
    'drivers': Subsystem(
        name='Device Drivers',
        path='drivers/',
        description='Hardware device drivers',
        components=[
            Component('Driver Core', 'Driver model', path='drivers/base/'),
            Component('PCI', 'PCI bus drivers', path='drivers/pci/'),
            Component('USB', 'USB drivers', path='drivers/usb/'),
            Component('Block Drivers', 'Block device drivers', path='drivers/block/'),
        ]
    ),
}


class DiagramGenerator:
    """Generate various architecture diagrams."""
    
    def __init__(self, project_root: str):
        self.project_root = Path(project_root)
        self.parser = CParser(project_root)
    
    def generate_c4_context(self) -> str:
        """Generate C4 System Context diagram for Linux kernel."""
        return """@startuml C4_Context
!include https://raw.githubusercontent.com/plantuml-stdlib/C4-PlantUML/master/C4_Context.puml

title Linux Kernel - System Context Diagram

Person(user, "User", "End user running applications")
Person(dev, "Kernel Developer", "Develops and maintains kernel")
Person(admin, "System Administrator", "Manages system configuration")

System(kernel, "Linux Kernel", "Monolithic kernel with loadable modules")

System_Ext(hardware, "Hardware", "CPU, Memory, Storage, Network, Peripherals")
System_Ext(userspace, "User Space", "Applications, Libraries, System Services")
System_Ext(firmware, "Firmware/BIOS", "Low-level hardware initialization")

Rel(user, userspace, "Uses")
Rel(userspace, kernel, "System calls")
Rel(kernel, hardware, "Controls")
Rel(firmware, hardware, "Initializes")
Rel(dev, kernel, "Develops")
Rel(admin, kernel, "Configures")

LAYOUT_WITH_LEGEND()
@enduml"""
    
    def generate_c4_container(self, subsystem_name: str = None) -> str:
        """Generate C4 Container diagram for kernel or specific subsystem."""
        if subsystem_name and subsystem_name in KERNEL_SUBSYSTEMS:
            return self._generate_subsystem_container(KERNEL_SUBSYSTEMS[subsystem_name])
        else:
            return self._generate_kernel_container()
    
    def _generate_kernel_container(self) -> str:
        """Generate C4 Container diagram for entire kernel."""
        lines = [
            "@startuml C4_Container_Kernel",
            "!include https://raw.githubusercontent.com/plantuml-stdlib/C4-PlantUML/master/C4_Container.puml",
            "",
            "title Linux Kernel - Container Diagram",
            "",
            "LAYOUT_WITH_LEGEND()",
            "",
            "Person(dev, \"Kernel Developer\")",
            "",
            'System_Boundary(kernel, "Linux Kernel") {',
        ]
        
        for key, subsys in KERNEL_SUBSYSTEMS.items():
            alias = key.replace('-', '_')
            lines.append(f'    Container({alias}, "{subsys.name}", "C", "{subsys.description}")')
        
        lines.append("}")
        lines.append("")
        lines.append('System_Ext(hardware, "Hardware")')
        lines.append('System_Ext(userspace, "User Space")')
        lines.append("")
        
        # Add relationships
        lines.append('Rel(userspace, process, "System calls")')
        lines.append('Rel(process, memory, "Memory allocation")')
        lines.append('Rel(process, filesystem, "File I/O")')
        lines.append('Rel(filesystem, block, "Block I/O")')
        lines.append('Rel(block, drivers, "Device access")')
        lines.append('Rel(drivers, hardware, "Hardware control")')
        lines.append('Rel(network, drivers, "Network I/O")')
        
        lines.append("@enduml")
        return "\n".join(lines)
    
    def _generate_subsystem_container(self, subsys: Subsystem) -> str:
        """Generate C4 Container diagram for a specific subsystem."""
        lines = [
            "@startuml C4_Container",
            "!include https://raw.githubusercontent.com/plantuml-stdlib/C4-PlantUML/master/C4_Container.puml",
            "",
            f"title {subsys.name} - Container Diagram",
            "",
            "LAYOUT_WITH_LEGEND()",
            "",
            f'System_Boundary(subsys, "{subsys.name}") {{',
        ]
        
        for comp in subsys.components:
            alias = comp.name.lower().replace(' ', '_').replace('/', '_')
            lines.append(f'    Container({alias}, "{comp.name}", "{comp.technology}", "{comp.description}")')
        
        lines.append("}")
        lines.append("")
        lines.append('System_Ext(other, "Other Subsystems")')
        lines.append("")
        
        # Add inter-component relationships
        if len(subsys.components) > 1:
            for i in range(len(subsys.components) - 1):
                from_alias = subsys.components[i].name.lower().replace(' ', '_').replace('/', '_')
                to_alias = subsys.components[i + 1].name.lower().replace(' ', '_').replace('/', '_')
                lines.append(f'Rel({from_alias}, {to_alias}, "Calls")')
        
        lines.append("@enduml")
        return "\n".join(lines)
    
    def generate_c4_component(self, subsystem_name: str) -> str:
        """Generate C4 Component diagram for a subsystem."""
        if subsystem_name not in KERNEL_SUBSYSTEMS:
            raise ValueError(f"Unknown subsystem: {subsystem_name}")
        
        subsys = KERNEL_SUBSYSTEMS[subsystem_name]
        
        lines = [
            "@startuml C4_Component",
            "!include https://raw.githubusercontent.com/plantuml-stdlib/C4-PlantUML/master/C4_Component.puml",
            "",
            f"title {subsys.name} - Component Diagram",
            "",
            "LAYOUT_WITH_LEGEND()",
            "",
            f'Container_Boundary(subsys, "{subsys.name}") {{',
        ]
        
        for comp in subsys.components:
            alias = comp.name.lower().replace(' ', '_').replace('/', '_')
            lines.append(f'    Component({alias}, "{comp.name}", "{comp.technology}", "{comp.description}")')
        
        lines.append("}")
        lines.append("")
        
        # Add relationships between components
        for i, comp in enumerate(subsys.components[:-1]):
            from_alias = comp.name.lower().replace(' ', '_').replace('/', '_')
            to_alias = subsys.components[i + 1].name.lower().replace(' ', '_').replace('/', '_')
            lines.append(f'Rel({from_alias}, {to_alias}, "Uses")')
        
        lines.append("@enduml")
        return "\n".join(lines)
    
    def generate_sequence_diagram(self, title: str, flow_type: str) -> str:
        """Generate sequence diagram for common kernel flows."""
        flows = {
            'syscall': self._syscall_sequence(),
            'fork': self._fork_sequence(),
            'page_fault': self._page_fault_sequence(),
            'file_read': self._file_read_sequence(),
            'network_send': self._network_send_sequence(),
        }
        
        if flow_type not in flows:
            raise ValueError(f"Unknown flow type: {flow_type}. Available: {list(flows.keys())}")
        
        return flows[flow_type]
    
    def _syscall_sequence(self) -> str:
        """Generate syscall entry sequence diagram."""
        return """@startuml Syscall_Entry
title System Call Entry Flow

skinparam sequenceArrowThickness 2
skinparam roundcorner 20

participant "User Space" as user #LightBlue
participant "syscall_entry" as entry #LightGreen
participant "do_syscall_64" as dosys #LightYellow
participant "sys_call_table" as table #LightPink
participant "Syscall Handler" as handler #LightGray

user -> entry: syscall instruction
activate entry

entry -> entry: save registers (pt_regs)
entry -> dosys: do_syscall_64(regs)
activate dosys

dosys -> table: lookup sys_call_table[nr]
activate table
table --> dosys: handler address
deactivate table

dosys -> handler: invoke handler(args)
activate handler

handler -> handler: perform operation
handler --> dosys: return value
deactivate handler

dosys -> dosys: store result in regs->ax
dosys --> entry: return
deactivate dosys

entry -> entry: restore registers
entry --> user: sysret/iret
deactivate entry

note right of entry
    x86_64 uses:
    - SYSCALL/SYSRET (fast path)
    - INT 0x80 (compat)
end note
@enduml"""
    
    def _fork_sequence(self) -> str:
        """Generate fork() sequence diagram."""
        return """@startuml Fork_Flow
title Process Fork Flow

skinparam sequenceArrowThickness 2
skinparam roundcorner 20

participant "Parent Process" as parent #LightBlue
participant "sys_fork" as sysfork #LightGreen
participant "kernel_clone" as clone #LightYellow
participant "copy_process" as copy #LightPink
participant "Scheduler" as sched #LightGray

parent -> sysfork: fork()
activate sysfork

sysfork -> clone: kernel_clone(SIGCHLD, ...)
activate clone

clone -> copy: copy_process(clone_flags)
activate copy

copy -> copy: dup_task_struct()
note right: Allocate new task_struct

copy -> copy: copy_creds()
note right: Copy credentials

copy -> copy: copy_mm()
note right: Copy/share memory

copy -> copy: copy_files()
note right: Copy file descriptors

copy -> copy: copy_fs()
note right: Copy filesystem info

copy -> copy: copy_signal()
copy -> copy: copy_sighand()

copy --> clone: new task_struct
deactivate copy

clone -> sched: wake_up_new_task(p)
activate sched
sched -> sched: activate_task()
sched --> clone: task queued
deactivate sched

clone --> sysfork: child pid
deactivate clone

sysfork --> parent: pid (parent) / 0 (child)
deactivate sysfork

note over parent,sched
    After fork:
    - Parent returns child PID
    - Child returns 0
    - Both continue from fork() return
end note
@enduml"""
    
    def _page_fault_sequence(self) -> str:
        """Generate page fault handling sequence diagram."""
        return """@startuml Page_Fault
title Page Fault Handling Flow

skinparam sequenceArrowThickness 2
skinparam roundcorner 20

participant "CPU" as cpu #LightBlue
participant "page_fault_handler" as pf #LightGreen
participant "handle_mm_fault" as mmf #LightYellow
participant "VMA" as vma #LightPink
participant "Page Allocator" as alloc #LightGray
participant "Page Tables" as pt #Wheat

cpu -> pf: #PF exception
activate pf

pf -> pf: get fault address (CR2)
pf -> pf: find_vma(mm, address)

alt VMA not found
    pf --> cpu: SIGSEGV
else VMA found
    pf -> mmf: handle_mm_fault(vma, address, flags)
    activate mmf
    
    mmf -> vma: vma->vm_ops->fault()
    activate vma
    
    alt Anonymous page
        vma -> alloc: alloc_pages()
        activate alloc
        alloc --> vma: new page
        deactivate alloc
        vma -> vma: clear_page() / copy-on-write
    else File-backed page
        vma -> vma: filemap_fault()
        note right: Read from page cache\\nor disk
    end
    
    vma --> mmf: page
    deactivate vma
    
    mmf -> pt: set_pte()
    activate pt
    pt --> mmf: PTE installed
    deactivate pt
    
    mmf --> pf: VM_FAULT_NOPAGE
    deactivate mmf
end

pf --> cpu: return (retry instruction)
deactivate pf

note over cpu,pt
    Page fault types:
    - Minor: page in cache, just map
    - Major: page on disk, I/O needed
    - COW: copy-on-write fault
end note
@enduml"""
    
    def _file_read_sequence(self) -> str:
        """Generate file read sequence diagram."""
        return """@startuml File_Read
title File Read Operation Flow

skinparam sequenceArrowThickness 2
skinparam roundcorner 20

participant "User Space" as user #LightBlue
participant "sys_read" as read #LightGreen
participant "VFS" as vfs #LightYellow
participant "Page Cache" as cache #LightPink
participant "File System" as fs #LightGray
participant "Block Layer" as block #Wheat

user -> read: read(fd, buf, count)
activate read

read -> vfs: vfs_read(file, buf, count, pos)
activate vfs

vfs -> vfs: file->f_op->read_iter()

vfs -> cache: filemap_read()
activate cache

alt Page in cache (cache hit)
    cache -> cache: find_get_pages_contig()
    cache --> vfs: cached pages
else Page not in cache (cache miss)
    cache -> fs: readahead / readpage
    activate fs
    
    fs -> block: submit_bio(READ)
    activate block
    block -> block: I/O scheduler
    block -> block: device driver
    block --> fs: bio completion
    deactivate block
    
    fs --> cache: pages filled
    deactivate fs
end

cache --> vfs: data available
deactivate cache

vfs -> vfs: copy_to_iter(buf, ...)
note right: Copy to user buffer

vfs --> read: bytes read
deactivate vfs

read --> user: bytes read (or error)
deactivate read

note over user,block
    Readahead:
    - Kernel predicts sequential access
    - Prefetches additional pages
    - Improves I/O performance
end note
@enduml"""
    
    def _network_send_sequence(self) -> str:
        """Generate network send sequence diagram."""
        return """@startuml Network_Send
title Network Packet Send Flow

skinparam sequenceArrowThickness 2
skinparam roundcorner 20

participant "User Space" as user #LightBlue
participant "Socket Layer" as sock #LightGreen
participant "TCP" as tcp #LightYellow
participant "IP" as ip #LightPink
participant "Network Device" as dev #LightGray
participant "NIC Driver" as nic #Wheat

user -> sock: send(fd, buf, len, flags)
activate sock

sock -> sock: sock_sendmsg()
sock -> tcp: tcp_sendmsg()
activate tcp

tcp -> tcp: allocate sk_buff
tcp -> tcp: copy_from_user()
tcp -> tcp: tcp_push()
tcp -> tcp: __tcp_push_pending_frames()

tcp -> ip: ip_queue_xmit()
activate ip

ip -> ip: ip_local_out()
ip -> ip: add IP header
ip -> ip: ip_output()
ip -> ip: ip_finish_output()

ip -> dev: dev_queue_xmit()
activate dev

dev -> dev: netfilter hooks
dev -> dev: traffic control (qdisc)
dev -> nic: ndo_start_xmit()
activate nic

nic -> nic: DMA to hardware
nic --> dev: NETDEV_TX_OK
deactivate nic

dev --> ip: transmitted
deactivate dev

ip --> tcp: sent
deactivate ip

tcp --> sock: bytes queued
deactivate tcp

sock --> user: bytes sent
deactivate sock

note over user,nic
    Packet path:
    send() -> socket -> TCP -> IP -> device -> driver -> NIC
    Each layer adds headers and performs processing
end note
@enduml"""
    
    def generate_state_diagram(self, entity: str) -> str:
        """Generate state machine diagram for kernel entities."""
        diagrams = {
            'task': self._task_state_diagram(),
            'page': self._page_state_diagram(),
            'socket': self._socket_state_diagram(),
            'request': self._request_state_diagram(),
        }
        
        if entity not in diagrams:
            raise ValueError(f"Unknown entity: {entity}. Available: {list(diagrams.keys())}")
        
        return diagrams[entity]
    
    def _task_state_diagram(self) -> str:
        """Generate task/process state diagram."""
        return """@startuml Task_States
title Linux Process/Task States

skinparam state {
    BackgroundColor #FEFECE
    BorderColor #A80036
}

[*] --> TASK_NEW : fork()/clone()

TASK_NEW --> TASK_RUNNING : wake_up_new_task()

state TASK_RUNNING {
    [*] --> Running
    Running --> Ready : preempt/yield
    Ready --> Running : schedule()
    note right of Running : Actually executing on CPU
    note right of Ready : Runnable, waiting for CPU
}

TASK_RUNNING --> TASK_INTERRUPTIBLE : sleep_on() / wait_event()
TASK_RUNNING --> TASK_UNINTERRUPTIBLE : sleep_on() / mutex_lock()
TASK_RUNNING -[#red]-> TASK_STOPPED : SIGSTOP / ptrace
TASK_RUNNING -[#blue]-> EXIT_ZOMBIE : do_exit()

TASK_INTERRUPTIBLE --> TASK_RUNNING : wake_up() / signal
TASK_UNINTERRUPTIBLE --> TASK_RUNNING : wake_up()

TASK_STOPPED --> TASK_RUNNING : SIGCONT

TASK_INTERRUPTIBLE : Can be interrupted by signals
TASK_UNINTERRUPTIBLE : Cannot be interrupted
TASK_STOPPED : Stopped for debugging/job control

EXIT_ZOMBIE --> EXIT_DEAD : parent calls wait()
EXIT_ZOMBIE : Terminated, waiting for parent

EXIT_DEAD --> [*] : release_task()

note bottom of TASK_RUNNING
    Only one state flag set at a time
    (stored in task->__state)
end note
@enduml"""
    
    def _page_state_diagram(self) -> str:
        """Generate page state diagram."""
        return """@startuml Page_States
title Linux Page States

skinparam state {
    BackgroundColor #FEFECE
    BorderColor #A80036
}

[*] --> Free : Initial state

Free --> Allocated : alloc_pages()
note right of Free : In buddy allocator free list

state Allocated {
    [*] --> Clean
    Clean --> Dirty : write to page
    Dirty --> Clean : writeback complete
    Dirty --> Writeback : start writeback
    Writeback --> Clean : I/O complete
}

Allocated --> Free : __free_pages()

state "In Page Cache" as cached {
    [*] --> Inactive
    Inactive --> Active : page accessed
    Active --> Inactive : page aging
    note right: LRU lists for reclaim
}

Allocated --> cached : add_to_page_cache()
cached --> Allocated : remove from cache

state "Mapped" as mapped {
    [*] --> Private
    Private --> Shared : fork() / mmap()
    note right: Present in process page tables
}

Allocated --> mapped : map to process
mapped --> Allocated : unmap

note bottom of Allocated
    Page flags (struct page->flags):
    - PG_locked, PG_dirty, PG_writeback
    - PG_lru, PG_active, PG_referenced
    - PG_slab, PG_buddy, PG_compound
end note
@enduml"""
    
    def _socket_state_diagram(self) -> str:
        """Generate TCP socket state diagram."""
        return """@startuml Socket_States
title TCP Socket States

skinparam state {
    BackgroundColor #FEFECE
    BorderColor #A80036
}

[*] --> CLOSED : socket()

state "Connection Setup" as setup {
    CLOSED --> LISTEN : listen() [server]
    CLOSED --> SYN_SENT : connect() [client]
    
    LISTEN --> SYN_RECEIVED : recv SYN, send SYN+ACK
    SYN_SENT --> ESTABLISHED : recv SYN+ACK, send ACK
    SYN_RECEIVED --> ESTABLISHED : recv ACK
}

state "Established" as established {
    ESTABLISHED : Data transfer
    ESTABLISHED --> ESTABLISHED : send/recv data
}

state "Connection Teardown" as teardown {
    ESTABLISHED --> FIN_WAIT_1 : close() [active close]
    ESTABLISHED --> CLOSE_WAIT : recv FIN [passive close]
    
    FIN_WAIT_1 --> FIN_WAIT_2 : recv ACK
    FIN_WAIT_1 --> CLOSING : recv FIN
    FIN_WAIT_1 --> TIME_WAIT : recv FIN+ACK
    
    FIN_WAIT_2 --> TIME_WAIT : recv FIN
    CLOSING --> TIME_WAIT : recv ACK
    
    CLOSE_WAIT --> LAST_ACK : close()
    LAST_ACK --> CLOSED : recv ACK
    
    TIME_WAIT --> CLOSED : 2*MSL timeout
}

TIME_WAIT : Wait 2*MSL before reuse
note right of TIME_WAIT
    Prevents delayed packets
    from previous connection
end note

note bottom of ESTABLISHED
    Most time spent here
    during normal operation
end note
@enduml"""
    
    def _request_state_diagram(self) -> str:
        """Generate block I/O request state diagram."""
        return """@startuml Request_States
title Block I/O Request States

skinparam state {
    BackgroundColor #FEFECE
    BorderColor #A80036
}

[*] --> Created : blk_mq_alloc_request()

Created --> Queued : blk_mq_insert_request()
note right of Created : Request allocated from tag pool

state Queued {
    [*] --> Software_Queue
    Software_Queue --> Hardware_Queue : blk_mq_run_hw_queue()
    
    note right of Software_Queue
        Per-CPU software staging queue
    end note
    
    note right of Hardware_Queue
        Device hardware dispatch queue
    end note
}

Queued --> InFlight : queue_rq() callback
note right of InFlight : Submitted to device driver

InFlight --> Completed : blk_mq_complete_request()

state Completed {
    [*] --> Success
    [*] --> Error
    [*] --> Retry
}

Completed --> [*] : blk_mq_end_request()

Retry --> Queued : blk_mq_requeue_request()

note bottom of InFlight
    Request tracked via:
    - rq->state
    - Tag allocation
    - Timeout tracking
end note
@enduml"""
    
    def generate_erd(self, subsystem: str) -> str:
        """Generate Entity-Relationship diagram."""
        erds = {
            'process': self._process_erd(),
            'memory': self._memory_erd(),
            'filesystem': self._filesystem_erd(),
        }
        
        if subsystem not in erds:
            raise ValueError(f"Unknown subsystem: {subsystem}. Available: {list(erds.keys())}")
        
        return erds[subsystem]
    
    def _process_erd(self) -> str:
        """Generate process-related ERD."""
        return """@startuml Process_ERD
title Process Management - Entity Relationships

skinparam linetype ortho

entity "task_struct" as task {
    * pid : pid_t
    --
    * tgid : pid_t
    * state : unsigned int
    * comm[16] : char
    * flags : unsigned int
}

entity "mm_struct" as mm {
    * mmap : vm_area_struct*
    --
    * pgd : pgd_t*
    * mm_users : atomic_t
    * mm_count : atomic_t
    * start_code : unsigned long
    * end_code : unsigned long
}

entity "files_struct" as files {
    * fdt : fdtable*
    --
    * count : atomic_t
    * next_fd : unsigned int
}

entity "signal_struct" as signal {
    * nr_threads : atomic_t
    --
    * leader_pid : pid*
    * tty : tty_struct*
}

entity "cred" as cred {
    * uid : kuid_t
    --
    * gid : kgid_t
    * euid : kuid_t
    * egid : kgid_t
}

entity "nsproxy" as ns {
    * count : atomic_t
    --
    * mnt_ns : mnt_namespace*
    * pid_ns : pid_namespace*
    * net_ns : net*
}

entity "thread_info" as ti {
    * flags : unsigned long
    --
    * cpu : u32
    * preempt_count : int
}

task ||--o| mm : "->mm"
task ||--|| files : "->files"
task ||--|| signal : "->signal (thread group)"
task ||--|| cred : "->cred"
task ||--|| ns : "->nsproxy"
task ||--|| ti : embedded

task }|--|| task : "->parent"
task }|--|{ task : "->children"
task }|--|{ task : "->sibling"
task }|--|{ task : "->thread_group"

note bottom of task
    Central process descriptor
    Contains all process state
end note
@enduml"""
    
    def _memory_erd(self) -> str:
        """Generate memory management ERD."""
        return """@startuml Memory_ERD
title Memory Management - Entity Relationships

skinparam linetype ortho

entity "mm_struct" as mm {
    * mmap : vm_area_struct*
    --
    * pgd : pgd_t*
    * mm_users : atomic_t
    * task_size : unsigned long
}

entity "vm_area_struct" as vma {
    * vm_start : unsigned long
    --
    * vm_end : unsigned long
    * vm_flags : unsigned long
    * vm_pgoff : unsigned long
}

entity "page" as page {
    * flags : unsigned long
    --
    * _mapcount : atomic_t
    * _refcount : atomic_t
    * index : unsigned long
}

entity "address_space" as mapping {
    * host : inode*
    --
    * i_pages : xarray
    * nrpages : unsigned long
}

entity "anon_vma" as anon {
    * root : anon_vma*
    --
    * rb_root : rb_root
    * refcount : atomic_t
}

entity "zone" as zone {
    * watermark[3] : unsigned long
    --
    * free_area[MAX_ORDER] : free_area
    * zone_pgdat : pglist_data*
}

entity "pglist_data" as node {
    * node_zones[] : zone
    --
    * node_id : int
    * node_start_pfn : unsigned long
}

mm ||--|{ vma : "->mmap (VMA list)"
vma }o--o| mapping : "->vm_file->f_mapping"
vma }o--o| anon : "->anon_vma"
mapping ||--|{ page : "page cache"
anon ||--|{ vma : "reverse mapping"
zone ||--|{ page : "free pages"
node ||--|{ zone : "memory zones"

note bottom of vma
    Virtual Memory Area
    Represents contiguous virtual address range
end note

note bottom of page
    Physical page frame descriptor
    struct page is ~64 bytes
end note
@enduml"""
    
    def _filesystem_erd(self) -> str:
        """Generate filesystem ERD."""
        return """@startuml Filesystem_ERD
title Virtual File System - Entity Relationships

skinparam linetype ortho

entity "file" as file {
    * f_path : path
    --
    * f_inode : inode*
    * f_op : file_operations*
    * f_pos : loff_t
    * f_count : atomic_long_t
}

entity "dentry" as dentry {
    * d_name : qstr
    --
    * d_inode : inode*
    * d_parent : dentry*
    * d_sb : super_block*
    * d_flags : unsigned int
}

entity "inode" as inode {
    * i_ino : unsigned long
    --
    * i_mode : umode_t
    * i_uid : kuid_t
    * i_gid : kgid_t
    * i_size : loff_t
    * i_op : inode_operations*
}

entity "super_block" as sb {
    * s_dev : dev_t
    --
    * s_type : file_system_type*
    * s_root : dentry*
    * s_op : super_operations*
}

entity "vfsmount" as mnt {
    * mnt_root : dentry*
    --
    * mnt_sb : super_block*
    * mnt_flags : int
}

entity "address_space" as mapping {
    * host : inode*
    --
    * i_pages : xarray
    * a_ops : address_space_operations*
}

entity "file_operations" as fops {
    * read : function*
    --
    * write : function*
    * mmap : function*
    * open : function*
}

file }|--|| dentry : "f_path.dentry"
file }|--|| mnt : "f_path.mnt"
file }o--|| inode : "f_inode"
file }o--|| fops : "f_op"

dentry }|--|| inode : "d_inode"
dentry }|--o| dentry : "d_parent"
dentry }|--|| sb : "d_sb"

inode ||--|| mapping : "i_mapping"
inode }|--|| sb : "i_sb"

mnt }|--|| dentry : "mnt_root"
mnt }|--|| sb : "mnt_sb"

sb ||--|| dentry : "s_root"

note bottom of file
    Open file descriptor
    Per-process view of a file
end note

note bottom of inode
    On-disk file metadata
    Shared between all openers
end note
@enduml"""


def main():
    parser = argparse.ArgumentParser(
        description='Generate PlantUML architecture diagrams for Linux kernel',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Diagram Types:
    c4-context     - System context diagram (high-level)
    c4-container   - Container diagram for kernel or subsystem
    c4-component   - Component diagram for specific subsystem
    sequence       - Sequence diagrams for kernel flows
    state          - State machine diagrams for kernel entities
    erd            - Entity-relationship diagrams

Available Subsystems: process, memory, filesystem, network, block, drivers

Flow Types (for sequence): syscall, fork, page_fault, file_read, network_send

Entity Types (for state): task, page, socket, request

Examples:
    %(prog)s --type c4-container
    %(prog)s --type c4-container --subsystem memory
    %(prog)s --type sequence --flow fork
    %(prog)s --type state --entity task
    %(prog)s --type erd --subsystem process
        """
    )
    
    parser.add_argument('--type', '-t', required=True,
                        choices=['c4-context', 'c4-container', 'c4-component', 
                                'sequence', 'state', 'erd'],
                        help='Type of diagram to generate')
    parser.add_argument('--subsystem', '-s',
                        choices=list(KERNEL_SUBSYSTEMS.keys()),
                        help='Kernel subsystem (for c4-container, c4-component, erd)')
    parser.add_argument('--flow', '-f',
                        choices=['syscall', 'fork', 'page_fault', 'file_read', 'network_send'],
                        help='Flow type (for sequence diagrams)')
    parser.add_argument('--entity', '-e',
                        choices=['task', 'page', 'socket', 'request'],
                        help='Entity type (for state diagrams)')
    parser.add_argument('--output', '-o', help='Output file (default: stdout)')
    parser.add_argument('--title', help='Custom title for diagram')
    parser.add_argument('-v', '--verbose', action='store_true',
                        help='Enable verbose output')
    
    args = parser.parse_args()
    
    # Determine project root
    script_dir = Path(__file__).resolve().parent
    project_root = script_dir.parent.parent
    
    generator = DiagramGenerator(str(project_root))
    
    try:
        if args.type == 'c4-context':
            output = generator.generate_c4_context()
        elif args.type == 'c4-container':
            output = generator.generate_c4_container(args.subsystem)
        elif args.type == 'c4-component':
            if not args.subsystem:
                print("Error: --subsystem required for c4-component", file=sys.stderr)
                sys.exit(1)
            output = generator.generate_c4_component(args.subsystem)
        elif args.type == 'sequence':
            if not args.flow:
                print("Error: --flow required for sequence diagrams", file=sys.stderr)
                sys.exit(1)
            output = generator.generate_sequence_diagram(args.title or args.flow, args.flow)
        elif args.type == 'state':
            if not args.entity:
                print("Error: --entity required for state diagrams", file=sys.stderr)
                sys.exit(1)
            output = generator.generate_state_diagram(args.entity)
        elif args.type == 'erd':
            if not args.subsystem:
                print("Error: --subsystem required for ERD diagrams", file=sys.stderr)
                sys.exit(1)
            output = generator.generate_erd(args.subsystem)
        
        # Write output
        if args.output:
            with open(args.output, 'w') as f:
                f.write(output)
            if args.verbose:
                print(f"Diagram written to: {args.output}", file=sys.stderr)
        else:
            print(output)
    
    except ValueError as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        if args.verbose:
            import traceback
            traceback.print_exc()
        sys.exit(1)


if __name__ == '__main__':
    main()
