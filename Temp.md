## Executive summary

Xeno OS splits **rootfs creation** (external/manual debootstrap artifact) from **ISO pipeline updates** (`scripts/auto-build.sh`). Security and Windows-compat logic exists in dedicated setup scripts, but the **current rootfs has not had those scripts applied**. The live image is closer to a permissive Ubuntu desktop lab than a Kali-like hardened security OS with full Windows app support.

---

## 1. `rootfs/` structure — package lists, apt sources, pinning

### Current state

| Area | Path | State |
|---|---|---|
| Base Ubuntu sources | `/home/xeno/Xeno-os/rootfs/etc/apt/sources.list` | Noble main/restricted/universe/multiverse + updates + security |
| Hyprland PPA | `/home/xeno/Xeno-os/rootfs/etc/apt/sources.list.d/cppiber-ubuntu-hyprland-noble.sources` | Present |
| Google Chrome repo | `/home/xeno/Xeno-os/rootfs/etc/apt/sources.list.d/google-chrome.sources` | Present |
| Kali rolling repo | `/home/xeno/Xeno-os/rootfs/etc/apt/sources.list.d/kali-rolling.list` | **Missing** |
| Apt pinning | `/home/xeno/Xeno-os/rootfs/etc/apt/preferences.d/` | **Empty** (no Kali pin) |
| Keyrings | `/home/xeno/Xeno-os/rootfs/etc/apt/keyrings/` | **Empty** |
| Package manifest in repo | — | **Missing** (no `packages.txt`, no debootstrap script) |
| Package count | — | ~3044 installed (full desktop, not minbase) |

### What the repo defines (not yet in rootfs)

`/home/xeno/Xeno-os/scripts/setup-security-tools.sh` would create:

- `/home/xeno/Xeno-os/rootfs/etc/apt/sources.list.d/kali-rolling.list`
- `/home/xeno/Xeno-os/rootfs/etc/apt/preferences.d/kali-pinning` (Pin-Priority **100** for `o=Kali`)
- `/home/xeno/Xeno-os/rootfs/etc/apt/keyrings/kali-archive-keyring.gpg`

Pinning strategy: Kali is **opt-in only** via `apt-get install -t kali-rolling <pkg>` — safe for Ubuntu base, but not equivalent to a native Kali metapackage install.

### Gap

There is **no reproducible rootfs bootstrap** in the repo. `.cursorrules` / `AGENTS.md` mention debootstrap minbase, but no script creates or maintains a canonical package list. Rootfs is a large hand-grown artifact.

---

## 2. Build pipeline — how rootfs is built/updated

### Primary script: `/home/xeno/Xeno-os/scripts/auto-build.sh`

Pipeline order:

1. `/home/xeno/Xeno-os/scripts/fix-boot-display.sh` — Hyprland launcher, scoped RT limits (script intent)
2. Kernel fetch/validate/install via `/home/xeno/Xeno-os/scripts/fix-kernel-rootfs.sh`
3. Casper live stack (purge `live-boot`, reinstall `casper`, initramfs)
4. `rsync` desktop + tests into rootfs
5. **Conditional feature setup** (idempotent markers):
   - `/home/xeno/Xeno-os/scripts/setup-compat-stack.sh` if `/usr/bin/xeno-windows` missing
   - `/home/xeno/Xeno-os/scripts/setup-security-tools.sh` if `/usr/bin/xeno-wifi-monitor` missing
6. SquashFS → GRUB ISO Level 3

Shared chroot helpers: `/home/xeno/Xeno-os/scripts/lib-chroot.sh`

Other related scripts:

| Script | Role |
|---|---|
| `/home/xeno/Xeno-os/scripts/enter-rootfs.sh` | Interactive chroot |
| `/home/xeno/Xeno-os/scripts/install-astal-chroot.sh` | Astal/Bun shell deps |
| `/home/xeno/Xeno-os/drivers/install-oot-wifi.sh` | Optional rtl8812au DKMS (manual, not in auto-build) |

### Current rootfs vs pipeline intent

| Marker / check | Expected after setup | Actual rootfs |
|---|---|---|
| `/usr/bin/xeno-windows` | from compat script | **Missing** |
| `/usr/bin/xeno-wifi-monitor` | from security script | **Missing** |
| `/etc/profile.d/xeno-wine.sh` | from compat script | **Missing** |
| Kali apt config | from security script | **Missing** |

