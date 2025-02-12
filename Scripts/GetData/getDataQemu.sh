#!/bin/bash
# Script to run tests (cyclictest) in different environments:
# - Bare Metal  
# - Nanos (QEMU with KVM)  
# - OSv (QEMU with KVM)  
# - AppBox (QEMU with KVM)
#
# Steps:
# 1. The script checks that hyperthreading is disabled: the number of logical cores must equal the number of physical cores.
# 2. Each test is executed with a defined timeout (TEST_TIMEOUT). If the maximum time is reached, the process is killed and the next test is started after a wait (WAIT_BETWEEN_TESTS).
# 3. For each test, the affinity to the CPU Core where the process will run is defined and the process is set to have a priority of 99.
#

##########################
# Global Variables
##########################
CPU_CORE="1"            # CPU Core to execute the process - from 0 to n CPU Core
ISOLATED_NUM_CORES=1    # Number of CPU Cores isolated - in this case 1, because CPU CORE 1 is disable for execute te process
TEST_TIMEOUT=60         # Timeout for test (in seconds) - 4h and 10s
WAIT_BETWEEN_TESTS=10   # Time to wait between tests (in seconds) - 10s
PATCH_DATA="/home/samuel/unikernels/Data/"
SSH_USER="samuel"



##########################
# Functions
##########################

# Function to check if hyperthreading is disabled and how many CPU Cores are available.
check_hyperthreading_CPU_Cores() {
    echo "Check hyperthreading and CPU Cores"
    local threads_per_core
    local cores_per_socket
    local sockets
    local physical_cores
    local total_logical

    threads_per_core=$(lscpu | awk -F: '/Thread\(s\) per core/ {gsub(/ /, "", $2); print $2}')
    cores_per_socket=$(lscpu | awk -F: '/Core\(s\) per socket/ {gsub(/ /, "", $2); print $2}')
    sockets=$(lscpu | awk -F: '/Socket\(s\)/ {gsub(/ /, "", $2); print $2}')
    physical_cores=$(( cores_per_socket * sockets ))
    total_logical=$(nproc)
    total_logical_adjusted=$(( total_logical + $ISOLATED_NUM_CORES ))

    if [ "$threads_per_core" -ne 1 ] || [ "$total_logical_adjusted" -ne "$physical_cores" ]; then
        echo "Error:"
        echo "  Logical Cores: $total_logical_adjusted"
        echo "  Physical Cores: $physical_cores"
        exit 1
    else
        echo "OK: Hyperthreading disabled. Available CPU Cores: $physical_cores"
    fi
}



# Function to collect statistics
# Parameters:
  # $1 - Output file name
  # $2 - PID
collect_stats() {
  local OUTPUT="$1"
  local PID="$2"

  sleep 2

  # Check if the PID exists
  if [ -z "$PID" ]; then
    echo "Process not found."
    return
  fi

  # Output file header
  echo "CPU(%),RSS(KB)" > "$OUTPUT"

  # Collects statistics until the process is finished
  while true; do
    # Check if the process still exists
    if ! ps -p "$PID" > /dev/null; then
      echo "Process with PID $PID has finished."
      break
    fi

    # Get statistics from pidstat
    STATS=$(pidstat -u -r -p "$PID" 1 1)

    # Extracts %CPU and RSS
    CPU=$(echo "$STATS" | awk '/Average:/ && /%CPU/ {getline; print $8}')
    RSS=$(echo "$STATS" | awk '/Average:/ && /RSS/ {getline; print $7}')

    # If the values are not extracted correctly, it exits the loop
    if [ -z "$CPU" ] || [ -z "$RSS" ]; then
      echo "The process ended or failed to extract value."
      break
    fi

    # Saves the values in the log
    echo "$CPU,$RSS" >> "$OUTPUT"
  done
}



