import paramiko
import time

# SSH and ESXi Configuration
ESXI_HOST = "unik.dei.uc.pt"
ESXI_USER = "root"
ESXI_PASSWORD = "password"

LINUX_HOST = "10.3.1.174"
STRESS1_HOST = "10.3.1.174"
STRESS2_HOST = "10.3.3.196"
SSH_USER = "samuel"
SSH_PASSWORD = "password"

# VM Groups
NANOS_VMS = [100, 101, 102]
OSV_VMS = [103, 104, 105]
APPBOX_VMS = [106, 107, 108]
LINUX_VMS = [109, 110, 111]
STRESS_VMS = [87, 88]

SLEEP_4H = 4 * 60 * 60  # 4 hours in seconds
SLEEP_10S = 10  # 10 seconds

"""Executes a command via SSH"""
def execute_ssh_command(host, username, password, command):
    try:
        ssh = paramiko.SSHClient()
        ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        ssh.connect(host, username=username, password=password)
        stdin, stdout, stderr = ssh.exec_command(command)
        output = stdout.read().decode().strip()
        ssh.close()
        return output
    except Exception as e:
        print(f"Error executing SSH command on {host}: {e}")
        return None

"""Powers off a virtual machine on ESXi."""
def power_off_vm(vm_id):
    command = f"vim-cmd vmsvc/power.off {vm_id}"
    execute_ssh_command(ESXI_HOST, ESXI_USER, ESXI_PASSWORD, command)

"""Powers off and then powers on a virtual machine on ESXi."""
def power_on_vm(vm_id):
    power_off_vm(vm_id)
    time.sleep(10)
    command = f"vim-cmd vmsvc/power.on {vm_id}"
    execute_ssh_command(ESXI_HOST, ESXI_USER, ESXI_PASSWORD, command)

"""Turns on VMs, waits for a duration, then turns them off."""
def run_vm_test(vm_list, duration):
    for vm_id in vm_list:
        power_on_vm(vm_id)
        time.sleep(duration)
        power_off_vm(vm_id)

"""Runs a command on a Linux VM and waits for completion."""
def run_linux(vm_id, ip_address, command, sleep_time, turn_off=False):
    power_on_vm(vm_id)
    execute_ssh_command(ip_address, SSH_USER, SSH_PASSWORD, command)
    time.sleep(sleep_time)

    if turn_off:
        power_off_vm(vm_id)

"""Runs cyclictest on a Linux VM and waits for completion."""
def run_linux_test(vm_id, interval):
    command = f"./cyclictest -D 4h -v -i {interval}"
    run_linux(vm_id, LINUX_HOST, command, SLEEP_4H, turn_off=True)

"""Runs a stress test on a VM."""
def run_stress_test(vm_id, ip_address):
    command = "stress -c 10 -m 24 --vm-bytes 256M"
    run_linux(vm_id, ip_address, command, SLEEP_10S, turn_off=False)

"""Main function to orchestrate VM tests."""
def main():
    # Tests without stress
    run_vm_test(NANOS_VMS, SLEEP_4H)
    run_vm_test(OSV_VMS, SLEEP_4H)
    run_vm_test(APPBOX_VMS, SLEEP_4H)

    run_linux_test(LINUX_VMS[0], 10000)
    run_linux_test(LINUX_VMS[1], 1000)
    run_linux_test(LINUX_VMS[2], 100)

    # Tests with stress
    run_stress_test(STRESS_VMS[0], STRESS1_HOST)
    run_stress_test(STRESS_VMS[1], STRESS2_HOST)
    
    run_vm_test(NANOS_VMS, SLEEP_4H)
    run_vm_test(OSV_VMS, SLEEP_4H)
    run_vm_test(APPBOX_VMS, SLEEP_4H)

    run_linux_test(LINUX_VMS[0], 10000)
    run_linux_test(LINUX_VMS[1], 1000)
    run_linux_test(LINUX_VMS[2], 100)

if __name__ == "__main__":
    main()
