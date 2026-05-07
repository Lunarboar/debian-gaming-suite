# 📂 Project Structure — Debian Gaming Suite (Modular)

This document outlines the role of each file in the new modular architecture.

## 🚀 Root
- **`setup.sh`**: Main entry point. Handles distribution detection (Debian, Ubuntu, PikaOS, VanillaOS) and provides the choice between **Containerized** (Distrobox) and **Native** modes.
- **`update.sh`**: Modular update script for both the Host system and the Gaming containers.
- **`revert.sh`**: Safety script to undo changes and restore the system to its stock state.
- **`README.md`**: Global user documentation.
- **`STRUCTURE.md`**: This architectural overview.
- **`PR_MESSAGE.md`**: Template for Pull Request submission.

## 🛠️ Utilities (`utils/`)
- **`common.sh`**: Core functions (colors, logging, root/internet checks).
- **`hardware.sh`**: Advanced auto-detection (GPU, CPU, RAM, Distro base).
- **`rollback.sh`**: Backup system and automatic restoration script generator.

## 📦 Modules (`modules/`)

### 🏎️ Drivers (`modules/drivers/`)
- **`amd.sh` / `nvidia.sh` / `intel.sh`**: Hardware driver installation on the host (required for direct GPU access).

### 🎮 Gaming Stack (`modules/gaming/`)
- **`distrobox.sh`**: Isolated Arch Linux container setup via **Podman**. Handles Steam/Lutris exports and installs **Distroshelf** (GUI manager).
- **`tools.sh`**: Native installation of Steam, Lutris, Heroic, and MangoHud on the host.
- **`proton.sh`**: Version management for GE-Proton, DXVK, and VKD3D.
- **`upscaling.sh`**: Configuration for FSR, DLSS, and XeSS environment variables.

### ⚙️ System Tweaks (`modules/system/`)
- **`kernel.sh`**: Installation of the **Liquorix** kernel (low-latency gaming kernel).
- **`grub.sh`**: Boot parameter optimization (CPU/GPU tweaks, mitigations off).
- **`zram.sh`**: Dynamic compressed swap in RAM.
- **`sysctl.sh`**: Core kernel tweaks (Network BBR, scheduler optimizations).

### 🌐 Repositories (`modules/repos/`)
- **`debian.sh`**: Management of APT sources, enabling contrib/non-free, and PPA safety checks for Debian.