**Conclusion:** `auto-build.sh` has not been run through the feature-setup stage on this rootfs (or it failed/was skipped). Next `auto-build.sh` run should trigger both setup scripts.

### Broken package state (show-stopper)

```
hi  hyprland                          (half-installed)
hi  xdg-desktop-portal-hyprland       (half-installed)
hi  xwayland                          (half-installed)
iU  linux-headers-7.1.2-xeno1-xanmod1 (unpacked, not configured)
iHR linux-image-7.1.2-xeno1-xanmod1   (half-installed, reinst-required)
```

`auto-build.sh` calls `xeno_assert_no_broken_pkgs` before squashfs — a clean ISO build would **fail** until this is repaired.

---

## 3. Kali integration, metapackages, firmware

### Kali integration (repo design)

**File:** `/home/xeno/Xeno-os/scripts/setup-security-tools.sh`

- `ENABLE_KALI_REPO=1` by default
- Ubuntu-first tool install (~50 packages: aircrack-ng, hashcat, nmap, wireshark, sqlmap, tor, nftables, etc.)
- Kali-only pull list: `wifite`, `airgeddon`, `responder`, `bloodhound` (explicit `-t kali-rolling`)
- **No Kali metapackages** (`kali-linux-default`, `kali-tools-wireless`, etc.)

### Kernel-level Kali alignment (present)

| Component | Path |
|---|---|
| mac80211/cfg80211 patches | `/home/xeno/Xeno-os/kernel/patches/0001-*.patch`, `0002-*.patch`, `0003-*.patch` |
| WLAN config fragment | `/home/xeno/Xeno-os/kernel/configs/xeno.config.fragment` |
| Deprecated top-level patch | `/home/xeno/Xeno-os/kali-wifi-injection.patch` (points to kernel/patches/) |

### Firmware (partial)

**Installed in rootfs:**
- `linux-firmware`
- `firmware-sof-signed`

**Script would also install:** `firmware-sof-signed`, `wireless-tools`, `iw`, `rfkill`, etc. — but most wireless pentest tools from the script are **not installed**.

### Pentest tools — script target vs rootfs reality

| Category | In setup script | In current rootfs |
|---|---|---|
| aircrack-ng / reaver / mdk4 / hcxtools | Yes | **No** |
| wireshark / tshark / kismet | Yes | **No** |
| hashcat / hydra / john / nmap / sqlmap / tor | Yes | **Partial** (hashcat, hydra, john, nmap, sqlmap, tor yes) |
| bettercap / ettercap / gobuster / nikto | Yes | **No** (nikto via grep earlier — actually sqlmap yes, nikto no) |
| python3-scapy / impacket / pwntools | Yes | **No** |
| Kali-only (wifite, etc.) | Script + repo | **No repo, no packages** |
| `xeno-wifi-monitor` helper | Script | **Missing** |

---

## 4. Security defaults — live-lab vs hardened

### Current live-lab posture (permissive)

| Control | Path / fact | Assessment |
|---|---|---|
| Sudo | `/home/xeno/Xeno-os/rootfs/etc/sudoers.d/xeno` → `NOPASSWD:ALL` | **Live-lab default**, not hardened |
| Autologin | `/home/xeno/Xeno-os/rootfs/etc/systemd/system/getty@tty1.service.d/override.conf` | tty1 autologin as `xeno` |
| Casper user | `/home/xeno/Xeno-os/rootfs/etc/casper.conf` | `USERNAME=xeno`, `HOST=xeno-os` |
| RT/memlock limits | `/home/xeno/Xeno-os/rootfs/etc/security/limits.d/99-hyprland.conf` | **Wildcard `*`** — grants RT to all users (fix-boot-display.sh would scope to `@hyprland` + `xeno`) |
| Firewall | — | **No ufw, no firewalld** installed or configured |
| SSH server | `openssh-server` | **Not installed** (client only) |
| SSH hardening | `/etc/ssh/sshd_config*` | No custom hardening |
| fail2ban | — | **Absent** |
| AppArmor | `apparmor` package | Default Ubuntu; no Xeno-specific profiles |
| Wireshark capture | Script sets setuid + `wireshark` group | **Not applied** (wireshark not installed) |
| Tor | Installed | Present, no documented firewall integration |

### What exists in scripts but not enforced

`/home/xeno/Xeno-os/scripts/fix-boot-display.sh` documents scoped RT limits as a security fix — rootfs still has the old global `*` config.

