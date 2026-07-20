# Xeno OS Drivers

## In-tree (custom XanMod kernel)

The production kernel build (`kernel/build-kernel.sh`) enables full `CONFIG_WLAN`
and major in-tree chipsets (Intel, Atheros, MediaTek, Realtek RTW88/89, Broadcom
fullmac, Ralink, ZyDAS, etc.) plus Kali-oriented mac80211/cfg80211 patches.

Validate any `linux-image-*.deb` with:

```bash
bash kernel/validate-kernel-deb.sh kernel/cache
```

## Out-of-tree injection adapters

Some USB Realtek adapters need the aircrack-ng `rtl8812au` driver:

```bash
sudo bash drivers/install-oot-wifi.sh
```

Only install OOT drivers against a **validated** Xeno kernel with matching headers.
