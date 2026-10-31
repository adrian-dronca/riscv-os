# IronHart Operating System

> A modern RISC-V operating system built for learning and exploration.

IronHart is a personal operating system project focused on understanding every major component of a modern OS stack, from the first CPU instruction executed after reset to user-space applications.

The project is designed as a hands-on journey through computer architecture, bootloaders, memory management, scheduling, filesystems, and operating system internals.

## Goals

- Learn the RISC-V ISA
- Build a custom bootloader
- Understand privilege modes and traps
- Implement virtual memory management
- Develop a multitasking kernel
- Create/import a filesystem
- Support user-space applications
- Gain practical operating system development experience
- Document the entire learning process

## Current Status

🚧 Early Development

The project starts from a blank repository and will evolve incrementally. Features will be implemented one step at a time and documented as they mature.

---

## Planned Architecture

```text
+-----------------------+
| User Applications     |
+-----------------------+
| System Calls          |
+-----------------------+
| Process Scheduler     |
+-----------------------+
| Virtual Memory (MMU)  |
+-----------------------+
| Device Drivers        |
+-----------------------+
| Kernel Core           |
+-----------------------+
| Bootloader            |
+-----------------------+
| RISC-V Hardware       |
+-----------------------+
```

---

## Features 

---

## Learning Objectives

This project aims to provide practical experience with:

- RISC-V Privileged Architecture
- Bootloaders
- Low-level Assembly Programming
- Operating System Design
- Memory Management
- Scheduling Algorithms
- Filesystem Design
- Device Drivers
- Systems Programming in C and/or Rust

---

## Long-Term Vision

The long-term goal is to evolve IronHart into a small but capable operating system that demonstrates a complete understanding of modern OS fundamentals while serving as a public portfolio project for systems programming and embedded software engineering.

---

## Author

Adrian D.

Building an operating system from the hardware up, one instruction at a time.