### Missing entirely

- No `live-lab` vs `hardened` profile toggle (env var, casper hook, or separate package set)
- No default firewall rules for lab vs daily-driver
- No SSH install policy (disabled by default vs hardened enable)
- No auditd, no AppArmor custom confinement for Wine/Bottles
- No documentation of secure defaults for installed pentest tools (e.g. disabling services, binding tor)

---

## 5. Wine / Bottles / Windows app compatibility

### Repo design: `/home/xeno/Xeno-os/scripts/setup-compat-stack.sh`

Would install:

- i386 multiarch
- System Wine stack (`wine`, `wine64`, `wine32`, `winetricks`, DXVK/VKD3D deps, gamemode, mangohud)
- Flatpak + Flathub + `com.usebottles.bottles` + `org.winehq.Wine`
- `/etc/profile.d/xeno-wine.sh` (WINEESYNC, WINEFSYNC, WINE_VK_USE_WSI)
- `/usr/bin/xeno-windows` helper + desktop entries

Kernel support: `CONFIG_NTSYNC=y` in `/home/xeno/Xeno-os/kernel/configs/xeno.config.fragment`

Session launcher also sets Wine sync vars: `/home/xeno/Xeno-os/rootfs/usr/bin/xeno-start-hyprland` (partial; fix-boot-display version is more complete)

### Current rootfs state

| Component | State |
|---|---|
| `flatpak` | Installed |
| Flatpak apps | `/home/xeno/Xeno-os/rootfs/var/lib/flatpak/app/com.usebottles.bottles`, `org.winehq.Wine` |
| System Wine / winetricks / gamemode | **Not installed** |
| i386 multiarch | **Not enabled** (only amd64) |
| `xeno-windows` helper | **Missing** |
| `xeno-wine.sh` profile.d | **Missing** |
| DXVK/VKD3D apt packages | **Not installed** |
| `mesa-vulkan-drivers` | Installed (amd64 only) |

**Assessment:** Partial Flatpak-only Windows path exists; the documented hybrid (system Wine + Bottles + DXVK/VKD3D + gamemode + `xeno-windows`) is **not deployed**.

---

## Gap matrix: target vs current

| Capability | Defined in repo | In current rootfs | Gap severity |
|---|---|---|---|
| Reproducible rootfs bootstrap | Docs only | Manual artifact | **High** |
| Kali apt repo + pinning | `setup-security-tools.sh` | Absent | **High** |
| Full pentest toolchain | Script list | ~10% installed | **High** |
| `xeno-wifi-monitor` | Script | Missing | **High** |
| Kernel injection patches | CI + patches | Kernel broken (iHR) | **High** |
| Firewall defaults | — | None | **High** |
| SSH hardening / policy | — | No server | **Medium** |
| Hardened vs live-lab profiles | — | Live-lab only | **High** |
| NOPASSWD sudo | rootfs | Active | **High** (for hardened target) |
| Scoped RT limits | fix-boot-display.sh | Wildcard `*` still | **Medium** |
| Full Wine/Bottles stack | setup-compat-stack.sh | Flatpak only | **Medium** |
| `xeno-windows` CLI | setup-compat-stack.sh | Missing | **Medium** |
| PySide6 scientific GUI | .cursorrules deps | **Not installed** | **High** (Phase 2) |
| Kali metapackages | — | Not used | **Medium** (by design, but limits Kali parity) |
| OOT WiFi drivers in build | `drivers/install-oot-wifi.sh` | Manual only | **Low–Medium** |

---

## Recommended next steps (for parent agent)

1. **Repair dpkg state** — run `fix-kernel-rootfs.sh`, finish/reinstall `hyprland`, `xwayland`, `xdg-desktop-portal-hyprland`.
2. **Run feature setup** — `sudo XENO_FORCE_FEATURE_SETUP=1 bash scripts/setup-security-tools.sh` and `setup-compat-stack.sh` (or full `auto-build.sh`).
3. **Add rootfs bootstrap** — debootstrap script + versioned package manifest(s) for `live-lab` and `hardened` profiles.
4. **Add security layer** — ufw/nftables default rules, SSH policy, remove/restrict `NOPASSWD:ALL` in hardened profile, apply scoped limits from `fix-boot-display.sh`.
5. **Document Kali strategy** — keep Ubuntu-first + pinned Kali opt-in, or add optional `kali-tools-*` metapackage profile with stricter pinning.

