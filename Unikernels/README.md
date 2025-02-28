# Unikernels Installation Guide  

This guide provides step-by-step instructions for installing and setting up various unikernels. Below, you'll find details for each unikernel, including prerequisites, installation steps, and execution environments.  

---

## 📋 Unikernels Overview 
| Unikernel | Type      | Execution Environment | Languages   | Last Update  |  
|----------------|------------------------|----------------|---------------|-------------------------|  
| HermiTux  | POSIX     | QEMU/KVM, Uhyve       | C/C++, Python, Lua, Rust | 17/11/2023 |  
| MirageOS  | Non-POSIX | UNIX, Xen, KVM, FreeBSD   | OCaml | 10/04/2024    |  
| Nanos     | POSIX     | QEMU/KVM, XEN, VMware ESXi, Amazon EC2, Google Cloud, HyperV, Oracle, RPI4   | C/C++, Go, Java, Node.js, Python, PHP, Ruby, Ruby  | 17/04/2024    |  
| OSv       | POSIX     | QEMU/KVM, Firecracker, Cloud Hypervisor, Xen, VMware ESXi, VMware Workstation, VirtualBox, Hyperkit    | C/C++, Java, Node.js, Ruby, Erlang, Go, Rust   | 19/03/2024 | 
| UKL       | POSIX     | QEMU/KVM (VMware ESXi and VMware Workstation)  | C/C++ | 08/09/2023 |
| Unikraft  | POSIX     | QEMU/KVM, XEN | C/C++, Python, Go, Rust, Lua  | 05/04/2024 |

*Last updated: 07 June 2024*

---

## 🛠️ Prerequisites  
Before installing any unikernel, ensure the following tools are installed on your system:  
- **QEMU/KVM**: For running most unikernels.  
  ```bash
  sudo apt-get install qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils virt-manager
  ```
- **Git**: For cloning repositories.
    ```bash
    sudo apt-get install git
    ```

- **OCaml** (for MirageOS):
    ```bash
    sudo apt-get install ocaml opam
    ```
---

## 🚀 Unikernel Installation
### HermiTux
#### 1. **Install Dependencies**
First, update the system and install the necessary dependencies:
```bash
sudo apt update
sudo apt install git build-essential cmake nasm apt-transport-https wget \
libgmp-dev bsdmainutils libseccomp-dev python3 libelf-dev
```
#### 2. **Install HermitCore Toolchain**:
The HermitCore toolchain will be installed in `/opt/hermit`. Run the following command to download and install the required packages:
```bash
for dep in binutils-hermit_2.30.51-1_amd64.deb gcc-hermit_6.3.0-1_amd64.deb \
    libhermit_0.2.10_all.deb  newlib-hermit_2.4.0-1_amd64.deb; do \
    wget https://github.com/ssrg-vt/hermitux/releases/download/v1.0/$dep && \
    sudo dpkg -i $dep && \
    rm $dep;
done
```
#### 3. **Clone the Repository and Initialise Submodules**:
Clone the HermiTux repository and initialise the submodules:
```bash
git clone https://github.com/ssrg-vt/hermitux
cd hermitux
git submodule init && git submodule update
```
#### 4. **Build HermiTux**:
Compile HermiTux using the following command. **This step is only required once**:
```bash
make
```
#### 5. **Run an Application**:
Once HermiTux is built, you can run any application without repeating the previous steps. Navigate to the app directory, compile it, and execute it with HermiTux:
```bash
cd <your-app-directory>
gcc *.c -o <your-app> -static
sudo HERMIT_ISLE=uhyve HERMIT_TUX=1 ../../../hermitux-kernel/prefix/bin/proxy \
    ../../../hermitux-kernel/prefix/x86_64-hermit/extra/tests/hermitux <your-app>
```