# Function to run the tests
# Parameters:
#   $1: Test name (for display)
#   $2: Log file (where the output will be stored)
#   $3: Collect statistics? - True or False
#   $@: Command to be executed
run_test() {
    local test_name="$1"                # Test name
    local log_file="${PATCH_DATA}$2"    # Log file
    local collect_stats="${3:-false}"   # Collect statistics? (optional, default: false)
    shift 3
    local cmd=( "$@" )                  # Command

    mkdir -p "$(dirname "$log_file")"

    echo "=================================================="
    echo "Test: $test_name"
    echo "Start Time: $(date)"

    # Executes the command with taskset and redirects output to the log
    taskset -c "$CPU_CORE" "${cmd[@]}" >> "$log_file" 2>&1 &
    local child_pid=$!      # Get PID
    sleep 2

    # Apply priority
    chrt -f -p 99 "$child_pid" 2>/dev/null

    # If statistics collection is activated, starts collection in the background
    if [[ "$collect_stats" == "true" ]]; then
        local stats_file="${log_file}.stats.csv"
        collect_stats "$stats_file" $child_pid &
        local stats_pid=$!
    fi

    # Waits for timeout and terminates if necessary
    if [[ "$test_name" == Ubuntu* ]]; then
        echo "Ubuntu detected, waiting 60s before SSH..."
        sleep 60

        # Run SSH and timeout cyclictest
        timeout "$TEST_TIMEOUT" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p 2222 "$SSH_USER"@127.0.0.1 "sudo ./cyclictest -D 4h -v -i $CYCLICTEST_INTERVAL" > "$log_file" 2>&1

        # Check that SSH is still running and shut it down if necessary
        local ssh_pid
        ssh_pid=$(pgrep -f "ssh -o StrictHostKeyChecking=no*")
        if [[ -n "$ssh_pid" ]]; then
            echo "Timeout reached for SSH test '$test_name' after ${TEST_TIMEOUT} seconds. Killing process..."
            kill -9 "$ssh_pid" 2>/dev/null
        fi
    else
        sleep "$TEST_TIMEOUT"
        if kill -0 "$child_pid" 2>/dev/null; then
            echo "Timeout reached for test '$test_name' after ${TEST_TIMEOUT} seconds."
            kill -- -$child_pid 2>/dev/null
        fi
    fi

    # Encerra a coleta de estatísticas, se estiver ativa
    if [[ "$collect_stats" == "true" ]]; then
        echo "Encerrando coleta de estatísticas..."
        kill -SIGTERM "$stats_pid" 2>/dev/null
        wait "$stats_pid" 2>/dev/null
    fi

    ps aux | grep "qemu-system-x86_64" | grep -v grep | awk '{print $2}' | xargs kill -9 2>/dev/null

    echo "Finish Time: $(date)"
    echo "Waiting $WAIT_BETWEEN_TESTS seconds for the next test"
    sleep "$WAIT_BETWEEN_TESTS"
}



# Parameters:
#   $1 - Path of the VM image
#   $2 - VNC port
#   $3 - SSH port
#   $4 - Number of CPUs
#   $5 - RAM
startVM() {
    local vm_image="$1"
    local vnc_port="$2"
    local ssh_port="$3"
    local vm_cpus="$4"
    local vm_ram="$5"

    # Checks that all parameters have been provided
    if [ -z "$vm_image" ] || [ -z "$vnc_port" ] || [ -z "$ssh_port" ] || [ -z "$vm_cpus" ] || [ -z "$vm_ram" ]; then
        echo "Error: All parameters are required."
        echo "Usage: startVM <image> <vnc_port> <ssh_port> <cpus> <ram>"
        return 1
    fi

    echo "Starting VM with the following settings:"
    echo "  Image: $vm_image"
    echo "  VNC Port: $vnc_port"
    echo "  SSH Port: $ssh_port"
    echo "  CPUs: $vm_cpus"
    echo "  RAM: $vm_ram"

    # Starts the VM in the background
    qemu-system-x86_64 -enable-kvm -m "$vm_ram" -smp "$vm_cpus" \
        -hda "$vm_image" \
        -netdev user,id=net0,hostfwd=tcp::"$ssh_port"-:22 \
        -device virtio-net-pci,netdev=net0 \
        -vnc :"$vnc_port" -cpu host &

    # Wait for VM to initialise
    sleep 60

    # Run the stress command via SSH
    echo "Running stress on the VM"
    ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p "$ssh_port" "$SSH_USER"@127.0.0.1 "stress -c 10 -m 24 --vm-bytes 256M" &
    sleep 10
}



######################################
# Tests - No Stress
######################################