---

## Key file index

| Purpose | Absolute path |
|---|---|
| ISO pipeline | `/home/xeno/Xeno-os/scripts/auto-build.sh` |
| Security/wireless setup | `/home/xeno/Xeno-os/scripts/setup-security-tools.sh` |
| Wine/Bottles setup | `/home/xeno/Xeno-os/scripts/setup-compat-stack.sh` |
| Boot/session security limits | `/home/xeno/Xeno-os/scripts/fix-boot-display.sh` |
| Chroot helpers | `/home/xeno/Xeno-os/scripts/lib-chroot.sh` |
| Kernel WLAN/injection config | `/home/xeno/Xeno-os/kernel/configs/xeno.config.fragment` |
| OOT WiFi drivers | `/home/xeno/Xeno-os/drivers/install-oot-wifi.sh` |
| Live user config | `/home/xeno/Xeno-os/rootfs/etc/casper.conf` |
| Sudo policy | `/home/xeno/Xeno-os/rootfs/etc/sudoers.d/xeno` |
| RT limits (current) | `/home/xeno/Xeno-os/rootfs/etc/security/limits.d/99-hyprland.conf` |


---



# Kernel Build Pipeline Investigation Report

Most relevant `.cursorrules` section for this audit: **Section 4 (RESO_01)** — it documents Ubuntu production baseline config, but the actual build script prefers XanMod configs and only falls back to Ubuntu.

---

## 1. Patch Application — `kernel/build-kernel.sh`

**Path:** `/home/xeno/Xeno-os/kernel/build-kernel.sh`

Patches are applied from `kernel/patches/*.patch` in glob order via `apply_patch()`:

```46:76:/home/xeno/Xeno-os/kernel/build-kernel.sh
apply_patch() {
    local patch_file="$1"
    local name
    name="$(basename "$patch_file")"
    echo "Applying: $name"
    # Already-applied patches print reverse-hunk messages; treat as OK
    if patch -p1 --forward --dry-run < "$patch_file" >/tmp/xeno-patch-dry.log 2>&1; then
        patch -p1 --forward < "$patch_file"
        echo "  ✓ applied $name"
    else
        if grep -qiE 'previously applied|Reversed \(or previously applied\)|Ignoring previously applied' /tmp/xeno-patch-dry.log; then
            echo "  ✓ already applied: $name"
            return 0
        fi
        # Core mac80211 / cfg80211 patches are hard requirements
        if [[ "$name" == 0001-* || "$name" == 0002-* ]]; then
            echo "ERROR: required patch failed: $name"
            cat /tmp/xeno-patch-dry.log
            exit 1
        fi
        # Legacy driver helpers may not exist on all trees — warn, do not abort
        echo "WARNING: optional patch skipped (context mismatch): $name"
        cat /tmp/xeno-patch-dry.log | tail -30
    fi
}
```

### Loopholes

| Issue | Detail |
|-------|--------|
| **Silent skip for 0003+** | Only `0001-*` and `0002-*` are hard-fail. `0003-legacy-usb-wifi-injection-helpers.patch` can fail on context mismatch and the build continues. |
| **Filename convention trap** | Any future patch not prefixed `0001-` or `0002-` is treated as optional — even if it is critical. |
| **No post-build patch audit** | There is no check that patches actually landed; only Kconfig validation runs later. |
| **Floating XanMod HEAD** | `git clone --depth=1` always pulls latest XanMod. Patches can break (0001/0002 fail loud) or 0003 silently skip as the tree drifts. |
| **"Already applied" heuristic** | String-matching on dry-run log may mask partial/conflicting upstream changes. |

Build aborts correctly on 0001/0002 failure (`exit 1` with `set -euo pipefail`). The problem is **0003 and any misnamed patch**, not total silence on all failures.

---

## 2. CI Workflow — `.github/workflows/build-kernel.yml`

**Path:** `/home/xeno/Xeno-os/.github/workflows/build-kernel.yml`

The workflow does **not** use `continue-on-error`. It calls `build-kernel.sh`, which inherits the optional-patch behavior above.

### Runner config

```19:61:/home/xeno/Xeno-os/.github/workflows/build-kernel.yml
  compile_kernel:
    name: Compile Kernel Packages
    runs-on: ubuntu-latest
    timeout-minutes: 360
    ...
      - name: Build Xeno OS kernel
        run: |
          chmod +x kernel/build-kernel.sh kernel/validate-kernel-deb.sh
          bash kernel/build-kernel.sh
```

