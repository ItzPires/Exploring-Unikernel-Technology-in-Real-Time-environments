import re
import subprocess
import requests
import sys

"""
Extracts system call numbers from an objdump file by searching for 'syscall' 
instructions and their corresponding 'mov $0xZZZ,%eax' assignments.
"""
def extract_syscalls(lines):
    syscalls = []

    for i, line in enumerate(lines):
        # Identify 'syscall' instruction
        if 'syscall' in line:
            # Search for 'mov $0xZZZ,%eax' in preceding lines
            for j in range(i - 1, -1, -1):
                match = re.search(r'mov\s+\$0x([0-9a-fA-F]+),%eax', lines[j])
                if match:
                    syscall_hex = match.group(1)
                    syscalls.append(int(syscall_hex, 16))  # Convert hexadecimal to decimal
                    break  # Stop searching once the instruction is found

    # Remove duplicates and return sorted list of unique syscalls
    return sorted(set(syscalls))

"""
Maps system call numbers to their respective names using the Linux syscall table.

Downloads the `syscall_64.tbl` file from the Linux kernel repository to retrieve 
the mapping of syscall numbers to their names.
"""
def map_syscalls(syscall_numbers, kernel_version):
    syscall_mapping = {}
    results = []

    try:
        # Fetch the syscall_64.tbl file from the Linux kernel repository
        url = f"https://raw.githubusercontent.com/torvalds/linux/refs/tags/v{kernel_version}/arch/x86/entry/syscalls/syscall_64.tbl"
        response = requests.get(url, timeout=10)
        response.raise_for_status()  # Raise an error for HTTP failures
        
        # Process each line of the remote file
        for line in response.text.splitlines():
            line = line.strip()
            
            # Ignore empty lines, comments, or headers
            if not line or line.startswith("#"):
                continue
                
            columns = line.split()
            
            # Expected structure: <number> <abi> <name> <entry_point> [options]
            if len(columns) >= 3:
                try:
                    syscall_num = int(columns[0])
                    syscall_name = columns[2]  # Third column contains the syscall name
                    syscall_mapping[syscall_num] = syscall_name
                except (ValueError, IndexError):
                    continue  # Skip malformed lines
    except requests.exceptions.RequestException as e:
        raise RuntimeError(f"Failed to fetch syscall_64.tbl: {e}")

    # Map provided syscall numbers to their corresponding names
    for num in syscall_numbers:
        results.append((num, syscall_mapping.get(num, "NOT FOUND")))

    return results

"""
Displays the system calls in by the program.
"""
def display_syscalls(syscalls):
    for num, name in syscalls:
        print(name)

"""
Main entry point of the script. Disassembles a binary using objdump, extracts system calls, 
and maps them to their corresponding names using the Linux syscall table.

Usage:
    python objdump.py [binary] [kernel_version]

Example:
    python objdump.py cyclictest 6.8-rc1
"""
if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: python objdump.py [binary] [kernel_version]")
        sys.exit(1)

    binary = sys.argv[1]
    kernel_version = sys.argv[2]

    try:
        # Run objdump to disassemble the binary
        objdump_result = subprocess.run(
            ["objdump", "-d", binary],
            capture_output=True,  # Capture stdout and stderr
            text=True,  # Ensure output is handled as a string
            check=True  # Raise an exception if the command fails
        )
    except subprocess.CalledProcessError as e:
        print(f"Error executing objdump: {e}")
        sys.exit(1)

    # Extract system call numbers
    syscall_numbers = extract_syscalls(objdump_result.stdout)

    # Map system call numbers to syscall names
    mapped_syscalls = map_syscalls(syscall_numbers, kernel_version)

    # Print mapped syscalls
    display_syscalls(mapped_syscalls)
