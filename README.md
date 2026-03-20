# 🎮 Debian Gaming Optimisation Suite

> One script to turn any Debian-based Linux into a Nobara-level gaming machine.  
> Share it with every Linux gamer you know.

![License](https://img.shields.io/badge/license-MIT-blue)
![Platform](https://img.shields.io/badge/platform-Debian%20%7C%20Ubuntu%20%7C%20Zorin%20%7C%20Mint%20%7C%20Pop!_OS-orange)
![GPU](https://img.shields.io/badge/GPU-AMD%20%7C%20NVIDIA%20%7C%20Intel%20Arc-green)

---

## ✅ What It Does

- Installs **XanMod kernel** with BORE scheduler (smoother frames, less stutter)
- Installs the right **GPU drivers** for your hardware automatically
- Installs **GE-Proton**, Wine-GE, DXVK, VKD3D-Proton
- Configures **FSR 4** (AMD AI upscaling — RX 9000 native, RDNA3 fallback)
- Configures **DLSS 4.5** (NVIDIA — 2nd gen transformer + 6X Dynamic MFG)
- Configures **XeSS 3** (Intel Arc — MFG 2x/3x/4x + upscaling all GPUs)
- Enables **Ray Tracing** (DXR 1.0 + DXR 1.1 via VKD3D-Proton)
- Sets up **EAC + BattlEye** anti-cheat (Battlefield, Fortnite, GTA 5, Apex)
- Installs **GameMode**, MangoHud, Gamescope, Lutris, Heroic
- Sets up a **weekly auto-update pipeline** to stay cutting edge

---

## ✅ Supported Hardware

### GPUs
| GPU | Upscaling | Ray Tracing | Anti-Cheat |
|-----|-----------|-------------|------------|
| AMD Radeon RX 5000–9000 (RDNA) | FSR 4 native (RDNA4) / FSR 3 | ✅ DXR 1.0 + 1.1 | ✅ EAC + BattlEye |
| NVIDIA GeForce GTX/RTX | DLSS 4.5 + FSR 3 fallback | ✅ DXR 1.0 + 1.1 | ✅ EAC + BattlEye |
| Intel Arc A/B-series | XeSS 3 MFG + FSR 3 | ✅ DXR 1.0 + 1.1 | ✅ EAC + BattlEye |
| Hybrid AMD+NVIDIA / Intel+NVIDIA | Both stacks | ✅ | ✅ |

### CPUs
AMD Ryzen (all generations) • Intel Core (8th gen+) • Intel Core Ultra

### Distros
Ubuntu • Zorin OS • Linux Mint • Pop!_OS • Debian • Elementary OS • KDE Neon • and more

---

## 🚀 Quick Start
```bash
# Make executable
chmod +x debian-gaming-setup-universal.sh

# Run setup (auto-detects your GPU and CPU)
./debian-gaming-setup-universal.sh
```

**Read `INSTRUCTIONS.txt` before running** — covers prerequisites, Secure Boot, and troubleshooting.

---

## 🔄 Stay Cutting Edge

After setup, install the updater as a permanent system command:
```bash
sudo mv debian-gaming-update-universal.sh /usr/local/bin/gaming-update
```

Then just run it anytime:
```bash
gaming-update
```

The weekly timer runs it automatically in the background.

---

## 📁 Files

| File | Purpose |
|------|---------|
| `debian-gaming-setup-universal.sh` | Run once on a fresh system |
| `debian-gaming-update-universal.sh` | Run regularly to stay cutting edge |
| `zorin-gaming-setup.sh` | Zorin OS specific — AMD Ryzen + RX 9070 XT |
| `zorin-gaming-update.sh` | Zorin OS updater — AMD Ryzen + RX 9070 XT |
| `INSTRUCTIONS.txt` | Full guide, prerequisites, troubleshooting, FAQ |

---

## ⚠️ Before You Run

- Do **not** run as root
- Read `INSTRUCTIONS.txt` first
- Need at least **5GB free disk space**
- Need a working internet connection (~1.5–2.5 GB downloads)
- NVIDIA users: check Secure Boot notes in `INSTRUCTIONS.txt`

---

## 🎯 Anti-Cheat Games

Install the runtimes once in Steam, then use the launch options in `Gaming-AntiCheat-Launch-Options.txt`:
```bash
# Install EAC runtime
steam steam://install/1826330

# Install BattlEye runtime  
steam steam://install/1161040
```

**Working:** Fortnite ✓ Apex Legends ✓ GTA 5 ✓ Battlefield 2042 ✓ Rainbow Six ✓ Rust ✓  
**Not working:** Valorant (Vanguard — kernel-level, Windows only)

---

## 🏆 Upscaling Quick Reference
```bash
# FSR 4 — RX 9000 series native AI upscaling
PROTON_FSR4_UPGRADE=1 %command%

# FSR 4 + Ray Tracing (RDNA 4 sweet spot)
PROTON_FSR4_UPGRADE=1 RADV_PERFTEST=gpl,rt VKD3D_CONFIG=dxr,dxr11 DXVK_ASYNC=1 gamemoderun mangohud %command%

# DLSS 4.5 (NVIDIA)
PROTON_ENABLE_NVAPI=1 PROTON_HIDE_NVIDIA_GPU=0 DXVK_NVAPI_ALLOW_OTHER_DRIVERS=1 DXVK_ASYNC=1 %command%

# XeSS 3 (Intel Arc — enable in game settings, no launch flags needed)

# FSR 3 via Gamescope (any GPU, no game support needed)
gamescope -f -W 2560 -H 1440 -r 144 --fsr-upscaling -- %command%
```

---

## 🤝 Contributing

Found a bug? Have an improvement? Open an **Issue** or submit a **Pull Request**.  
If this helped you, share it — every Linux gamer deserves this setup.

---

## 📜 Credits

Built on the incredible work of:

| Project | What it provides |
|---------|-----------------|
| [GloriousEggroll](https://github.com/GloriousEggroll) | GE-Proton, Wine-GE |
| [XanMod](https://xanmod.org) | Gaming kernel |
| [DXVK](https://github.com/doitsujin/dxvk) | DirectX → Vulkan |
| [VKD3D-Proton](https://github.com/HansKristian-Work/vkd3d-proton) | DX12 + FSR4 support |
| [OptiScaler](https://github.com/optiscaler/OptiScaler) | FSR4/DLSS4/XeSS3 injection |
| [MangoHud](https://github.com/flightlessmango/MangoHud) | Performance overlay |
| [GameMode](https://github.com/FeralInteractive/gamemode) | CPU/GPU boost |
| [Valve](https://github.com/ValveSoftware) | Steam, Proton, Gamescope |
| The Linux gaming community ❤️ | Making all of this possible |

---

*Free forever. Licensed under MIT. Share it freely.*
```

5. Scroll down and click **Commit changes**

---

## Step 5 — Add Topics So People Can Find You

Topics are like hashtags — they make your repo show up in GitHub searches.

1. On your repo main page look for the **About** section on the right side
2. Click the **gear icon ⚙️** next to it
3. In the **Topics** box add these one at a time:
```
linux-gaming
gaming
debian
ubuntu
proton
amd
nvidia
intel-arc
fsr4
dlss
upscaling
ray-tracing
zorin-os
linux-mint
pop-os
```

4. Click **Save changes**

---

## Step 6 — Create a Release

A release makes it easy for people to download a clean ZIP of everything.

1. On the right side of your repo page click **Releases**
2. Click **Create a new release**
3. Click **Choose a tag** and type `v1.0.0` then click **Create new tag**
4. In **Release title** type: `v1.0.0 — Initial Release`
5. In the description box paste:
```
## What's included
- Universal setup script for all Debian-based distros
- Supports AMD (FSR 4), NVIDIA (DLSS 4.5), Intel Arc (XeSS 3)
- Ray tracing support (DXR 1.0 + DXR 1.1)
- EAC + BattlEye anti-cheat configuration
- Automated weekly update pipeline
- Full instructions and troubleshooting guide

## Quick start
```bash
chmod +x debian-gaming-setup-universal.sh
./debian-gaming-setup-universal.sh
```

Read INSTRUCTIONS.txt before running.