check_hyperthreading_CPU_Cores

# 1: Bare Metal 10000
#run_test "Bare Metal 10000" "BareMetal/Ubuntu/NoStress/RAW/bareMetal10000_NoStress.txt" false \
#    /home/samuel/apps/rt-tests/cyclictest -D 4h -v -i 10000

# 2: Bare Metal 1000
#run_test "Bare Metal 1000" "BareMetal/Ubuntu/NoStress/RAW/bareMetal1000_NoStress.txt" false \
#    /home/samuel/apps/rt-tests/cyclictest -D 4h -v -i 10000

# 3: Bare Metal 100
#run_test "Bare Metal 100" "BareMetal/Ubuntu/NoStress/RAW/bareMetal100_NoStress.txt" false \
#    /home/samuel/apps/rt-tests/cyclictest -D 4h -v -i 100

# 4: Nanos 10000
/home/samuel/.ops/bin/ops build /home/samuel/unikernels-aux/Nanos/cyclictest -c /home/samuel/unikernels/nanos/config10000.json # build Nanos with configs for this test

run_test "Nanos 10000" "QEMU/Nanos/NoStress/RAW/QemuNanosNoStress10000.txt" true \
    qemu-system-x86_64 -machine q35 \
      -device pcie-root-port,port=0x10,chassis=1,id=pci.1,bus=pcie.0,multifunction=on,addr=0x3 \
      -device pcie-root-port,port=0x11,chassis=2,id=pci.2,bus=pcie.0,addr=0x3.0x1 \
      -device pcie-root-port,port=0x12,chassis=3,id=pci.3,bus=pcie.0,addr=0x3.0x2 \
      -device virtio-scsi-pci,bus=pci.2,addr=0x0,id=scsi0 \
      -device scsi-hd,bus=scsi0.0,drive=hd0 \
      -vga none -device isa-debug-exit -smp cores=1 -vnc :10 \
      -gdb tcp::1234,server,nowait -m 1G \
      -device virtio-rng-pci -device virtio-balloon -enable-kvm \
      -cpu host -cpu max \
      -drive file=/root/.ops/images/cyclictest,format=raw,if=none,id=hd0 \
      -device virtio-net,bus=pci.3,addr=0x0,netdev=n0,mac=c2:c9:00:53:9d:ff \
      -netdev user,id=n0 -display none -serial stdio

# 5: Nanos 1000
/home/samuel/.ops/bin/ops build /home/samuel/unikernels-aux/Nanos/cyclictest -c /home/samuel/unikernels/nanos/config1000.json

run_test "Nanos 1000" "QEMU/Nanos/NoStress/RAW/QemuNanosNoStress1000.txt" false \
    qemu-system-x86_64 -machine q35 \
      -device pcie-root-port,port=0x10,chassis=1,id=pci.1,bus=pcie.0,multifunction=on,addr=0x3 \
      -device pcie-root-port,port=0x11,chassis=2,id=pci.2,bus=pcie.0,addr=0x3.0x1 \
      -device pcie-root-port,port=0x12,chassis=3,id=pci.3,bus=pcie.0,addr=0x3.0x2 \
      -device virtio-scsi-pci,bus=pci.2,addr=0x0,id=scsi0 \
      -device scsi-hd,bus=scsi0.0,drive=hd0 \
      -vga none -device isa-debug-exit -smp cores=1 -vnc :10 \
      -gdb tcp::1234,server,nowait -m 1G \
      -device virtio-rng-pci -device virtio-balloon -enable-kvm \
      -cpu host -cpu max \
      -drive file=/root/.ops/images/cyclictest,format=raw,if=none,id=hd0 \
      -device virtio-net,bus=pci.3,addr=0x0,netdev=n0,mac=c2:c9:00:53:9d:ff \
      -netdev user,id=n0 -display none -serial stdio

# 6: Nanos 100
/home/samuel/.ops/bin/ops build /home/samuel/unikernels-aux/Nanos/cyclictest -c /home/samuel/unikernels/nanos/config100.json