### MirageOS
#### 1. **Install Dependencies**:
Update your system and install the required dependencies, including OPAM:
```bash
sudo apt update
sudo apt-get install opam
```
#### 2. **Initialise OPAM**:
Initialise OPAM and set up the environment:
```bash
opam init
eval `opam config env`
```
#### 3. **Install MirageOS**:
Install the MirageOS toolchain using OPAM:
```bash
opam install mirage
```
#### 4. **Configure the Unikernel**:
Navigate to your project directory and configure the unikernel for the desired target (e.g., `unix` for running on a Unix system):
```bash
cd <your-app-directory>
mirage configure -t unix
```
#### 5. **Build and Run the Unikernel**:
Build and Run the unikernel with:
```bash
make depend
make
./<your-app>
```

### Nanos
#### 1. **Install Ops**:
Ops is the tool used to run applications on Nanos. Install it with the following command:
```bash
sudo curl https://ops.city/get.sh -sSfL | sh
```
#### 2. **Run an Application**:
Once Ops is installed, you can run a pre-compiled application directly. Use the following command, replacing `<your-app>` with the path to your binary:
```bash
ops run <your-app>
```
This command will automatically package and launch your application using Nanos.

### OSv
#### 1. **Install Dependencies**
Update your system and set up the environment. This step is only required once:

```bash
sudo apt update
sudo apt install git
```
The OSv build process requires **libssl1.1**. Download and install it manually:
```bash
wget http://archive.ubuntu.com/ubuntu/pool/main/o/openssl/libssl1.1_1.1.0g-2ubuntu4_amd64.deb
sudo dpkg -i libssl1.1_1.1.0g-2ubuntu4_amd64.deb
```
#### 2. **Clone the Repository, Initialise Submodules, Setup and Build**
This step is only required once:
```bash
git clone https://github.com/cloudius-systems/osv.git
cd osv && git submodule update --init --recursive
sudo ./scripts/setup.py
sudo ./scripts/build
```
#### 3. **Run an Application**:
Once OSv is set up, you can run any application without repeating the initial setup. Follow these steps:
- ##### 1. **Generate the Manifest**:

Use the `manifest_from_host.sh` script to create a manifest for your application:
```bash
sudo ./scripts/manifest_from_host.sh -w <your-app>
```
- ##### 2. **Build with the Manifest**:

Append the manifest to the OSv image:
```bash
sudo ./scripts/build --append-manifest
```
- ##### 3. **Optional: Edit Command-Line Arguments**:

If your application requires specific arguments (e.g., ./app -10000 -v -D 4h), edit the `/build/release.x64/append_cmdline` file to include them before running the application.
- ##### 4. **Run the Application**:

Start the application with OSv:
```bash
sudo ./scripts/run.py
```

### UKL
#### 1. **Install Dependencies**:
Before setting up UKL, install all the required dependencies with the following command:
```bash
sudo apt update
sudo apt install -y git autoconf automake build-essential gcc clang make sed qemu libssl-dev libelf-dev bc bison flex libncurses-dev libssl-dev libelf-dev
```
#### 2. **Clone the Repository**:
Clone the UKL repository and initialise submodules. This step is only required once:
```bash
git clone https://github.com/unikernelLinux/ukl.git
cd ukl
git submodule update --init
```
#### 3. **Set Up the Build Environment**:
Generate the necessary configuration files. This step is also only required once:
```bash
autoreconf -i
```
#### 4. **Configure and Build UKL**:
Configure and build UKL for your specific application. Replace `<your-app-directory>` with the path to your application:
```bash
./configure --with-program=<your-app-directory>
make -j`nproc` compile
```
#### 5. **Run an Application**:
Once the build is complete, you can run your application with:
```bash
make boot
```

### Unikraft
#### 1. **Install KraftKit**:
KraftKit is the tool used to build and run Unikraft unikernels. Install it with the following command:
```bash
curl -sSfL https://get.kraftkit.sh | sh
```
#### 2. **Run the Unikernel**:
Once KraftKit is installed and your application is compiled, you can run the unikernel using the following command. Replace `<your-app>` with the path to your pre-compiled application:
```bash
kraft run <your-app>
```
This command will automatically configure and launch your application as a unikernel.

