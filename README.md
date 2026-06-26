# ꧁༒XENO OS - SYSTEM ARCHITECTURE & PHASE 1 STATE༒꧂

## 1. Project Overview
Xeno OS is a highly customized, hardware-agnostic, performance-oriented Linux distribution built on an Ubuntu 24.04 (`Noble Numbat`) base. It is engineered to be a "Hybrid Powerhouse," combining desktop daily-driver performance, native Windows app compatibility, and deep kernel-level offensive cybersecurity capabilities.

## 2. Core Kernel Architecture
- **Upstream Source:** XanMod Kernel (v6.12.30+).
- **CPU Scheduler:** BORE (Burst-Oriented Response Enhancer) for ultra-low latency desktop responsiveness.
- **Windows Translation:** NTSYNC enabled at the kernel level for zero-overhead Wine/Bottles gaming and application performance.
- **Cybersecurity Injection:** Kali Linux `mac80211` patches are injected into the kernel source before compilation. This enables raw 802.11 frame injection and monitor mode for cybersecurity tools (Aircrack-ng, Wireshark) running in user-space.
- **Build Pipeline:** The kernel is built via a GitHub Actions CI/CD pipeline (`build-kernel.yml`) which outputs `.deb` files to prevent the host machine from enduring heavy compilation loads.

## 3. File System & Bootloader
- **Base System:** Generated via `debootstrap` (`minbase` variant).
- **Compression:** The live filesystem is compressed into a SquashFS image using maximum `ZSTD` compression.
- **Boot Engine:** Employs the `casper` live-boot engine for filesystem overlay in memory.
- **Bootloader:** Hybrid ISO using GRUB (`grub-mkrescue` / `xorriso` with `-iso-level 3` to bypass 4GB file limits) supporting both UEFI and Legacy BIOS hardware.

## 4. Hardware Abstraction & Drivers
- **Hardware-Agnostic:** Xeno OS is designed to boot on any modern x86_64 architecture. 
- **Dynamic Hardware Detection (`hardware-detect.sh`):** A custom systemd `oneshot` service runs on first boot to dynamically detect CPU (Intel/AMD), GPU (NVIDIA/AMD/Intel), and Chassis type. It enables power-management (`tlp`) exclusively on laptops and downloads proprietary drivers conditionally.
- **Custom Hardware Support:** `linux-headers`, `dkms`, and `build-essential` are pre-installed. The user is pre-added to `dialout` and `tty` groups, allowing unrestricted access to serial/USB ports for custom robotics, SDRs, and microcontrollers.

## 5. User-Space Software Payload
- **Display Stack:** Wayland protocol utilizing `Hyprland` as the compositor. (Version-pinned via `apt-mark hold` to prevent rolling-release configuration breakage).
- **Windows Compatibility:** Handled entirely in userspace via Flatpak `com.usebottles.bottles` to prevent multilib "FrankenDebian" dependency hell.
- **Scientific/ML Stack:** Python 3 globally configured with PySide6, NumPy, SciPy, Pandas, Matplotlib, TensorFlow, Open3D, and Jupyter environments.
- **Creative/Engineering:** Blender, Krita, OBS Studio, Kdenlive, GNU Octave, Docker, Arduino IDE.
- **Fail-Safe:** `Timeshift` is pre-configured for automated daily snapshot rollbacks.

## 6. Phase 2 Guidelines (For LLMs / AI Agents)
- **GUI Framework:** All native desktop panels (Math, Data, 3D) MUST be written in Python using `PySide6`. 
- **Thread Safety:** All heavy Python calculations MUST use `QThread` and `QObject` signals. DO NOT block the main GUI thread.
- **Desktop Shell:** The top bar and launcher MUST be written in TypeScript using `Astal v2` (AGS) running on `Bun`.
