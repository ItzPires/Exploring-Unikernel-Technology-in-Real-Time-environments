import subprocess
import sys

"""
Executes a command with strace and captures only the system calls.
"""
def run_strace(command):
    try:
        result = subprocess.run(
            ["strace", "-c", "-U", "syscall"] + command,  # Uses strace to capture system call statistics
            stdout=subprocess.DEVNULL,  # Suppresses the original command's output
            stderr=subprocess.PIPE,  # Captures strace output
            text=True,  # Ensures output is treated as a string
            check=True  # Raises an exception if the command fails
        )
        return result.stderr  # The relevant strace output is captured in stderr
    except subprocess.CalledProcessError as e: # If the command fails, print an error message and exit
        print(f"Error executing strace: {e}")
        sys.exit(1)

"""
Extracts system calls used by the program from strace output.
"""
def extract_syscalls(strace_output):
    syscalls = strace_output.splitlines()[2:-2] # Extracts the system calls from the strace output (Skip the header and the footer)
    return syscalls


"""
Displays the system calls used by the program.
"""
def display_syscalls(syscalls):
    print("\n".join(syscalls))

"""
Main entry point of the script. Executes a command with strace and extracts the system calls used.

Usage:
    python strace.py [command] [arguments]

Examples:
    python strace.py ./cyclictest -D 4h -i 10000 -v
"""
if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python strace.py [command] [arguments]")
        sys.exit(1)

    # Extract command and arguments from command-line input
    command = sys.argv[1:]

    # Execute the command with strace and capture the output
    strace_output = run_strace(command)

    # Extract and display the system calls used by the program
    syscalls = extract_syscalls(strace_output)
    display_syscalls(syscalls)