run_test "Nanos 100" "QEMU/Nanos/NoStress/RAW/QemuNanosNoStress100.txt" false \
    qemu-system-x86_64 -machine q35 \
      -device pcie-root-port,port=0x10,chassis=1,id=pci.1,bus=pcie.0,multifunction=on,addr=0x3 \
      -device pcie-root-port,port=0x11,chassis=2,id=pci.2,bus=pcie.0,addr=0x3.0x1 \
      -device pcie-root-port,port=0x12,chassis=3,id=pci.3,bus=pcie.0,addr=0x3.0x2 \
      -device virtio-scsi-pci,bus=pci.2,addr=0x0,id=scsi0 \
      -device scsi-hd,bus=scsi0.0,drive=hd0 \
      -vga none -device isa-debug-exit -smp cores=1 -vnc :10 \
      -gdb tcp::1234,server,nowait -m 1G \
      -device virtio-rng-pci -device virtio-balloon -enable-kvm \
      -cpu host -cpu max \
      -drive file=/root/.ops/images/cyclictest,format=raw,if=none,id=hd0 \
      -device virtio-net,bus=pci.3,addr=0x0,netdev=n0,mac=c2:c9:00:53:9d:ff \
      -netdev user,id=n0 -display none -serial stdio

# 7: OSv 10000
./scripts/manifest_from_host.sh -w /home/samuel/unikernels-aux/Nanos/cyclictest # build OSv with Cyclictest

echo "/cyclictest -D 4h -v -i 10000 -p99" > ./build/release/append_cmdline # add command
./scripts/build --append-manifest

run_test "OSv 10000" "QEMU/OSv/NoStress/RAW/QemuKVMOSvNoStress10000.txt" false \
    qemu-system-x86_64 -m 1G -smp cores=1 \
      -vnc :10 -gdb tcp::1234,server,nowait \
      -device virtio-blk-pci,id=blk0,drive=hd0,scsi=off,bootindex=0 \
      -drive file=/home/samuel/unikernels/osv/build/last/usr.img,if=none,id=hd0,cache=none,aio=native \
      -netdev user,id=un0,net=192.168.122.0/24,host=192.168.122.1 \
      -device virtio-net-pci,netdev=un0 \
      -device virtio-rng-pci -enable-kvm -cpu host -cpu max \
      -chardev stdio,mux=on,id=stdio,signal=on \
      -mon chardev=stdio,mode=readline \
      -device isa-serial,chardev=stdio

# 8: OSv 1000
echo "/cyclictest -D 4h -v -i 1000 -p99" > ./build/release/append_cmdline
./scripts/build --append-manifest

run_test "OSv 1000" "QEMU/OSv/NoStress/RAW/QemuKVMOSvNoStress1000.txt" false \
    qemu-system-x86_64 -m 1G -smp cores=1 \
      -vnc :10 -gdb tcp::1234,server,nowait \
      -device virtio-blk-pci,id=blk0,drive=hd0,scsi=off,bootindex=0 \
      -drive file=/home/samuel/unikernels/osv/build/last/usr.img,if=none,id=hd0,cache=none,aio=native \
      -netdev user,id=un0,net=192.168.122.0/24,host=192.168.122.1 \
      -device virtio-net-pci,netdev=un0 \
      -device virtio-rng-pci -enable-kvm -cpu host -cpu max \
      -chardev stdio,mux=on,id=stdio,signal=on \
      -mon chardev=stdio,mode=readline \
      -device isa-serial,chardev=stdio

# 9: OSv 100
echo "/cyclictest -D 4h -v -i 100 -p99" > ./build/release/append_cmdline
./scripts/build --append-manifest

run_test "OSv 100" "QEMU/OSv/NoStress/RAW/QemuKVMOSvNoStress100.txt" false \
    qemu-system-x86_64 -m 1G -smp cores=1 \
      -vnc :10 -gdb tcp::1234,server,nowait \
      -device virtio-blk-pci,id=blk0,drive=hd0,scsi=off,bootindex=0 \
      -drive file=/home/samuel/unikernels/osv/build/last/usr.img,if=none,id=hd0,cache=none,aio=native \
      -netdev user,id=un0,net=192.168.122.0/24,host=192.168.122.1 \
      -device virtio-net-pci,netdev=un0 \
      -device virtio-rng-pci -enable-kvm -cpu host -cpu max \
      -chardev stdio,mux=on,id=stdio,signal=on \
      -mon chardev=stdio,mode=readline \
      -device isa-serial,chardev=stdio