- Disk cleanup before build (Android, dotnet, CodeQL, etc.)
- Outputs to `kernel/output/*.deb` → artifact `xeno-kernel-debs`
- `build-kernel.sh` runs `validate-kernel-deb.sh` at the end

### Critical CI loophole: scheduled builds don't publish releases

```75:75:/home/xeno/Xeno-os/.github/workflows/build-kernel.yml
    if: github.event_name == 'push' || github.event_name == 'workflow_dispatch'
```

Monthly cron (`0 2 1 * *`) compiles and uploads artifacts, but **`publish_release` is skipped**. ISO pipeline downloads from GitHub Releases, not artifacts — so scheduled builds do not update what `auto-build.sh` consumes.

### Trigger path gap

Push triggers only watch `kernel/patches/**`, not repo-root `kali-wifi-injection.patch`.

### Release claims vs reality

Release body always states full injection patches were applied, with no verification that 0003 succeeded:

```98:102:/home/xeno/Xeno-os/.github/workflows/build-kernel.yml
          body: |
            Xeno OS custom XanMod kernel with:
            - Full CONFIG_WLAN + major in-tree Wi-Fi drivers
            - Kali-oriented mac80211 / cfg80211 injection patches
            - PREEMPT + 1000Hz + NTSYNC (Windows app smoothness)
```

---

## 3. Patches — what exists vs what's applied

### Repo-root stub (deprecated)

**Path:** `/home/xeno/Xeno-os/kali-wifi-injection.patch`

Not a real patch — 10-line deprecation notice pointing to `kernel/patches/`:

```1:9:/home/xeno/Xeno-os/kali-wifi-injection.patch
# DEPRECATED — do not apply this file directly.
#
# The maintained Kali/Xeno wireless injection series lives in:
#   kernel/patches/0001-mac80211-injection-sequence-and-qos.patch
#   kernel/patches/0002-cfg80211-allow-monitor-channel-change.patch
#   kernel/patches/0003-legacy-usb-wifi-injection-helpers.patch
```

Nothing references this file; it is not in CI triggers or `build-kernel.sh`.

### Active patch series

| File | Target | Required? |
|------|--------|-----------|
| `/home/xeno/Xeno-os/kernel/patches/0001-mac80211-injection-sequence-and-qos.patch` | `net/mac80211/tx.c` — injection sequence + QoS | **Yes** (build aborts) |
| `/home/xeno/Xeno-os/kernel/patches/0002-cfg80211-allow-monitor-channel-change.patch` | `net/wireless/chan.c` — monitor channel with normal VIF | **Yes** (build aborts) |
| `/home/xeno/Xeno-os/kernel/patches/0003-legacy-usb-wifi-injection-helpers.patch` | `zd1211rw`, `rtl8187` legacy USB drivers | **Optional** (warn + continue) |

0003 touches drivers that may be refactored/removed in newer XanMod trees — likely to fail silently over time.

---

## 4. Docs vs actual kernel config

### Doc claim: Ubuntu production baseline

`.cursorrules` RESO_01:

```141:148:/home/xeno/Xeno-os/.cursorrules
│  [RESO_01] UNIVERSAL DRIVER STRATEGY                                         │
│  The kernel is a full-featured, complete production-grade XanMod kernel (not │
│  a stripped-down build). It does not use `make x86_64_defconfig`. Instead,   │
│  it uses the complete Ubuntu Production Baseline config from the GitHub      │
│  Actions runner at `/boot/config-$(uname -r)`, ensuring 100% hardware,       │
│  peripheral, and VM compatibility (including vboxguest, vboxvideo,           │
│  hv_vmbus, hv_storvsc, and hyperv_drm compiled as modules).                  │
```

**Actual behavior** in `build-kernel.sh`:

```79:104:/home/xeno/Xeno-os/kernel/build-kernel.sh
BASE_CFG=""
for candidate in \
    CONFIGS/xanmod/gcc/config_x86-64-v3 \
    CONFIGS/xanmod/gcc/config_x86-64 \
    CONFIGS/xanmod/gcc/config \
    arch/x86/configs/xanmod_defconfig
do
    if [ -f "$candidate" ]; then
        BASE_CFG="$candidate"
        break
    fi
done

if [ -n "$BASE_CFG" ]; then
    echo "Using XanMod baseline: $BASE_CFG"
    cp "$BASE_CFG" .config
else
    echo "XanMod baseline not found — falling back to host Ubuntu config + olddefconfig"
    if [ -f "/boot/config-$(uname -r)" ]; then
        cp "/boot/config-$(uname -r)" .config
```

