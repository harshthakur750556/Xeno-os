# Xeno OS — Hardware & Wireless Driver Subsystem

This directory contains configuration, helper scripts, and documentation for Xeno OS hardware drivers, focusing on high-performance wireless packet injection and cross-chipset compatibility.

---

## 1. In-Tree Drivers (Custom XanMod Kernel)

The production XanMod kernel (`kernel/build-kernel.sh` with `kernel/configs/xeno.config.fragment`) compiles and packages in-tree Linux wireless support (`CONFIG_WLAN=y`) covering:

| Chipset Family | In-Tree Driver Module | Injection Support |
|---|---|---|
| **Intel Dual-Band / Wi-Fi 6/6E/7** | `iwlwifi`, `iwlmvm`, `iwldvm` | Standard STA / AP (Restricted Injection) |
| **Atheros 802.11n (USB / PCIe)** | `ath9k`, `ath9k_htc` (AR9271) | Full Native Packet Injection & Monitor Mode |
| **Atheros 802.11ac (PCIe)** | `ath10k_core`, `ath10k_pci` | Monitor Mode & Frame Injection |
| **MediaTek 802.11ac/ax** | `mt76_core`, `mt76x2u`, `mt76x0u`, `mt7921e` | Monitor Mode & Active Injection |
| **Realtek Modern PCIe / USB** | `rtw88_core`, `rtw89_core` | Monitor Mode Support |
| **Broadcom FullMAC** | `brcmfmac`, `brcmutil` | Standard Operational Modes |
| **Ralink / ZyDAS Legacy USB** | `rt2800usb`, `zd1211rw` | Full Frame Injection & Monitor Mode |

### Kernel Patches Applied:
- `0001-mac80211-injection-sequence-and-qos.patch`: Enables raw 802.11 frame injection and custom sequence numbering.
- `0002-cfg80211-allow-monitor-channel-change.patch`: Allows dynamic channel switching while monitor virtual interfaces (VIFs) are active.
- `0003-legacy-usb-wifi-injection-helpers.patch`: Enhances packet injection reliability on USB adapters.

---

## 2. Out-of-Tree Wi-Fi Injection Adapters (DKMS)

Specialized USB Wi-Fi adapters based on the Realtek `rtl8812au` / `rtl8821au` chipset family require out-of-tree DKMS modules for monitor mode and packet injection.

### Automated Driver Installation

Run the dedicated out-of-tree driver installer inside a running Xeno OS environment or target RootFS:

```bash
sudo bash drivers/install-oot-wifi.sh
```

To target a specific root filesystem directory:
```bash
sudo env XENO_ROOTFS="/path/to/rootfs" bash drivers/install-oot-wifi.sh
```

The script:
1. Installs compilation prerequisites (`build-essential`, `dkms`, `git`, `bc`, and matching `linux-headers`).
2. Clones the patched `aircrack-ng/rtl8812au` repository.
3. Builds and registers the DKMS module against the active or staged kernel headers.

---

## 3. Kernel Deb Package Validation Gate

Before installing custom kernel packages or building out-of-tree modules, validate the staged `.deb` packages in `kernel/cache/`:

```bash
bash kernel/validate-kernel-deb.sh kernel/cache
```

This verification gate ensures:
- `CONFIG_WLAN=y`, `CONFIG_CFG80211=m/y`, `CONFIG_MAC80211=m/y` are enabled.
- Preemption model (`CONFIG_PREEMPT_BUILD=y`) and 1000Hz timer (`CONFIG_HZ_1000=y`) are active.
- Over 500+ kernel driver modules are cleanly packaged without `.dpkg-new` file corruption.

---

## 4. Post-Boot Wireless Verification

To test wireless interface detection, monitor mode creation, and packet injection capabilities on a booted system:

```bash
# Check loaded module
lsmod | grep -E "88XXau|ath9k|mt76|rtw88|iwlwifi"

# Run automated Xeno WiFi diagnostic helper
sudo xeno-wifi-monitor doctor

# Start a monitor mode virtual interface on wlan0
sudo xeno-wifi-monitor start wlan0
```