# 10. AppBox 10000
/home/samuel/unikernels/Unikernel---Proof-of-Concept/Scripts/build.sh \
    /home/samuel/unikernels/rt-tests/cyclictest -D 4h -v -i 10000 -p99

run_test "AppBox 10000" "QEMU/AppBox/NoStress/RAW/QemuAppBox_10000_NoStress.txt" false \
    qemu-system-x86_64 \
      -kernel /home/samuel/unikernels/Unikernel---Proof-of-Concept/kernel/arch/x86_64/boot/bzImage \
      -initrd /home/samuel/unikernels/Unikernel---Proof-of-Concept/Output/RAW/image.img \
      -append "console=ttyS0 isolcpus=1 nohz_full=1 rcu_nocbs=1" -enable-kvm -nographic -m 1G -smp 1 -cpu host

# 11. AppBox 1000
/home/samuel/unikernels/Unikernel---Proof-of-Concept/Scripts/build.sh \
    /home/samuel/unikernels/rt-tests/cyclictest -D 4h -v -i 1000 -p99

run_test "AppBox 1000" "QEMU/AppBox/NoStress/RAW/QemuAppBox_1000_NoStress.txt" false \
    qemu-system-x86_64 \
      -kernel /home/samuel/unikernels/Unikernel---Proof-of-Concept/kernel/arch/x86_64/boot/bzImage \
      -initrd /home/samuel/unikernels/Unikernel---Proof-of-Concept/Output/RAW/image.img \
      -append "console=ttyS0 isolcpus=1 nohz_full=1 rcu_nocbs=1" -enable-kvm -nographic -m 1G -smp 1 -cpu host

# 12. AppBox 100
/home/samuel/unikernels/Unikernel---Proof-of-Concept/Scripts/build.sh \
    /home/samuel/unikernels/rt-tests/cyclictest -D 4h -v -i 100 -p99

run_test "AppBox 100" "QEMU/AppBox/NoStress/RAW/QemuAppBox_100_NoStress.txt" false \
    qemu-system-x86_64 \
      -kernel /home/samuel/unikernels/Unikernel---Proof-of-Concept/kernel/arch/x86_64/boot/bzImage \
      -initrd /home/samuel/unikernels/Unikernel---Proof-of-Concept/Output/RAW/image.img \
      -append "console=ttyS0 isolcpus=1 nohz_full=1 rcu_nocbs=1" -enable-kvm -nographic -m 1G -smp 1 -cpu host

# 13. Ubuntu RT 10000
CYCLICTEST_INTERVAL=10000
run_test "Ubuntu RT 10000" "QEMU/Ubuntu/NoStress/RAW/QemuUbuntuRT_10000_NoStress.txt" false \
    qemu-system-x86_64 -enable-kvm -m 1G -smp 1 \
        -hda /home/samuel/unikernels/stressVM/cyclictest.img \
        -netdev user,id=net0,hostfwd=tcp::2222-:22 \
        -device virtio-net-pci,netdev=net0 \
        -vnc :3 -cpu host

# 14. Ubuntu RT 1000
CYCLICTEST_INTERVAL=1000
run_test "Ubuntu RT 1000" "QEMU/Ubuntu/NoStress/RAW/QemuUbuntuRT_1000_NoStress.txt" false \
    qemu-system-x86_64 -enable-kvm -m 1G -smp 1 \
        -hda /home/samuel/unikernels/stressVM/cyclictest.img \
        -netdev user,id=net0,hostfwd=tcp::2222-:22 \
        -device virtio-net-pci,netdev=net0 \
        -vnc :3 -cpu host

# 15. Ubuntu RT 100
CYCLICTEST_INTERVAL=100
run_test "Ubuntu RT 100" "QEMU/Ubuntu/NoStress/RAW/QemuUbuntuRT_100_NoStress.txt" false \
    qemu-system-x86_64 -enable-kvm -m 1G -smp 1 \
        -hda /home/samuel/unikernels/stressVM/cyclictest.img \
        -netdev user,id=net0,hostfwd=tcp::2222-:22 \
        -device virtio-net-pci,netdev=net0 \
        -vnc :3 -cpu host



