# 🎮 Debian Gaming Optimisation Suite (Modular)

> One suite to turn any Debian-based Linux into a professional gaming machine.  
> Powered by Distrobox, Podman, and the Liquorix Kernel.

![License](https://img.shields.io/badge/license-MIT-blue)
![Platform](https://img.shields.io/badge/platform-Debian%20%7C%20Ubuntu%20%7C%20Zorin%20%7C%20Mint%20%7C%20Pop!_OS-orange)
![GPU](https://img.shields.io/badge/GPU-AMD%20%7C%20NVIDIA%20%7C%20Intel%20Arc-green)

---

## ✅ Major Features

- **Modular Architecture**: Cleanly separated components for drivers, system tweaks, and gaming stacks.
- **Containerized Gaming**: Isolated Arch Linux environment via **Podman & Distrobox** (Recommended for stability).
- **GUI Management**: Integrated **Distroshelf** (Flatpak) to manage your gaming containers visually.
- **XanMod/Liquorix Kernel**: High-performance, low-latency gaming kernels.
- **GPU Optimization**: Automatic setup for **FSR 3/4**, **DLSS**, and **XeSS**.
- **Anti-Cheat Support**: Pre-configured runtimes for EAC and BattlEye.
- **Safe Rollback**: Built-in backup and restoration system (`revert.sh`).

---

## ✅ Supported Hardware

### GPUs
| GPU | Upscaling | Ray Tracing | Anti-Cheat |
|-----|-----------|-------------|------------|
| AMD Radeon (RDNA) | FSR 3 / 4 | ✅ DXR 1.0 + 1.1 | ✅ EAC + BattlEye |
| NVIDIA GeForce RTX | DLSS / FSR 3 | ✅ DXR 1.0 + 1.1 | ✅ EAC + BattlEye |
| Intel Arc A/B-series | XeSS / FSR 3 | ✅ DXR 1.0 + 1.1 | ✅ EAC + BattlEye |

### CPUs
AMD Ryzen (all generations) • Intel Core (8th gen+) • Intel Core Ultra

---

## 🚀 Quick Start

```bash
# Clone the repository
git clone https://github.com/YourUsername/little-script.git
cd little-script

# Make the orchestrator executable
chmod +x setup.sh

# Run the setup
./setup.sh
```

---

## 📁 File Structure

| File | Purpose |
|------|---------|
| `setup.sh` | **Main Entry Point**. Handles detection and installation. |
| `update.sh` | Keep your host and containers up to date. |
| `revert.sh` | Safely undo all changes and return to stock. |
| `modules/` | Category-specific optimization scripts. |
| `utils/` | Hardware detection and shared helper functions. |
| `STRUCTURE.md` | Full architectural overview. |

---

## 🛡️ Safety & Backups

Every time you run the suite, it automatically creates a timestamped backup of your system configurations in `~/.local/share/debian-gaming-backups/`.  
If anything goes wrong, simply run:
```bash
./revert.sh
```

---

## 🎯 Anti-Cheat Games
Install the runtimes in Steam, then use the provided launch options for:
- Fortnite ✓ Apex Legends ✓ GTA 5 ✓ Battlefield 2042 ✓ Rust ✓

---

## 🏆 Credits
Built on the work of **GloriousEggroll (Proton-GE)**, **XanMod**, **Distrobox**, and the incredible Linux gaming community.

---
*Free forever. Licensed under MIT.*
