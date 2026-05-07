# 🎮 Debian Gaming Suite — Optimization Guide

Welcome to the modular Debian gaming suite. This guide helps you get the most out of your hardware using the latest Linux gaming technologies.

---

## 🚀 Quick Start

1. **Run the setup**: `./debian-gaming-setup-universal.sh`
2. **Choose your path**:
   - **Containerized (Recommended)**: Runs Steam/Gaming tools inside a lightweight Arch Linux container (via Distrobox). Keeps your Debian host clean while providing the latest gaming packages.
   - **Native**: Standard installation on your Debian host.
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

---

## 🛠️ Performance Tips

### 🖥️ Desktop Composition
To reduce input lag and stuttering, it is highly recommended to disable window composition for full-screen applications.
- **KDE Plasma**: The script has enabled "Allow applications to block compositing".
- **XFCE**: The script has enabled "Unredirect full screen windows".
- **GNOME**: Handled automatically by the shell (Unredirection).

### ✅ Verify GameMode
After rebooting, you should verify that GameMode is correctly configured. Open a terminal and run:
`gamemoded -t`
- All tests should pass (**OK**). 
- If the "Group" test fails, ensure you have logged out and back in after running the setup.

### 💎 Intel 12th Gen+ (Split-Lock Fix)
We have disabled **Split-Lock Mitigation** (`kernel.split_lock_mitigate=0`). 
- **Impact**: On Intel 12th Gen and newer CPUs, this fix can increase FPS by up to **200%** in titles like **God of War**.

### ⚡ ZRAM
The script automatically configures **ZRAM**. This creates a compressed swap area in your RAM.
- **< 8GB RAM**: 25% allocated to ZRAM.
- **8-16GB RAM**: 33% allocated to ZRAM.
- **> 16GB RAM**: 50% allocated to ZRAM.

---

## 🔄 Updating & Reverting
- **Update**: Run `./update.sh` to keep your system and container up to date.
- **Revert**: Run `./revert.sh` to undo all changes and return to a stock Debian configuration.