######################################
# Tests - Stress
######################################

#Turn On Stress VMS
startVM "/home/samuel/unikernels/stressVM/stress1.img" 1 2223 2 8G
startVM "/home/samuel/unikernels/stressVM/stress2.img" 2 2224 2 8G

# 1: Bare Metal 10000
#run_test "Bare Metal 10000" "BareMetal/Ubuntu/Stress/RAW/bareMetal10000_Stress.txt" false \
#    /home/samuel/apps/rt-tests/cyclictest -D 4h -v -i 10000

# 2: Bare Metal 1000
#run_test "Bare Metal 1000" "BareMetal/Ubuntu/Stress/RAW/bareMetal1000_Stress.txt" false \
#    /home/samuel/apps/rt-tests/cyclictest -D 4h -v -i 10000

# 3: Bare Metal 100
#run_test "Bare Metal 100" "BareMetal/Ubuntu/Stress/RAW/bareMetal100_Stress.txt" false \
#    /home/samuel/apps/rt-tests/cyclictest -D 4h -v -i 100

# 4: Nanos 10000
/home/samuel/.ops/bin/ops build /home/samuel/unikernels-aux/Nanos/cyclictest -c /home/samuel/unikernels/nanos/config10000.json

run_test "Nanos 10000" "QEMU/Nanos/Stress/RAW/QemuNanosStress10000.txt" false \
    qemu-system-x86_64 -machine q35 \
      -device pcie-root-port,port=0x10,chassis=1,id=pci.1,bus=pcie.0,multifunction=on,addr=0x3 \
      -device pcie-root-port,port=0x11,chassis=2,id=pci.2,bus=pcie.0,addr=0x3.0x1 \
      -device pcie-root-port,port=0x12,chassis=3,id=pci.3,bus=pcie.0,addr=0x3.0x2 \
      -device virtio-scsi-pci,bus=pci.2,addr=0x0,id=scsi0 \
      -device scsi-hd,bus=scsi0.0,drive=hd0 \
      -vga none -device isa-debug-exit -smp cores=1 -vnc :10 \
      -gdb tcp::1234,server,nowait -m 1G \
      -device virtio-rng-pci -device virtio-balloon -enable-kvm \
      -cpu host -cpu max \
      -drive file=/root/.ops/images/cyclictest,format=raw,if=none,id=hd0 \
      -device virtio-net,bus=pci.3,addr=0x0,netdev=n0,mac=c2:c9:00:53:9d:ff \
      -netdev user,id=n0 -display none -serial stdio

# 5: Nanos 1000
/home/samuel/.ops/bin/ops build /home/samuel/unikernels-aux/Nanos/cyclictest -c /home/samuel/unikernels/nanos/config1000.json

run_test "Nanos 1000" "QEMU/Nanos/Stress/RAW/QemuNanosStress1000.txt" false \
    qemu-system-x86_64 -machine q35 \
      -device pcie-root-port,port=0x10,chassis=1,id=pci.1,bus=pcie.0,multifunction=on,addr=0x3 \
      -device pcie-root-port,port=0x11,chassis=2,id=pci.2,bus=pcie.0,addr=0x3.0x1 \
      -device pcie-root-port,port=0x12,chassis=3,id=pci.3,bus=pcie.0,addr=0x3.0x2 \
      -device virtio-scsi-pci,bus=pci.2,addr=0x0,id=scsi0 \
      -device scsi-hd,bus=scsi0.0,drive=hd0 \
      -vga none -device isa-debug-exit -smp cores=1 -vnc :10 \
      -gdb tcp::1234,server,nowait -m 1G \
      -device virtio-rng-pci -device virtio-balloon -enable-kvm \
      -cpu host -cpu max \
      -drive file=/root/.ops/images/cyclictest,format=raw,if=none,id=hd0 \
      -device virtio-net,bus=pci.3,addr=0x0,netdev=n0,mac=c2:c9:00:53:9d:ff \
      -netdev user,id=n0 -display none -serial stdio

# 6: Nanos 100
/home/samuel/.ops/bin/ops build /home/samuel/unikernels-aux/Nanos/cyclictest -c /home/samuel/unikernels/nanos/config100.json

