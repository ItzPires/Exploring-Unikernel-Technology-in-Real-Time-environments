# OSv Patches by Luca Abeni

This folder contains patches provided by **Luca Abeni**, a university professor. More information about his work can be found [here](http://www.santannapisa.it/luca-abeni).

## Purpose
The patches in this repository were created for **OSv**, a unikernel operating system optimized for virtual machines. These patches primarily implement missing **syscalls** in OSv that are required for running **cyclictest**.

**Cyclictest** is a tool used to measure response latency in operating systems, and these syscalls are crucial to ensure that the tool can run properly in the OSv environment.

## Implemented Patches
The patches add the following functionalities to OSv:

- Implementation of missing syscalls in OSv to support **cyclictest**.
- Fixes and improvements to the syscall infrastructure.

## Contribution
These patches were kindly provided by **Luca Abeni**.
