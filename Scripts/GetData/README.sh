# Scripts for Data Collection on QEMU and ESXi Hypervisors  

This repository contains two scripts, `getDataQemu.sh` and `getDataESXi.py`, designed to collect performance data from **unikernels** running on **QEMU** and **ESXi** hypervisors with **Cyclictest Tool**. These scripts automate the process of starting, testing, and destroying virtual machines (VMs) while gathering relevant metrics.  

---

## 📂 Script Overview  
- **`getDataQemu.sh`**: Collects data from VMs running on **QEMU/KVM**.  
- **`getDataESXi.py`**: Collects data from VMs running on **VMware ESXi**.  

Both scripts are designed to work with the following projects:  
- **Nanos**  
- **OSv**  
- **AppBox**
- **Ubuntu RT**

Additionally, they require **Ubuntu VMs** for running stress tests.  

---

## 🖥️ QEMU/KVM Setup  

### Prerequisites  
1. **Ubuntu VM Configuration**:  
   - Ubuntu VMs must be configured to **auto-login** without requiring a password.  
   - Ensure the following packages are installed on the stress VMs:  
     ```bash
     sudo apt-get install stress screen
     ```  
   - Install **Nanos**, **OSv**, and **AppBox** on the host.  

2. **Script Configuration**:  
   - Edit the `getDataQemu.sh` script to specify:  
     - The **directory** where data will be saved.  
     - The **SSH username** for accessing the VMs.  
     - The **installation paths** for Nanos, OSv, and AppBox.  

3. **Automation**:  
   - The script automatically **creates and destroys** VMs during execution.  

### Usage  
Run the script in your terminal:  
```bash
./getDataQemu.sh
```

## 🖥️ ESXi Setup
### Prerequisites  
1. **Enable SSH on ESXi**:
    - Log in to the ESXi host.
    - Go to Host > Actions > Services > Enable SSH.

2. **VM Preparation**:
    - Pre-install the following VMs on ESXi:
        - Unikernels: Nanos, OSv, AppBox.
        - Ubuntu (for stress tests).
    - Install the required packages on the stress VMs:
        ```bash
        sudo apt-get install stress screen
        ```

3. **Script Configuration**:
    - Edit the getDataESXi.py script to specify:
        - The IDs and IP addresses of the VMs.
        - The directory where data will be saved.

4. **Automation**:
    - The script automatically creates and destroys VMs during execution.

### Usage  
Run the script in your terminal:  
```bash
python3 getDataESXi.py
```

## 📊 Data Collection
Both scripts collect data from running Cyclictest on Unikernels and Operating Systems while executing tests with and without stress (parallel workload). The data is saved in the specified directories for later analysis. For QEMU analyses, CPU and RAM consumption data is also collected.

*Last updated: February 2025*