#### 3. **Optional: Use Docker for Compilation**:
If your application is not pre-compiled, KraftKit can use Docker to build the necessary components before running the unikernel. This step is optional and depends on your application's requirements.

---

## Run some Unikernels in VMware ESXi
This guide explains how to run **Nanos**, **OSv**, and **UKL** unikernels on **VMware ESXi**. Each unikernel requires a slightly different setup process.
Only these 3 unikernels can be built/adapted to run on ESXi.

### Prerequisites
- VMware ESXi installed and configured.
- Access to the ESXi web interface.

### Nanos
#### 1. **Create a Raw Disk Image**:
Build your application using Ops to generate a raw disk image:

```bash
ops build <your-app>
```
This will create a `.img` file (e.g., `<your-app>.img`).

#### 2. **Convert the Image to VMDK**:
Convert the raw image to a VMware-compatible `.vmdk` format using `qemu-img`:
```bash
qemu-img convert -f raw -O vmdk <your-app>.img <your-app>.vmdk
```

#### 3. **Create a New VM in VMware Workstation**:
- Create a New Virtual Machine
- Choose Workstation 15.x or ESXi in the hardware compatibility
- Select ***I will install the operating system later***
- Set the Guest operating system to Other > Other
- On the Select a Disk screen, choose ***Use an existing disk*** and select the `.vmdk` file you created
- When prompted to ***Convert existing virtual disk to newer format***, select ***Convert***
- Before starting the VM, open the `.vmx` file of the VM and put `ethernet0.virtualDev = "vmxnet3"`

#### 4. **Convert to OVF and Import to ESXi**:
- In VMware Workstation, convert the VM to OVF format:
    - Go to File > Export to OVF
    - Save the OVF file
- Import the OVF file into your VMware ESXi host

#### 5. **Run the VM**:
- Power on the VM in ESXi
- The Nanos unikernel should boot and run your application

### OSv
#### 1. **Build the Unikernel**:
Compile the Unikernel with the application, as shown before:
```bash
sudo ./scripts/build --append-manifest
```
#### 2. **Convert the Image to VMDK Format**:
Use the OSv script to convert the built image to a VMware-compatible `.vmdk` file
```bash
./scripts/convert vmdk
```
This will create a `.vmdk` file in the `build/release/` directory.

#### 3. **Generate the VMX Configuration File**
Generate the `.vmx` configuration file required for VMware using the OSv script:
```bash
./scripts/gen-vmx.sh
```
This script will create a `.vmx` file in the build/release/ directory, which contains the necessary settings for running the VM.

#### 4. **Convert to OVF and Import to ESXi**:
- Import `.vmx` and `.vmdk into VMWare Workstation
- In VMware Workstation, convert the VM to OVF format:
    - Go to File > Export to OVF
    - Save the OVF file
- Import the OVF file into your VMware ESXi host

#### 5. **Run the VM**:
- Power on the VM in ESXi
- The OSv unikernel should boot and run your application

### UKL
#### 1. **Configure and Build UKL**:
Configure and build UKL for your specific application. Replace `<your-app-directory>` with the path to your application:
```bash
./configure --with-program=<your-app-directory>
make -j`nproc` compile
```
#### 2. **Convert the UKL**:
Run the `convertUKLtoESXi.sh` script developed during the thesis:
```bash
./convertUKLtoESXi.sh
```
#### 3. **Convert to OVF and Import to ESXi**:
- Import `.vmx` and `.vmdk into VMWare Workstation
- In VMware Workstation, convert the VM to OVF format:
    - Go to File > Export to OVF
    - Save the OVF file
- Import the OVF file into your VMware ESXi host

#### 4. **Run the VM**:
- Power on the VM in ESXi
- The UKL unikernel should boot and run your application

---  
*Last updated: 12 February 2025*
