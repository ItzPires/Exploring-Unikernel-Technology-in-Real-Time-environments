# Exploring Unikernel Technology in Real-Time Environments  
**Master's Thesis - 2024/2025**  
**FCTUC - Universidade de Coimbra**

---

## 📖 Introduction and Objectives  
This thesis investigates the viability of **unikernels** in **real-time environments**. The primary goal is to evaluate whether these highly specialized, lightweight systems can meet the strict determinism and predictability requirements of real-time applications in fields like aviation, medicine, and finance.  

---

## 🧠 State of the Art  
### What is a Unikernel?  
A unikernel is a **minimalistic, single-address-space system** containing *only* the OS components and libraries required to run a specific application. Unlike traditional OSs, they eliminate unnecessary functionalities, reducing attack surfaces and resource usage.  

![GPOS vs Unikernels](/Images/OStoUnikernel.png)
- **Left (General Purpose OS)**: Includes generic components, with a subset (highlighted) used by the application.  
- **Right (Unikernels)**: Contains only essential components (highlighted) for a single application.  

### Real-Time Environments  
- **Definition**: Systems that guarantee task execution within **strict deadlines**.  
- **Key Requirements**: Predictability, determinism, fault tolerance.  
- **Types**: Hard (zero tolerance), Firm (tolerate minor delays), Soft (tolerate delays with degraded performance).  

---

## 🔍 Exploratory Work  
### Unikernel Framework Selection  
- **Initial Pool**: 17 frameworks identified.  
- **Selection Criteria**: Active repositories, documentation, community support, framework diversity.  
- **Final Selection**: 6 frameworks (see table below).  

| Unikernel | Type      | Execution Environment | Languages   | Last Update  |  
|----------------|------------------------|----------------|---------------|-------------------------|  
| HermiTux  | POSIX     | QEMU/KVM, Uhyve       | C/C++, Python, Lua, Rust | 17/11/2023 |  
| MirageOS  | Non-POSIX | UNIX, Xen, KVM, FreeBSD   | OCaml | 10/04/2024    |  
| Nanos     | POSIX     | QEMU/KVM, XEN, ESXi, Amazon EC2, Google Cloud, HyperV, Oracle, RPI4   | C/C++, Go, Java, Node.js, Python, PHP, Ruby, Ruby  | 17/04/2024    |  
| OSv       | POSIX     | QEMU/KVM, Firecracker, Cloud Hypervisor, Xen, VMWare, VirtualBox, Hyperkit    | C/C++, Java, Node.js, Ruby, Erlang, Go, Rust   | 19/03/2024 | 
| UKL       | POSIX     | QEMU/KVM  | C/C++ | 08/09/2023 |
| Unikraft  | POSIX     | QEMU/KVM, XEN | C/C++, Python, Go, Rust, Lua  | 05/04/2024 |

*Last updated: 07 June 2024*

## 🧪 Tests with Unikernels  
### Initial Results  
| Project Name | Hello Word | Small Application | Cyclictest | Jitterdebugger |
|--------------|------------|----------------|------------|----------------|
| Hermitux     | ✓          | ✓              | ✗          | ✗              |
| Mirage OS    | ✓          | ✓              | ✗          | ✗              |
| Nanos        | ✓          | ✓              | ✗          | ✗              |
| OSv          | ✓          | ✓              | ✗          | ✗              |
| UKL          | ✓          | ✓              | ✗          | ✗              |
| Unikraft     | ✓          | ✓              | ✗          | ✗              | 

### Key Challenges  
- **MirageOS**: Requires OCaml rewrites (non-POSIX limitation).  
- **POSIX Unikernels**: Critical syscalls missing (e.g., `clock_nanosleep`).  

### Breakthrough: Syscall Analysis  
- **Method**: Mapped syscalls required by Cyclictest/Jitterdebugger against unikernel capabilities.  
- **Solution**: Implemented missing syscalls. 

### Final Results for Exploratory Work
| Project Name | Hello Word | Wind Vibration | Cyclictest | Jitterdebugger |
|--------------|------------|----------------|------------|----------------|
| Nanos        | ✓          | ✓              | ✗          | ✗              |
| OSv Modified | ✓          | ✓              | ✗          | ✗              |
---

## 💡 Proof of Concept: AppBox  
### Concept  
A **Linux-based minimalist system** bridging the gap between unikernels and traditional OSs:  
- **Kernel**: Full Linux kernel (ensures syscall compatibility).  
- **Minimalism**: Stripped-down userspace (smaller footprint than conventional OSs).  

**Comparison**:  
| System          | Kernel Completeness | Syscall Support | Specialization |  
|-----------------|---------------------|-----------------|----------------|  
| Traditional OS  | Full                | Complete        | Low            |  
| Unikernel       | None                | Partial         | High           |  
| AppBox          | Full                | Complete        | Medium         |  

![GPOS vs Unikernels vs AppBox](/Images/GPOSXUnikernelsXAppBox.png)

---  
*Last updated: 12 February 2025*
