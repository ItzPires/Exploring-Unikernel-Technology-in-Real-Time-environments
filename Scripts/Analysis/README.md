# System Call Analysis Scripts

## Overview

This directory contains two scripts designed to extract system calls used by specific tools.

- **objdump.py**: Identifies all system calls present in the target application, including those that may not be required for execution.
- **strace.py**: Captures only the system calls necessary to execute a tool with a specified command-line input.

## Usage Examples

### Using `strace.py`

To determine the system calls required for executing a command, run:

```bash
python strace.py ./cyclictest -D 4h -i 10000 -v
```

### Using `objdump.py`

To extract all system calls present in a binary for a specific Linux kernel version, run:

```bash
python objdump.py cyclictest 6.8-rc1
```

## Additional Information
### Output Format
The scripts returns a list of system calls. Example output:
```bash
openat
newfstatat
close
mmap
read
...
```

### Prerequisites
Ensure that your system has the following dependencies installed:
- Python 3
- `strace` (for running `strace.py`)
- `objdump` (for running `objdump.py`)
- `requests` Python module (for downloading syscall tables)

To install missing dependencies, use:
```bash
sudo apt update && sudo apt install strace binutils
pip install requests
```