On CI, XanMod configs always exist → **Ubuntu `/boot/config-$(uname -r)` is never used**. VM modules (vboxguest, hyperv_drm, etc.) are not in `xeno.config.fragment` and are not validated.

### Doc claim: full Kali mac80211 injection

README badge and copy:

- `README.md`: "Injection-Kali_mac80211_Patched", "kernel-level Wi-Fi frame injection"
- `drivers/README.md`: "Kali-oriented mac80211/cfg80211 patches"

**Validation only checks Kconfig + modules**, not patch presence:

```40:43:/home/xeno/Xeno-os/kernel/validate-kernel-deb.sh
check_cfg '^CONFIG_WLAN=y'
check_cfg '^CONFIG_CFG80211=[ym]'
check_cfg '^CONFIG_MAC80211=[ym]'
check_cfg '^CONFIG_(ATH9K|IWLWIFI|RTW88|MT76_CORE|BRCMFMAC)=[ym]'
```

A kernel can pass validation with 0003 skipped and no legacy USB injection helpers, while docs still claim full Kali injection.

### Silent config failures

```141:141:/home/xeno/Xeno-os/kernel/build-kernel.sh
./scripts/config --enable CONFIG_NTSYNC || ./scripts/config --module CONFIG_NTSYNC || true
```

NTSYNC (claimed in release notes for Wine/Proton) can fail silently. Fragment merge fallback also uses `|| true` per line (lines 119–127).

### WLAN fragment vs enforcement

**Path:** `/home/xeno/Xeno-os/kernel/configs/xeno.config.fragment` — extensive WLAN vendor/driver list.

Build script hard-enforces core wireless options (lines 133–137) and validates at least one major driver family (lines 174–178). That part is solid for **driver presence**, not **injection behavior**.

---

## 5. Rootfs kernel installation path

### Pipeline flow

```
CI build-kernel.sh → kernel/output/*.deb
                  → artifact → publish_release → GitHub Release
auto-build.sh     → gh release download → kernel/cache/*.deb
                  → validate-kernel-deb.sh
                  → fix-kernel-rootfs.sh (chroot dpkg -i)
                  → ISO casper/vmlinuz
```

### Key scripts

| Script | Path | Role |
|--------|------|------|
| ISO pipeline | `/home/xeno/Xeno-os/scripts/auto-build.sh` | Requires `gh auth`, downloads release debs to `kernel/cache`, validates, installs |
| Rootfs install | `/home/xeno/Xeno-os/scripts/fix-kernel-rootfs.sh` | Copies cache debs into chroot, `dpkg -i`, WLAN gate |
| Validation | `/home/xeno/Xeno-os/kernel/validate-kernel-deb.sh` | Pre-install gate |

### Loopholes in rootfs install

**No local build bridge** — `auto-build.sh` never reads `kernel/output/`. Local `build-kernel.sh` output must be manually copied to `kernel/cache/`. No script does this.

**Cache state is broken locally** — `/home/xeno/Xeno-os/kernel/cache/` contains only `latest_release.json` (tag `kernel-11`); no `.deb` files. `*.deb` is gitignored. `auto-build.sh` fails at:

```76:78:/home/xeno/Xeno-os/scripts/auto-build.sh
if ! ls "$CACHE_DIR"/linux-image-*.deb &>/dev/null; then
    echo "ERROR: no linux-image-*.deb in $CACHE_DIR"
    exit 1
```

**Fallback masks invalid custom kernel** — if validation fails, ISO still builds with Ubuntu generic:

```86:102:/home/xeno/Xeno-os/scripts/auto-build.sh
else
    ...
    echo "Continuing with Ubuntu generic kernel fallback for this ISO build."
    KERNEL_VALID=0
fi
```

ISO ships without XanMod/injection; only a note at the end mentions it.

**dpkg stderr suppressed** in `fix-kernel-rootfs.sh`:

```106:107:/home/xeno/Xeno-os/scripts/fix-kernel-rootfs.sh
dpkg -i linux-image-*.deb linux-headers-*.deb linux-libc-dev*.deb 2>/dev/null \
    || dpkg -i ./*.deb
```

