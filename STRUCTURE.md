# 📂 Structure du Projet — Debian Gaming Suite V2.1.0

Ce document récapitule le rôle de chaque fichier dans la nouvelle architecture modulaire.

## 🚀 Racine
- **`setup.sh`** : Point d'entrée principal. Orchestre l'installation, gère les menus (Safe/Advanced) et appelle les modules. Gère `apx` pour VanillaOS et skip PikaOS.
- **`README.md`** : Documentation utilisateur globale.
- **`STRUCTURE.md`** : Ce fichier.

## 🛠️ Utilities (`utils/`)
- **`common.sh`** : Fonctions de base (couleurs, logs, vérification root/internet, helpers d'affichage).
- **`hardware.sh`** : Logique d'auto-détection du GPU, CPU, RAM et de la distribution Linux (support PikaOS/VanillaOS).
- **`rollback.sh`** : Système de sauvegarde. Crée des backups des fichiers système avant modification et génère un script de restauration.

## 📦 Modules (`modules/`)

### 🏎️ Drivers (`modules/drivers/`)
- **`amd.sh`** : Installation des drivers Mesa/RADV (sans PPA sur Debian).
- **`nvidia.sh`** : Installation du driver propriétaire NVIDIA et configuration performance.
- **`intel.sh`** : Support pour Intel Arc (Mesa, GuC/HuC firmware) et IGP.

### 🎮 Gaming Stack (`modules/gaming/`)
- **`distrobox.sh`** : Création d'un container Arch Linux pour une stack gaming isolée et performante (recommandé sur Debian). Export des apps vers le host.
- **`proton.sh`** : Téléchargement et installation de GE-Proton, DXVK et VKD3D-Proton.
- **`upscaling.sh`** : Configuration FSR, DLSS et XeSS selon le GPU.
- **`anticheat.sh`** : Activation du support EAC et BattlEye.

### ⚙️ System Tweaks (`modules/system/`)
- **`kernel.sh`** : Installation du kernel Liquorix (recommandé car léger).
- **`grub.sh`** : Optimisation des paramètres de boot (mitigations CPU, modeset).
- **`zram.sh`** : Swap compressé en RAM avec taille dynamique.
- **`sysctl.sh`** : Ajustements réseau et scheduler.

### 🌐 Repositories (`modules/repos/`)
- **`debian.sh`** : Gestion des sources APT, contrib/non-free, et protection contre les PPA sur Debian.
