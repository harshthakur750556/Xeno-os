<div align="center">

![Xeno OS Header Banner](assets/xeno-banner.svg)

# XENO OS — Next-Generation Hybrid Security &amp; Wayland Platform

> **XENO OS (v9.0-BETA Noble Cyber-Nord)** is a bare-metal and VM-agnostic Linux operating system combining a custom low-latency XanMod BORE kernel with Kali packet injection patches, a high-performance 100% TypeScript/Astal v2 desktop shell on Hyprland Wayland, universal cross-platform application execution (`.apk`, `.exe`/`.msi`, `.AppImage`, `.deb`, `.iso`), fail-safe DRM KMS software rendering with self-healing fallback, high-throughput ZRAM memory compression, and open root sovereignty.

[![Base OS](https://img.shields.io/badge/Base_OS-Ubuntu_24.04_LTS_Noble-00F0FF?style=for-the-badge&logo=ubuntu&logoColor=white)](https://ubuntu.com)
[![Kernel](https://img.shields.io/badge/Kernel-XanMod_6.12+_BORE_1000Hz-7000FF?style=for-the-badge&logo=linux&logoColor=white)](https://xanmod.org)
[![Security](https://img.shields.io/badge/Security-Kali_mac80211_Patched-FF5555?style=for-the-badge&logo=kalilinux&logoColor=white)](https://kali.org)
[![ZRAM](https://img.shields.io/badge/ZRAM-zstd_50%25_RAM-00FFA3?style=for-the-badge&logo=speedtest&logoColor=black)](https://github.com/systemd/zram-generator)
[![Shell](https://img.shields.io/badge/Shell-Astal_v2_Typescript_Bun-00FFA3?style=for-the-badge&logo=bun&logoColor=black)](https://bun.sh)
[![Tests](https://img.shields.io/badge/Tests-96_Passing_8_Tiers-50FA7B?style=for-the-badge&logo=pytest&logoColor=black)](tests/)

</div>

![Cyber Divider](assets/cyber-divider.svg)

## <img src="assets/icons/clipboard-list.svg" width="20" height="20" align="absmiddle" /> Complete System Specifications

| Specification Area | Technical Implementation &amp; Parameter |
|---|---|
| **Base Operating System** | Ubuntu 24.04 LTS (Noble Numbat) Clean Debootstrap Base |
| **Kernel &amp; Architecture** | Custom XanMod 6.12+ (x86_64), `CONFIG_PREEMPT_BUILD=y` (Full Real-time Preemption) |
| **Scheduler &amp; Clock Frequency** | BORE (Burst-Oriented Response Enhancer) EEVDF Scheduler @ 1000Hz (`CONFIG_HZ_1000=y`) |
| **Kernel Synchronization** | Fast in-kernel `CONFIG_NTSYNC=y` (Direct Wine/Proton multi-threading synchronization) |
| **Memory Compression (ZRAM)** | `systemd-zram-generator` with **Zstd compression**, dynamic 50% RAM allocation (`ram / 2`) |
| **Virtual Memory Tuning** | `vm.max_map_count=1048576` for high-concurrency VMA handling (Wine/Proton workloads) |
| **Display Compositor** | Hyprland Wayland Compositor (with Mesa `kms_swrast`/`llvmpipe` driver override &amp; dynamic self-healing supervisor) |
| **Desktop Shell** | 100% Native TypeScript Astal v2 GTK3 Surface Layer running on the **Bun** runtime engine |
| **Universal Workspace Apps** | Kitty Terminal, Files, Chrome/Firefox, WiFi Monitor, Pentest Suite, Windows Compatibility Layer |
| **Windows App Execution** | Wine Staging 9.x + DXVK + VKD3D-Proton + Bottles + `WINEESYNC=1` + `WINEFSYNC=1` + `i386` multiarch |
| **Android App Execution** | Waydroid AOSP Subsystem sharing Linux kernel binder &amp; Wayland display buffers |
| **Linux Standalone Apps** | Direct FUSE 2/3 runtime (`libfuse2t64`) for zero-install `.AppImage` execution + Flatpak/Flathub |
| **Security &amp; Pentest Stack** | Kali `mac80211` &amp; `cfg80211` packet injection patches + Pinned Kali Rolling repo (`Priority: 100`) |
| **Wireless Adapter Drivers** | Broad in-tree kernel drivers (Intel `iwlwifi`, Atheros `ath9k`/`ath10k`, MediaTek `mt76`, Realtek `rtw88`/`89`, Broadcom) + Realtek injection DKMS installer ([`drivers/install-oot-wifi.sh`](file:///home/xeno/Xeno-os/drivers/install-oot-wifi.sh)) |
| **Local AI Engine &amp; Sandbox** | `xeno-ai-engine` (Ollama/llama.cpp @ `/var/cache/xeno-ai/models`) + Bubblewrap (`bwrap`) isolation |
| **Live Boot &amp; ISO Engine** | Casper Live Overlay (`boot=casper`), Instant Universal Boot (`timeout=0`), ZSTD Level 19 SquashFS, GRUB ISO Level 3 (`XENOOS`) |
| **Diagnostic &amp; Auto-Heal** | [`scripts/master-doctor.sh`](file:///home/xeno/Xeno-os/scripts/master-doctor.sh) (8-Tier audit engine with `--fix` self-healing) |
| **Test Verification** | 96 Automated Tests (73 E2E Integration + 23 Adversarial IPC boundary tests) |

![Cyber Divider](assets/cyber-divider.svg)

## <img src="assets/icons/layers.svg" width="20" height="20" align="absmiddle" /> Xeno OS Release Tier Classification

Xeno OS is distributed across three distinct edition tiers tailored to different computing paradigms:

```
┌──────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                       XENO OS RELEASE TIERS & EDITIONS                                   │
└──────────────────────────────────────────────────────────────────────────────────────────────────────────┘
       │                                           │                                           │
       ▼                                           ▼                                           ▼
 ┌───────────────┐                           ┌───────────────┐                           ┌───────────────┐
 │ ALPHA VERSION │                           │ BETA VERSION  │                           │ OMEGA VERSION │
 └───────┬───────┘                           └───────┬───────┘                           └───────┬───────┘
         │                                           │                                           │
   [ Base Core ]                               [ Desktop GUI ]                             [ Gold Master ]
   - No Graphical GUI                          - Hyprland Wayland                          - Calamares Installer
   - Headless Terminal Mode                    - Astal v2 / Bun Shell                      - Full Offline Drivers
   - XanMod 6.12+ BORE Kernel                  - Native Desktop Apps                       - Local AI Orchestration
   - ZRAM In-Memory Swap                       - Universal App GUI                         - Enterprise Hardening
   - CLI Compatibility Stack                   - Hardware GL Acceleration                  - Production Stable
         │                                           │                                           │
         ▼                                           ▼                                           ▼
  iso/output/ALPHA VERSION/                   iso/output/BETA VERSION/                    iso/output/OMEGA VERSION/
```

### 1. ALPHA VERSION — Base OS Core (Headless / Without GUI)
* **Target Output**: `iso/output/ALPHA VERSION/`
* **Architecture**: Core Ubuntu 24.04 LTS (Noble) minimal debootstrap + Custom XanMod 6.12+ BORE EEVDF low-latency kernel + in-memory ZRAM Zstandard compressed swap.
* **Included Stack**:
  - Full Linux CLI networking, WiFi packet injection kernel patches (`mac80211`), and security driver layer.
  - Universal CLI execution runners (`xeno-windows`, `xeno-wifi-monitor`, `xeno-tor-proxy`).
  - Serial console autologin (`ttyS0`) and virtual terminal autologin (`tty1`).
* **Ideal For**: Lightweight server deployments, automated headless CI/CD test harnesses, minimal hypervisors, and terminal-only security audits.

### 2. BETA VERSION — Interactive Cyber-Nord Desktop (With GUI)
* **Target Output**: `iso/output/BETA VERSION/`
* **Architecture**: Everything in the Alpha base + full graphical hardware-accelerated &amp; fail-safe software Wayland display stack.
* **Included Stack**:
  - **Hyprland Wayland Compositor**: Shader-accelerated tiling window manager with fail-safe Mesa `kms_swrast`/`llvmpipe` software rasterizer and self-healing supervisor for VMs (VirtualBox, VMware, QEMU, Hyper-V) and bare metal.
  - **Astal v2 / Bun Desktop Shell**: 100% Native TypeScript UI with real-time Cyber-Nord top bar (`Bar.ts`), fuzzy application search launcher (`Launcher.ts` on `Super+Space`), and toast notification daemon (`Notifications.ts`).
  - **Universal App Execution**: Seamless windowed execution for Windows (`.exe`/`.msi`), Android (`.apk`), AppImages, Flatpaks, and Debian packages.
  - **Instant Live Boot**: Single default Universal boot entry with zero countdown delays (`timeout=0`), booting straight into the graphical Wayland environment.
* **Ideal For**: Interactive daily driving, graphical security simulation, and multimedia/gaming workloads.

### 3. OMEGA VERSION — Final Stable Gold Master (Enterprise Edition)
* **Target Output**: `iso/output/OMEGA VERSION/`
* **Architecture**: Everything in the Beta edition + comprehensive offline hardware ecosystem, automated system installer, and local AI orchestration.
* **Included Stack**:
  - **Calamares GUI System Installer**: Automated graphical bare-metal installation to NVMe/SSD/HDD with custom Btrfs/EXT4 subvolume partitioning.
  - **Offline Battery-Included Drivers**: Pre-compiled DKMS binary modules for out-of-tree Realtek/MediaTek adapters, NVIDIA proprietary drivers, and Bluetooth chipsets.
  - **Local AI Agent Engine (`xeno-ai-engine`)**: Offline Ollama/llama.cpp runtime with Bubblewrap container sandboxing.
  - **Production Security Hardening**: Scoped PAM realtime limits, unprivileged user namespaces isolation, and firewall autotuning.
* **Ideal For**: Enterprise workstations, mission-critical laboratories, and zero-compromise penetration testing deployments.

![Cyber Divider](assets/cyber-divider.svg)

## <img src="assets/icons/cpu.svg" width="20" height="20" align="absmiddle" /> ZRAM Architecture &amp; Memory Consumption Specs

Xeno OS is engineered for a lightweight memory footprint and zero physical disk swap latency by leveraging kernel-level in-memory compressed swap (**ZRAM**) alongside aggressive OS de-bloating.

```
                  ┌──────────────────────────────────────────────┐
                  │          TOTAL PHYSICAL RAM (e.g. 8GB)       │
                  └──────────────────────┬───────────────────────┘
                                         │
                 ┌───────────────────────┴───────────────────────┐
                 ▼                                               ▼
   ┌───────────────────────────┐                   ┌───────────────────────────┐
   │    Active System Memory   │                   │    ZRAM0 Compressed Swap  │
   │      (50% = 4000 MB)      │                   │      (50% = 4000 MB)      │
   │                           │                   │  Algorithm: Zstd (~3:1)   │
   │  - XanMod Kernel: ~120MB  │                   │  Effective Storage Space: │
   │  - Hyprland + Shell: ~180MB                   │        ~10 GB - 12 GB     │
   │  - System Services: ~150MB│                   └─────────────┬─────────────┘
   │  - Free/Available: ~3550MB│                                 │
   └───────────────────────────┘                                 ▼
                                                   [ Zero Physical Disk I/O ]
                                                   [ Sub-Microsecond Access ]
                                                   [ Prevents Live USB Hang ]
```

### 1. ZRAM Implementation Details
- **Generator Daemon**: `systemd-zram-generator` configured in `/etc/systemd/zram-generator.conf.d/zram0.conf`.
- **Target Device**: `/dev/zram0` dynamically initialized during boot phase (`system-systemd\x2dzram\x2dsetup.slice`).
- **Allocation Rule**: `zram-size = ram / 2` (exactly 50% of detected physical RAM).
- **Compression Algorithm**: `zstd` (Zstandard). Provides optimal balance of high compression ratio (~2.8:1 to 3.5:1 on text/code/RAM pages) with near-instant decompression throughput (&gt;3GB/s).
- **Diskless Swapping**: Completely eliminates thrashing and freeze-ups when running from slow USB 2.0/3.0 live media or resource-constrained virtual machines.
- **Kernel Memory Overcommit**: Paired with `vm.max_map_count=1048576` and `vm.swappiness=180` to prioritize compressed RAM over cold disk paging.

### 2. Detailed RAM Consumption Profile

| Operational State | RAM Utilization | Primary Active Components |
|---|---|---|
| **Cold Boot Idle (Terminal / Headless)** | **~180 MB – 240 MB** | Systemd, XanMod Kernel, D-Bus, Udev, Serial Getty |
| **Cold Boot Idle (Hyprland + Astal Shell)** | **~450 MB – 680 MB** | Hyprland Wayland, Astal v2 GTK3 Shell, PipeWire, WirePlumber |
| **Active Terminal &amp; Native App Workloads** | **~500 MB – 750 MB** | Kitty Terminal, File Manager, System Tools, IPC Store |
| **Windows App Execution (Wine / Bottles)** | **~750 MB – 1.8 GB** | Wine Server, DXVK Shader Pipelines, Audio Pulse/PipeWire bridges |
| **Android Execution (Waydroid AOSP Container)** | **~1.1 GB – 2.1 GB** | Android System Server, SurfaceFlinger, Binder Interface |

### 3. Canonical De-Bloat Engine
To maintain the ~450MB idle footprint, Xeno OS removes heavy Canonical telemetry and background bloat from the Noble base:
- `snapd` &amp; `snap` daemons purged (replaced with native APT and Flatpak/Flathub).
- `cups` print spoolers and `geoclue-2.0` location tracking stripped.
- `apport` and `whoopsie` crash uploaders removed.
- APT archive caches stripped during ISO compression.

![Cyber Divider](assets/cyber-divider.svg)

## <img src="assets/icons/server.svg" width="20" height="20" align="absmiddle" /> Internal System Architecture &amp; Directory Layout

```mermaid
graph TD
    subgraph KERNEL["Layer 1: Low-Latency Kernel and Hardware Abstraction"]
        K1["Custom XanMod 6.12+ Kernel Source"]
        K2["BORE EEVDF Scheduler and PREEMPT 1000Hz"]
        K3["NTSYNC Kernel Synchronization Primitive"]
        K4["Kali mac80211 / cfg80211 Frame Injection Patches"]
        K5["Out-of-Tree Wi-Fi DKMS RTL8812AU / RTL8821AU"]
        K6["ZRAM In-Memory Compressed Swap zstd 50% RAM"]
        K1 --> K2
        K1 --> K3
        K1 --> K4
        K1 --> K5
        K1 --> K6
    end

    subgraph BOOT["Layer 2: Base System and ISO Packaging Subsystem"]
        B1["Ubuntu 24.04 LTS Noble Minimal RootFS"]
        B2["Casper Live Overlay Smart Lean ZSTD L19 SquashFS"]
        B3["GRUB Bootloader boot=casper Volume ID: XENOOS"]
        B4["Xorriso Wrapper -iso-level 3 for Large Images"]
        B1 --> B2
        B2 --> B3
        B3 --> B4
    end

    subgraph DISPLAY["Layer 3: Display Server and Hardware Adaptive Layer"]
        G1["xeno-start-hyprland Session Launcher"]
        G2["Hardware / VM Auto-Detector systemd-detect-virt"]
        G3["Mesa Software Renderer kms_swrast / llvmpipe"]
        G4["Hyprland Wayland Hardware Compositor"]
        G1 --> G2
        G2 --> G3
        G2 --> G4
        G3 --> G4
    end

    subgraph SHELL["Layer 4: Desktop Shell and System Telemetry Astal v2 / Bun"]
        S1["Bun Runtime Engine"]
        S2["Astal v2 GTK3 Binding Framework"]
        S3["Top Status Bar Bar.ts — Live CPU/RAM/Telemetry"]
        S4["Cyber App Launcher Launcher.ts — App Matrix"]
        S5["Notification Toast Engine Notifications.ts"]
        S6["Global Reactive IPC Socket /tmp/xeno-ipc.sock"]
        S1 --> S2
        S2 --> S3
        S2 --> S4
        S2 --> S5
        S6 --- S3
        S6 --- S4
        S6 --- S5
    end

    subgraph APPS["Layer 5: Universal Cross-Platform Execution Stack"]
        C1["Wine Staging + DXVK + VKD3D Windows Apps"]
        C2["Waydroid AOSP Container Android Apps"]
        C3["FUSE 2/3 Runtime Linux AppImage"]
        C4["APT / DPkg Native Package Engine Debian"]
        C5["Flatpak Container Engine Flathub"]
        C6["QEMU / KVM Hardware Hypervisor Live ISO"]
        C7["Local AI Engine xeno-ai-engine / Ollama"]
    end

    subgraph WORKSPACE["Layer 6: System and Security Suites"]
        W1["Kitty GPU-Accelerated Terminal"]
        W2["Native Cyber File Explorer"]
        W3["Chrome / Firefox Web Browser"]
        W4["WiFi Packet Injection Suite aircrack-ng"]
        W5["Windows Compatibility Layer Wine / Bottles"]
        W6["Offensive Security: Wireshark, Metasploit, Tor"]
    end

    K1 --> B1
    B4 --> G1
    G4 --> S1
    S2 --> C1
    S2 --> W1
```

![Cyber Divider](assets/cyber-divider.svg)

## <img src="assets/icons/folder-tree.svg" width="20" height="20" align="absmiddle" /> Repository &amp; Filesystem Map

```
Xeno-os/
├── assets/                     # Animated SVG banners, dividers, and Lucide icons
│   ├── xeno-banner.svg         # Animated glowing Cyber-Nord header banner
│   ├── cyber-divider.svg       # Animated laser sweep gradient divider
│   └── icons/                  # Lucide SVG icon collection
├── desktop/                    # TypeScript Astal shell, theme tokens, and assets
│   ├── env.py                  # VM software rendering environment initializer
│   ├── theme.py                # Python theme tokens (reference)
│   ├── assets/                 # Desktop visual icons and SVG assets
│   ├── themes/                 # Supplemental theme presets and palettes
│   └── shell/                  # Astal v2 / Bun TypeScript desktop shell
│       ├── app.ts              # Astal application entry point
│       ├── state.ts            # Reactive IPC client & telemetry store
│       ├── Bar.ts              # Status bar with CPU/RAM/clock/workspaces
│       ├── Launcher.ts         # Fast fuzzy application grid launcher
│       ├── Notifications.ts    # Floating notification toast center
│       ├── theme.ts            # TypeScript visual tokens (Single Source of Truth)
│       ├── sandbox.sh          # Sandboxed desktop shell launcher
│       ├── trigger.py          # Status bar & launcher IPC trigger utility
│       └── package.json        # Bun package definition & Astal dependencies
├── drivers/                    # Hardware driver packages & setup scripts
│   ├── README.md               # Hardware & wireless driver technical manual
│   └── install-oot-wifi.sh     # Realtek (rtl8812au) out-of-tree DKMS installer
├── iso/                        # ISO build artifacts and output
│   ├── build/casper/           # Live boot filesystem (SquashFS location)
│   ├── output/                 # Generated ISO images (ALPHA, BETA, OMEGA)
│   └── version.txt             # Target build version string (e.g. 9.0-beta)
├── kernel/                     # XanMod kernel sources, patches, and build scripts
│   ├── configs/                # xeno.config.fragment (BORE, NTSYNC, 1000Hz, WLAN)
│   ├── patches/                # 0001 (mac80211), 0002 (cfg80211), 0003 (usb injection)
│   ├── cache/                  # Staged compiled linux-image deb packages
│   ├── build-kernel.sh         # Automated XanMod kernel compilation pipeline
│   └── validate-kernel-deb.sh  # Kernel package verification gate
├── rootfs/                     # Ubuntu 24.04 LTS (Noble) debootstrap root filesystem
├── scripts/                    # Core build, configuration, and diagnostic tools
│   ├── auto-build.sh           # Smart Lean ISO packaging pipeline (ZSTD L19 + Level 3)
│   ├── master-doctor.sh        # Master 8-Tier diagnostic and self-healing doctor
│   ├── fix-boot-display.sh     # Display manager conflict resolution & VM launcher
│   ├── setup-compat-stack.sh   # Windows (Wine/DXVK/Bottles) compatibility installer
│   ├── setup-security-tools.sh # Kali tools, pinned repo, and injection helpers
│   ├── setup-ai.sh             # Ollama local LLM runtime and sandbox setup
│   ├── fix-kernel-rootfs.sh    # Kernel installation into rootfs
│   ├── stage-kernel-debs.sh    # Stages locally compiled kernels into cache/
│   ├── install-astal-chroot.sh # Astal shell and Bun dependencies installer
│   ├── enter-rootfs.sh         # Interactive chroot mount tool
│   └── lib-chroot.sh           # Shared chroot mount/unmount utility library
├── tests/                      # Automated test suite (96 tests)
│   ├── run_tests.py            # Test suite runner (Simulation & Live modes)
│   ├── test_e2e.py             # 73 E2E Integration and UX scenario tests
│   ├── test_adversarial.py     # 23 Adversarial IPC boundary & stress tests
│   ├── simulator.py            # Headless mock display server & IPC simulator
│   └── bin/                    # Test mock runner wrappers
├── .cursorrules                # AI engineer rules & memory log
├── .editorconfig               # Editor code style & whitespace rules
├── AGENTS.md                   # AI developer guidelines & critical path constraints
├── CHANGELOG.md                # System revision history and activity log
├── run-qemu.sh                 # Fast QEMU test runner (--gui or --terminal)
├── xorriso-wrapper.sh          # ISO Level 3 oversized image injection wrapper
└── README.md                   # Master technical manual and architectural spec
```

![Cyber Divider](assets/cyber-divider.svg)

## <img src="assets/icons/rocket.svg" width="20" height="20" align="absmiddle" /> Key Subsystems &amp; Functionality

### 1. Universal Cross-Platform Application Engine

Xeno OS allows running applications across virtually any format seamlessly:

```
                                   ┌────────────────────────────────────────────────────────┐
                                   │           XENO OS UNIVERSAL EXECUTION ENGINE           │
                                   └───────────────────────────┬────────────────────────────┘
                                                                │
            ┌───────────────────┬──────────────────────────────┼──────────────────────────────┬───────────────────┐
            ▼                   ▼                              ▼                              ▼                   ▼
       [.exe / .msi]         [.apk]                       [.AppImage]                       [.deb]             [.iso]
      (Windows Stack)    (Android AOSP)                (FUSE Standalone)                (Native Linux)      (Hypervisor)
            │                   │                              │                              │                   │
      Wine Staging +      Waydroid LXC                   libfuse2 FUSE                   APT / Dpkg Base     Hardware KVM
       DXVK / VKD3D      Kernel Binder                  User-Space Mount                + Pinned Kali Repo    + QEMU Virt
            │                   │                              │                              │                   │
      Direct3D→Vulkan    SurfaceFlinger                  Zero-Install                    Native ELF64        Full Hardware
       NTSYNC Kernel     Wayland Buffers                 Direct Execution                glibc 2.39 Bin      Virtualization
            │                   │                              │                              │                   │
            └───────────────────┴──────────────────────────────┼──────────────────────────────┴───────────────────┘
                                                               │
                                                               ▼
                                    ┌─────────────────────────────────────────────────────┐
                                    │        CUSTOM XANMOD 6.12+ LOW-LATENCY KERNEL       │
                                    │   - BORE EEVDF Scheduler (1000Hz Timer Frequency)   │
                                    │   - CONFIG_NTSYNC & PREEMPT Real-Time Multitasking  │
                                    │   - ZRAM In-Memory Compressed Swap (zstd 50% RAM)   │
                                    │   - Hyprland Wayland Hardware Compositor            │
                                    └─────────────────────────────────────────────────────┘
```

- **Windows Software (`.exe`, `.msi`)**:
  - System Wine Staging + DXVK (Direct3D 9/10/11 -&gt; Vulkan) and VKD3D-Proton (Direct3D 12 -&gt; Vulkan).
  - Preconfigured with `WINEESYNC=1`, `WINEFSYNC=1`, and in-kernel `CONFIG_NTSYNC=y` synchronization.
  - Multiarch `i386` for seamless 32-bit legacy application support.
  - GUI management via **Bottles** and CLI wrapper `/usr/bin/xeno-windows`.
- **Android Applications (`.apk`)**:
  - Waydroid AOSP container integrated directly into the Linux kernel (via Android binder &amp; ashmem).
  - Shares Wayland buffers for near-zero latency touch and windowed app execution.
- **Linux Standalone Binaries (`.AppImage`)**:
  - Built-in `libfuse2t64` / `libfuse.so.2` compatibility layer allowing instant double-click execution without extracting.
- **Native Debian Packages (`.deb`)**:
  - Dual repository support (Ubuntu Noble base + pinned Kali Linux rolling repo).
- **Virtual Machines &amp; Live ISOs (`.iso`)**:
  - Direct hardware-assisted QEMU/KVM hypervisor integration.
- **Local AI Engine (`xeno-ai-engine`)**:
  - Built-in Ollama / llama.cpp runtime hosted at `/var/cache/xeno-ai/models` on `127.0.0.1:11434`.
  - Sandboxed execution wrapper `/usr/bin/xeno-agent-sandbox` utilizing Bubblewrap (`bwrap`).

---

### 2. Offensive Security &amp; Wireless Injection Subsystem

1. **Kernel Packet Injection**:
   - Custom patches in `net/mac80211/tx.c` enable raw IEEE 802.11 frame injection and custom sequence numbering.
   - Patches in `net/wireless/chan.c` permit dynamic channel switching while monitor VIFs are active.
2. **Hardware &amp; Wireless Driver Architecture**:
   - Comprehensive in-tree driver support compiled into the custom XanMod kernel for major chipsets (Intel `iwlwifi`, Atheros `ath9k`/`ath10k`, MediaTek `mt76`, Realtek `rtw88`/`rtw89`, Broadcom `brcmfmac`, Ralink `rt2800usb`, ZyDAS `zd1211rw`).
   - Dedicated out-of-tree DKMS installer ([`drivers/install-oot-wifi.sh`](file:///home/xeno/Xeno-os/drivers/install-oot-wifi.sh)) for Realtek `rtl8812au`/`rtl8821au` USB injection adapters against matching installed kernel headers.
3. **Pinned Kali Repository**:
   - Configured with `Pin-Priority: 100` in `/etc/apt/preferences.d/kali-pinning` to allow selective installation of Kali security tools without overriding the stable Ubuntu Noble base.
4. **Pre-Installed Tools &amp; Utilities**:
   - `aircrack-ng`, `wireshark`, `nmap`, `bettercap`, `msfconsole`, `hydra`, `sqlmap`, `john`, `scapy`, and `tor`.
   - `/usr/bin/xeno-wifi-monitor`: One-shot virtual monitor interface creator and packet injection test utility.
   - `/usr/bin/xeno-tor-proxy`: Transparent TCP/DNS Tor routing helper.

---

### 3. TypeScript Astal v2 Desktop Shell &amp; GUI Development Workflow

Xeno OS features a native TypeScript desktop shell built on **Astal v2** (GTK3) and executed on the high-performance **Bun** runtime engine:

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                        XENO OS TYPESCRIPT DESKTOP SHELL (BUN + ASTAL)                  │
├────────────────────────────────────────────────────────────────────────────────────────┤
│  Top Bar (Bar.ts)       → Dynamic Workspaces, Telemetry Gauges (CPU/RAM), System Clock │
│  App Launcher (Launcher.ts) → Cyber-Nord Grid & Fuzzy Search Matrix (Super+Space)      │
│  Notification Center (Notifications.ts) → High-Throughput Toast Dispatch Queue         │
│  IPC & State Engine (state.ts) → Reactive State Store on /tmp/xeno-ipc.sock            │
│  Crash-Proof Launcher (xeno-desktop-shell) → Auto-discovered & launched by Hyprland   │
└────────────────────────────────────────────────────────────────────────────────────────┘
```

#### Developing &amp; Previewing Custom TypeScript GUIs
* **Live VM Preview**: Boot your ISO anytime using `bash run-qemu.sh --gui`. Hyprland boots with software cursor fallback (`no_hardware_cursors = true`) and automatically runs [`/usr/bin/xeno-desktop-shell`](file:///home/xeno/Xeno-os/rootfs/usr/bin/xeno-desktop-shell), rendering your custom TypeScript GUI instantly without crashes.
* **Local Sandbox Preview**: Test and hot-reload your TypeScript shell without rebooting:
  ```bash
  # Launch the shell in local developer sandbox
  bash desktop/shell/sandbox.sh
  # Or run directly via Bun
  cd desktop/shell && bun run app.ts
  ```
* **Zero-Crash Aquamarine Display Pipeline**:
  - `cursor { no_hardware_cursors = true }` eliminates Aquamarine hardware DRM cursor allocation faults.
  - `AQ_FORCE_LINEAR_BLIT=1` and `AQ_NO_MODIFIERS=1` guarantee rock-solid linear buffer rendering in VMs (QEMU, Hyper-V, VMware, VirtualBox) and bare-metal GPUs.
  - Global TypeScript error boundaries (`uncaughtException` &amp; `unhandledRejection`) safely catch runtime UI errors, preventing compositor drops during active GUI development.
* **Retained Hyprland Core Desktop Elements**:
  - Full tiling window management with key shortcuts (`Super+Return` for Kitty terminal, `Super+Space` for application launcher, `Super+Q` to close, `Super+1..5` for workspace switching, `Print` for screenshot capture).

![Cyber Divider](assets/cyber-divider.svg)

## <img src="assets/icons/wrench.svg" width="20" height="20" align="absmiddle" /> Management, Diagnostics &amp; Auto-Healing

<details open>
<summary><b>1. Master Doctor (8-Tier System Diagnostic)</b></summary>

```bash
# Run comprehensive 8-tier audit across host, rootfs, kernel, shell, and tests
bash scripts/master-doctor.sh

# Run Master Doctor in self-healing mode (auto-repairs missing configs/links)
sudo bash scripts/master-doctor.sh --fix
```
</details>

<details open>
<summary><b>2. ISO Packaging Pipeline (Smart Lean Engine)</b></summary>

```bash
# Run full automated ISO packaging pipeline (ZSTD L19 + Level 3 GRUB)
sudo bash scripts/auto-build.sh
```
</details>

<details open>
<summary><b>3. QEMU Virtual Machine Testing</b></summary>

```bash
# Launch built ISO in graphical Wayland mode
bash run-qemu.sh --gui

# Launch built ISO in headless serial console mode (ttyS0 autologin)
bash run-qemu.sh --terminal
```
</details>

<details open>
<summary><b>4. Automated Test Suite (96 Tests)</b></summary>

```bash
# Run simulation mode (73 E2E Integration + 23 Adversarial IPC tests)
python3 tests/run_tests.py && python3 -m unittest tests/test_adversarial.py

# Run live mode (interacts with active Wayland/X11 session)
python3 tests/run_tests.py --live
```
</details>

![Cyber Divider](assets/cyber-divider.svg)

## <img src="assets/icons/monitor.svg" width="20" height="20" align="absmiddle" /> Hardware Requirements

| Resource | Minimum (Simulation / VM) | Recommended (Bare Metal) |
|---|---|---|
| **CPU** | 64-bit x86_64 Dual Core (2.0 GHz) | 64-bit x86_64 Quad Core+ with AVX2 &amp; VT-x/AMD-V |
| **RAM** | 2.0 GB (with ZRAM enabled) | 8.0 GB+ (provides ~16GB+ effective memory via Zstd) |
| **Storage** | 15.0 GB free disk space (for build) | 32.0 GB+ NVMe / SSD |
| **GPU** | Mesa Software Rasterizer (`kms_swrast`/`llvmpipe`) | Intel Iris / AMD Radeon / NVIDIA (Vulkan 1.3+) |
| **Wi-Fi** | Any standard IEEE 802.11 adapter | Atheros AR9271 / Realtek RTL8812AU / MediaTek MT7612U (for injection) |

![Cyber Divider](assets/cyber-divider.svg)

## <img src="assets/icons/file-text.svg" width="20" height="20" align="absmiddle" /> Authorship &amp; License

- **Architect &amp; Developer**: Harsh Thakur (**Xeno — The Reaper of Eternal Graveyard**)
- **Platform Foundation**: Ubuntu Linux 24.04 LTS (Noble Numbat)
- **Kernel Architecture**: XanMod Linux with BORE Scheduler &amp; Kali Injection Extensions
- **Desktop Runtime**: Hyprland Wayland Compositor &amp; Astal v2 (Bun)
- **License**: Open Root Sovereignty &amp; GNU General Public License v3.0
