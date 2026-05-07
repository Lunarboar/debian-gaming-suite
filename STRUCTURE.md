# 📂 Structure du Projet — Debian Gaming Suite (Modular)

Ce document récapitule le rôle de chaque fichier dans la nouvelle architecture modulaire.

## 🚀 Racine
- **`setup.sh`** : Point d'entrée principal. Propose le choix entre **Containerisé** (Distrobox) et **Natif**. Gère `apx` pour VanillaOS et skip PikaOS.
- **`update.sh`** : Script de mise à jour modulaire (Host + Container).
- **`README.md`** : Documentation utilisateur globale.
- **`STRUCTURE.md`** : Ce fichier.

## 🛠️ Utilities (`utils/`)
- **`common.sh`** : Fonctions de base (couleurs, logs, vérification root/internet).
- **`hardware.sh`** : Auto-détection (GPU, CPU, RAM, Distro).
- **`rollback.sh`** : Système de sauvegarde et script de restauration automatique.

## 📦 Modules (`modules/`)

### 🏎️ Drivers (`modules/drivers/`)
- **`amd.sh` / `nvidia.sh` / `intel.sh`** : Installation des drivers sur le host (nécessaire pour l'accès hardware).

### 🎮 Gaming Stack (`modules/gaming/`)
- **`distrobox.sh`** : Container Arch Linux isolé avec Steam exporté (Recommandé).
- **`tools.sh`** : Installation native de Steam et des outils (Lutris, Heroic, MangoHud) sur le host.
- **`proton.sh`** : Gestionnaire de versions GE-Proton, DXVK et VKD3D.
- **`upscaling.sh`** : Configuration des variables FSR/DLSS/XeSS.

### ⚙️ System Tweaks (`modules/system/`)
- **`kernel.sh`** : Installation du kernel **Liquorix** (léger et performant).
- **`grub.sh`** : Paramètres de boot (optimisations CPU/GPU).
- **`zram.sh`** : Swap compressé en RAM dynamique.
- **`sysctl.sh`** : Tweaks noyau (réseau BBR, scheduler).

### 🌐 Repositories (`modules/repos/`)
- **`debian.sh`** : Gestion des sources APT, contrib/non-free, et protection contre les PPA sur Debian.