run_test "Nanos 100" "QEMU/Nanos/Stress/RAW/QemuNanosStress100.txt" false \
    qemu-system-x86_64 -machine q35 \
      -device pcie-root-port,port=0x10,chassis=1,id=pci.1,bus=pcie.0,multifunction=on,addr=0x3 \
      -device pcie-root-port,port=0x11,chassis=2,id=pci.2,bus=pcie.0,addr=0x3.0x1 \
      -device pcie-root-port,port=0x12,chassis=3,id=pci.3,bus=pcie.0,addr=0x3.0x2 \
      -device virtio-scsi-pci,bus=pci.2,addr=0x0,id=scsi0 \
      -device scsi-hd,bus=scsi0.0,drive=hd0 \
      -vga none -device isa-debug-exit -smp cores=1 -vnc :10 \
      -gdb tcp::1234,server,nowait -m 1G \
      -device virtio-rng-pci -device virtio-balloon -enable-kvm \
      -cpu host -cpu max \
      -drive file=/root/.ops/images/cyclictest,format=raw,if=none,id=hd0 \
      -device virtio-net,bus=pci.3,addr=0x0,netdev=n0,mac=c2:c9:00:53:9d:ff \
      -netdev user,id=n0 -display none -serial stdio

# 7: OSv 10000
echo "/cyclictest -D 4h -v -i 10000 -p99" > ./build/release/append_cmdline
./scripts/build --append-manifest

run_test "OSv 10000" "QEMU/OSv/Stress/RAW/QemuKVMOSvStress10000.txt" false \
    qemu-system-x86_64 -m 1G -smp cores=1 \
      -vnc :10 -gdb tcp::1234,server,nowait \
      -device virtio-blk-pci,id=blk0,drive=hd0,scsi=off,bootindex=0 \
      -drive file=/home/samuel/unikernels/osv/build/last/usr.img,if=none,id=hd0,cache=none,aio=native \
      -netdev user,id=un0,net=192.168.122.0/24,host=192.168.122.1 \
      -device virtio-net-pci,netdev=un0 \
      -device virtio-rng-pci -enable-kvm -cpu host -cpu max \
      -chardev stdio,mux=on,id=stdio,signal=on \
      -mon chardev=stdio,mode=readline \
      -device isa-serial,chardev=stdio

# 8: OSv 1000
echo "/cyclictest -D 4h -v -i 1000 -p99" > ./build/release/append_cmdline
./scripts/build --append-manifest

run_test "OSv 1000" "QEMU/OSv/Stress/RAW/QemuKVMOSvStress1000.txt" false \
    qemu-system-x86_64 -m 1G -smp cores=1 \
      -vnc :10 -gdb tcp::1234,server,nowait \
      -device virtio-blk-pci,id=blk0,drive=hd0,scsi=off,bootindex=0 \
      -drive file=/home/samuel/unikernels/osv/build/last/usr.img,if=none,id=hd0,cache=none,aio=native \
      -netdev user,id=un0,net=192.168.122.0/24,host=192.168.122.1 \
      -device virtio-net-pci,netdev=un0 \
      -device virtio-rng-pci -enable-kvm -cpu host -cpu max \
      -chardev stdio,mux=on,id=stdio,signal=on \
      -mon chardev=stdio,mode=readline \
      -device isa-serial,chardev=stdio

# 9: OSv 100
echo "/cyclictest -D 4h -v -i 100 -p99" > ./build/release/append_cmdline
./scripts/build --append-manifest

run_test "OSv 100" "QEMU/OSv/Stress/RAW/QemuKVMOSvStress100.txt" false \
    qemu-system-x86_64 -m 1G -smp cores=1 \
      -vnc :10 -gdb tcp::1234,server,nowait \
      -device virtio-blk-pci,id=blk0,drive=hd0,scsi=off,bootindex=0 \
      -drive file=/home/samuel/unikernels/osv/build/last/usr.img,if=none,id=hd0,cache=none,aio=native \
      -netdev user,id=un0,net=192.168.122.0/24,host=192.168.122.1 \
      -device virtio-net-pci,netdev=un0 \
      -device virtio-rng-pci -enable-kvm -cpu host -cpu max \
      -chardev stdio,mux=on,id=stdio,signal=on \
      -mon chardev=stdio,mode=readline \
      -device isa-serial,chardev=stdio