Follow-up integrity checks mitigate this, but first-pass errors are hidden.

**Weak injection gate in rootfs** — only checks `CONFIG_WLAN=y`, not mac80211 patches or injection-specific config:

```142:146:/home/xeno/Xeno-os/scripts/fix-kernel-rootfs.sh
if [ -f "/boot/config-$NEW_VERSION" ] && ! grep -q '^CONFIG_WLAN=y' "/boot/config-$NEW_VERSION"; then
    echo "ERROR: installed kernel has CONFIG_WLAN disabled"
    exit 1
fi
```

**Version selection** uses `head -1` not `sort -V` when multiple xeno kernels exist (line 125).

---

## Summary: What's broken

1. **Optional patch 0003** can fail silently; CI and validation still pass; release/docs claim full injection.
2. **Docs lie about config baseline** — RESO_01 says Ubuntu runner config; build uses XanMod configs; VM driver guarantees are undocumented/unvalidated.
3. **Scheduled CI builds don't publish** — ISO pipeline stays on stale GitHub Release debs.
4. **No local output → cache bridge** — `kernel/output/` and `kernel/cache/` are disconnected.
5. **Local cache empty** — metadata without debs blocks `auto-build.sh`.
6. **Validation gap** — checks WLAN Kconfig/modules, not patch application, NTSYNC, PREEMPT, or injection behavior.
7. **Deprecated root patch file** — `kali-wifi-injection.patch` can mislead; not wired into pipeline.
8. **No kernel tests** — `tests/` has zero kernel/WLAN/injection coverage.

---

## Recommended fixes

1. **Patch policy:** Treat all injection patches as required, or add post-patch source verification (grep for known hunks in `tx.c`, `chan.c`, etc.). Fail build if 0003 skips; log a patch summary artifact.
2. **Pin XanMod** to a tagged commit/ref instead of `HEAD` to reduce drift.
3. **CI publish:** Run `publish_release` on `schedule` too, or have `auto-build.sh` download workflow artifacts instead of releases.
4. **Config docs/code alignment:** Update RESO_01 to match XanMod baseline + fragment, or change build script to use Ubuntu config as documented. Add VM module checks to validation if that remains a claim.
5. **Extend `validate-kernel-deb.sh`:** Check `CONFIG_PREEMPT`, `CONFIG_HZ=1000`, NTSYNC if present, and optionally strings/grep in `vmlinux` for injection markers.
6. **Local dev path:** Add `scripts/stage-kernel-debs.sh` to copy `kernel/output/*.deb` → `kernel/cache/` after validation.
7. **Remove or relocate** deprecated `kali-wifi-injection.patch` to avoid confusion.
8. **Fix rootfs install:** Remove `2>/dev/null` on dpkg; use `sort -V` for kernel version selection.
9. **ISO fallback:** Fail by default when custom kernel invalid (opt-in fallback via env var) if injection/XanMod is a hard requirement.

---

## File index

| Path | Purpose |
|------|---------|
| `/home/xeno/Xeno-os/kernel/build-kernel.sh` | Clone XanMod, apply patches, merge config, build debs |
| `/home/xeno/Xeno-os/kernel/validate-kernel-deb.sh` | WLAN/module validation gate |
| `/home/xeno/Xeno-os/kernel/configs/xeno.config.fragment` | WLAN + latency Kconfig overlay |
| `/home/xeno/Xeno-os/kernel/patches/0001-*.patch` | mac80211 injection (required) |
| `/home/xeno/Xeno-os/kernel/patches/0002-*.patch` | cfg80211 monitor channel (required) |
| `/home/xeno/Xeno-os/kernel/patches/0003-*.patch` | Legacy USB injection (optional) |
| `/home/xeno/Xeno-os/kali-wifi-injection.patch` | Deprecated pointer only |
| `/home/xeno/Xeno-os/.github/workflows/build-kernel.yml` | CI compile + conditional release |
| `/home/xeno/Xeno-os/scripts/auto-build.sh` | ISO pipeline, gh release download |
| `/home/xeno/Xeno-os/scripts/fix-kernel-rootfs.sh` | Chroot kernel install/repair |
| `/home/xeno/Xeno-os/drivers/README.md` | Driver/injection documentation |
| `/home/xeno/Xeno-os/.cursorrules` (RESO_01) | Stale Ubuntu baseline claim |