# 🎮 Debian Gaming Suite — Optimization Guide

Welcome to the modular Debian gaming suite. This guide helps you get the most out of your hardware using the latest Linux gaming technologies.

---

## 🚀 Quick Start

1. **Run the setup**: `./debian-gaming-setup-universal.sh`
2. **Choose your path**:
   - **Containerized (Recommended)**: Runs Steam/Gaming tools inside a lightweight Arch Linux container (via Distrobox). Keeps your Debian host clean while providing the latest gaming packages.
   - **Native**: Standard installation on your Debian host. that's good too.
3. **Select Level**:
   - **Safe**: Balanced performance and security.
   - **Advanced**: Installs **Liquorix Kernel**, disables CPU mitigations, and optimizes GRUB for maximum FPS.
4. **Reboot**: Always reboot after installation to activate the kernel and drivers.

---

## 📦 Why Distrobox / Arch?

Debian is stable, but gaming moves fast. By using **Distrobox with Arch Linux**, you get:
- **Rolling-release packages**: The latest versions of Steam, Wine, and Mesa.
- **Isolation**: No dependency hell on your main system.
- **Performance**: Zero overhead compared to native execution.
- **Portable Home**: Your gaming settings and saves are stored in `~/.local/share/distrobox/gaming-home`.

---

## 🏎️ Steam Launch Options
Launch Aren't always needed, but here are some examples:
Right-click a game in Steam → **Properties** → **General** → **Launch Options**.

### 🔴 AMD Radeon (RDNA 2/3/4)
- **Global / RT enabled**:
  `RADV_PERFTEST=gpl,rt VKD3D_CONFIG=dxr,dxr11 gamemoderun mangohud %command%`
- **FSR 4 AI Upscaling (March 2026+)**:
  `PROTON_FSR4_UPGRADE=1 %command%`

### 🟢 NVIDIA GeForce (RTX)
- **DLSS 4.5 + Ray Tracing**:
  `PROTON_ENABLE_NVAPI=1 PROTON_HIDE_NVIDIA_GPU=0 VKD3D_CONFIG=dxr,dxr11 gamemoderun mangohud %command%`
- **Reflex + DLSS**:
  `PROTON_ENABLE_NVAPI=1 __GL_THREADED_OPTIMIZATIONS=1 %command%`

### 🔵 Intel Arc (Alchemist/Battlemage)
- **XeSS 3 MFG + RT**:
  `ANV_ENABLE_PIPELINE_CACHE=1 VKD3D_CONFIG=dxr,dxr11 mesa_glthread=true %command%`

---

## 🛠️ Performance Tips

### 🐧 Kernel & GRUB
If you chose **Advanced Mode**, the script installed the **Liquorix Kernel**. This kernel is tuned for low-latency desktop use and gaming. 
We also added `mitigations=off` to GRUB, which can provide a **5-15% performance boost** on older CPUs by disabling hardware vulnerability patches.

### ⚡ ZRAM
The script automatically configures **ZRAM**. This creates a compressed swap area in your RAM.
- **< 8GB RAM**: 25% allocated to ZRAM.
- **8-16GB RAM**: 33% allocated to ZRAM.
- **> 16GB RAM**: 50% allocated to ZRAM.

### 🛡️ Anti-Cheat
Most EAC (Easy Anti-Cheat) and BattlEye games work natively on Linux now. 
**IMPORTANT**: You must install the runtimes from the Steam Store:
- Search for "Proton EasyAntiCheat Runtime" and install it.
- Search for "Proton BattlEye Runtime" and install it.

---

## 🔄 Updating
Run the `update.sh` script regularly. It will:
1. Update your Debian host packages.
2. Update your Arch Linux gaming container (if using Distrobox).
3. Update GE-Proton and DXVK versions.

---

*Enjoy gaming on Debian. Share this suite with others!*