# 10. AppBox 10000
/home/samuel/unikernels/Unikernel---Proof-of-Concept/Scripts/build.sh \
    /home/samuel/unikernels/rt-tests/cyclictest -D 4h -v -i 10000 -p99

run_test "AppBox 10000" "QEMU/AppBox/Stress/RAW/QemuAppBox_10000_Stress.txt" false \
    qemu-system-x86_64 \
      -kernel /home/samuel/unikernels/Unikernel---Proof-of-Concept/kernel/arch/x86_64/boot/bzImage \
      -initrd /home/samuel/unikernels/Unikernel---Proof-of-Concept/Output/RAW/image.img \
      -append "console=ttyS0 isolcpus=1 nohz_full=1 rcu_nocbs=1" -enable-kvm -nographic -m 1G -smp 1 -cpu host

# 11. AppBox 1000
/home/samuel/unikernels/Unikernel---Proof-of-Concept/Scripts/build.sh \
    /home/samuel/unikernels/rt-tests/cyclictest -D 4h -v -i 1000 -p99

run_test "AppBox 1000" "QEMU/AppBox/Stress/RAW/QemuAppBox_1000_Stress.txt" false \
    qemu-system-x86_64 \
      -kernel /home/samuel/unikernels/Unikernel---Proof-of-Concept/kernel/arch/x86_64/boot/bzImage \
      -initrd /home/samuel/unikernels/Unikernel---Proof-of-Concept/Output/RAW/image.img \
      -append "console=ttyS0 isolcpus=1 nohz_full=1 rcu_nocbs=1" -enable-kvm -nographic -m 1G -smp 1 -cpu host

# 12. AppBox 100
/home/samuel/unikernels/Unikernel---Proof-of-Concept/Scripts/build.sh \
    /home/samuel/unikernels/rt-tests/cyclictest -D 4h -v -i 100 -p99

run_test "AppBox 100" "QEMU/AppBox/Stress/RAW/QemuAppBox_100_Stress.txt" false \
    qemu-system-x86_64 \
      -kernel /home/samuel/unikernels/Unikernel---Proof-of-Concept/kernel/arch/x86_64/boot/bzImage \
      -initrd /home/samuel/unikernels/Unikernel---Proof-of-Concept/Output/RAW/image.img \
      -append "console=ttyS0 isolcpus=1 nohz_full=1 rcu_nocbs=1" -enable-kvm -nographic -m 1G -smp 1 -cpu host

# 13. Ubuntu RT 10000
CYCLICTEST_INTERVAL=10000
run_test "Ubuntu RT 10000" "QEMU/Ubuntu/Stress/RAW/QemuUbuntuRT_10000_Stress.txt" false \
    qemu-system-x86_64 -enable-kvm -m 1G -smp 1 \
        -hda /home/samuel/unikernels/stressVM/cyclictest.img \
        -netdev user,id=net0,hostfwd=tcp::2222-:22 \
        -device virtio-net-pci,netdev=net0 \
        -vnc :3 -cpu host

# 14. Ubuntu RT 1000
CYCLICTEST_INTERVAL=1000
run_test "Ubuntu RT 1000" "QEMU/Ubuntu/Stress/RAW/QemuUbuntuRT_1000_Stress.txt" false \
    qemu-system-x86_64 -enable-kvm -m 1G -smp 1 \
        -hda /home/samuel/unikernels/stressVM/cyclictest.img \
        -netdev user,id=net0,hostfwd=tcp::2222-:22 \
        -device virtio-net-pci,netdev=net0 \
        -vnc :3 -cpu host

# 15. Ubuntu RT 100
CYCLICTEST_INTERVAL=100
run_test "Ubuntu RT 100" "QEMU/Ubuntu/Stress/RAW/QemuUbuntuRT_100_Stress.txt" false \
    qemu-system-x86_64 -enable-kvm -m 1G -smp 1 \
        -hda /home/samuel/unikernels/stressVM/cyclictest.img \
        -netdev user,id=net0,hostfwd=tcp::2222-:22 \
        -device virtio-net-pci,netdev=net0 \
        -vnc :3 -cpu host



echo All tests have been completed
