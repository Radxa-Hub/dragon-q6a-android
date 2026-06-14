# PROGRESS — Android 13 (GloDroid / AOSP) on the Radxa Dragon Q6A

> Early bring-up log (project bootstrap through the first full build). For the
> complete, current technical write-up see `DOCUMENTATION.md`; for the raw boot
> traces see `../boot-logs/`.

## Overall status
**Active phase:** Phase 1 — Build GloDroid + `dragon_q6a` target
**UART cable:** ❌ Not arrived yet (ordered ~2026-05-22, ~3 days)

---

## 2026-05-22 — Project bootstrap, environment check

### Build environment (WSL2)
| Check | Result | OK? |
|-------|--------|-----|
| Build tree | on a Linux-native filesystem (not `/mnt/c`) | ✅ |
| Free space | 953 GB / 1007 GB | ✅ |
| RAM in WSL2 | **~25 GB + 12 GB swap** (raised) | ✅ |
| CPU | 16 cores | ✅ |
| Network | github.com OK | ✅ |

---

## 2026-05-22 — Phase 0: Reconnaissance complete ✅

### Data gathered from Radxa OS on the Q6A
- dmesg (boot + GPU/display)
- lsblk / partition layout
- contents of /boot/efi (systemd-boot + kernel files)
- kernel configuration (zcat /proc/config.gz)
- vulkaninfo (Turnip confirmed)
- extlinux.conf + systemd-boot entries

### Key findings

**Boot chain (verified):**
Qualcomm UEFI v2.7 (SPI) → **systemd-boot** (BOOTAA64.EFI, 909 KB) → kernel + DTB from the ESP

- The bootloader is **systemd-boot**, not U-Boot. extlinux.conf = legacy fallback.
- Kernel, DTB and initrd live on the EFI partition (FAT32, 1 GB).
- DTB: `qcs6490-radxa-dragon-q6a.dtb` (184 KB) available directly on the ESP.

**Kernel 6.18.2-4-qcom:** Binder, Sync, DMA-BUF Heaps, DRM_MSM — all built in. Ready for Android without recompilation (bring-up).

**GPU:** Turnip Adreno 643, Vulkan 1.3.275 — working. Firmware: `a660_sqe.fw` + `a660_gmu.bin`.

**Display:** DPU 7.2 → DP controller → QMP PHY → hdmi-bridge → HDMI type A. card0=simpledrm (EFI fb), card1=msm_drm (the real DRM).

**Phase 0 DoD:** ✅ ARCHITECTURE.md written, with a clear boot-flow decision based on real data.

### Phase 0 TBD — CLOSED 2026-05-25
- [x] `loader.conf` — `timeout 3` (simplicity)
- [x] `RadxaOS-6.18.2-4-qcom.conf` — full entry with UUID, cmdline, paths
- [x] Binary DTB — decompiled, analysis complete (see 2026-05-25)

### Next step
**Phase 1:** prepare the GloDroid build environment + skeleton of the `dragon_q6a` target.

---

## 2026-05-22 — Phase 1: start (interrupted)

### Done
- Installed dependencies: `ccache 4.5.1`, `device-tree-compiler 1.6.1`, `openjdk-11-jdk 11.0.30`
- Installed `repo launcher v2.54` in `~/.local/bin/`
- Settled on the correct GloDroid branch: `master` (Android 13.0.0_r11); branch `android-13.0.0` does not exist
- Created `~/q6a/glodroid/`

### Blocked — missing git config
`repo init` requires a git identity. Not performed.

### Next session — 3 steps in this order

**Step 1 — git config (30 seconds):**
```bash
git config --global user.email "jerszjerszjersz@proton.me"
git config --global user.name "Huber"
```

**Step 2 — repo init + sync (run in screen, takes 3-8 h):**
```bash
cd ~/q6a/glodroid
repo init -u https://github.com/GloDroid/glodroid_manifest -b master --depth=1
# on success:
screen -S sync
repo sync -c -j8 --no-tags --no-clone-bundle
# Ctrl+A, D to detach
```

**Step 3 — files from the Q6A (USB stick or cat in terminal):**
- `sudo cat /boot/efi/loader/loader.conf`
- `sudo cat /boot/efi/loader/entries/RadxaOS-6.18.2-4-qcom.conf`
- Binary DTB: `/boot/efi/RadxaOS/6.18.2-4-qcom/qcs6490-radxa-dragon-q6a.dtb` (184 KB)
- GPU firmware: `find /usr/lib/firmware /lib/firmware -name "a660*"` → copy both files
- Kernel config: `/boot/config-6.18.2-4-qcom`

---

## 2026-05-23 — Phase 1: repo sync + git config

### Done (by the user between sessions)
- `git config --global` set (email + name)
- `repo init -u https://github.com/GloDroid/glodroid_manifest -b master --depth=1` OK
- `repo sync` finished — **136 GB** in `~/q6a/glodroid/`
- Full AOSP + GloDroid tree ready

---

## 2026-05-25 — Phase 1: DTB analysis + creation of the dragon_q6a target

### Files from the Q6A — received and verified

| File | Status |
|------|--------|
| `qcs6490-radxa-dragon-q6a.dtb` (184,388 B, fresh) | ✅ main DTB |
| `a660_gmu.bin` (54 KB) | ✅ GPU GMU firmware |
| `a660_sqe.fw.zst` (18 KB) | ✅ GPU SQE firmware (compressed) |
| `a660_zap.mbn` (1.1 MB) + `.zst` (2.4 KB) | ⚠️ have both, to verify after installing zstd |
| `config-6.18.2-4-qcom` (324 KB) | ✅ kernel config |
| `loader.conf` | ✅ systemd-boot: timeout 3 |
| `RadxaOS-6.18.2-4-qcom.conf` | ✅ boot entry with cmdline |
| `dragon_q6a.dtb` (185,007 B, May 13) | ❌ ignored — modified from a previous experiment |

### DTB analysis results

**HDMI bridge identified:** `compatible = "radxa,ra620"` — Radxa RA620 (DP→HDMI converter)

**Display pipeline (verified from DTB):**
```
DPU (sc7280-dpu, ae01000, port@2)
  → DP controller (sc7280-dp, ae90000, status=okay)
    → QMP PHY (data-lanes 0,1)
      → Radxa RA620 (hdmi-bridge)
        → HDMI connector type A
DSI (ae94000): disabled
eDP (aea0000): disabled
```

**GPU (verified from DTB):**
- `compatible = "qcom,adreno-635.0"`
- Firmware: `qcom/qcs6490/a660_zap.mbn` (note: `qcs6490/` subdirectory!)
- OPP: 315 MHz → 900 MHz (9 levels)
- GMU: `qcom,adreno-gmu-635.0`

**MMC:**
- sdhc_1 = `mmc@7c4000` (eMMC, hs400+enhanced strobe)
- sdhc_2 = `mmc@8804000` (SD card)
- `androidboot.boot_devices=platform/soc@0/8804000.mmc`

**Kernel config — key findings:**
- SELinux: `CONFIG_SECURITY_SELINUX=y` but **NOT in CONFIG_LSM** (defaults to bpf,yama,integrity...)
  → fix: `lsm=...,selinux,...` in the cmdline + `selinux=1`
- `BOOTPARAM=y` → selinux enabled via cmdline
- F2FS=m, FUSE=m, LOOP=m, DM=m, SQUASHFS=m — modules, not built-in

### Target `device/glodroid/dragon_q6a` — CREATED

Target files:
```
device/glodroid/dragon_q6a/
├── Android.mk              — copies the prebuilt kernel to $(PRODUCT_OUT)/kernel
├── AndroidProducts.mk      — registers dragon_q6a-userdebug
├── BoardConfig.mk          — GPU freedreno, KERNEL_BASE=0x80000000, SELinux cmdline
├── device.mk               — GPU firmware, Vulkan, Ethernet, no_suspend
├── dragon_q6a.mk           — product: arch, platform=qualcomm, prebuilt kernel
├── esp/                     — ESP partition template for systemd-boot
│   ├── loader/loader.conf
│   ├── loader/entries/android.conf
│   └── Android/             (kernel Image + DTB + ramdisk land here)
├── firmware/                — GPU firmware (a660_*)
├── gensdimg-uefi.sh         — script that builds the SD image from ESP + Android partitions
└── prebuilt/
    ├── Image                — ⚠️ DUMMY (64 KB) — the real one from the Q6A is needed!
    └── qcs6490-radxa-dragon-q6a.dtb  ✅
```

### Build tests
- `lunch dragon_q6a-userdebug` ✅ — target recognized
- `make fstab` ✅ — fstab.dragon_q6a generated correctly
- `make vulkan.freedreno` ❌ — requires `meson` (installed via pip3 --user, needs a symlink into /usr/local/bin)

### BLOCKERS

1. **`meson` not in the build PATH** — GloDroid AOSPEXT sets `PATH=/usr/bin:/bin:/sbin`, skipping `~/.local/bin`.
   Fix: `sudo ln -sf /home/huber/.local/bin/meson /usr/local/bin/meson`

2. **No real kernel Image** — dummy 64 KB, the real one from the Q6A is needed:
   ```bash
   # On the Q6A:
   sudo cp /boot/efi/RadxaOS/6.18.2-4-qcom/linux /media/pendrive/Image
   ```
   File ~36 MB (compressed) or ~64 MB (uncompressed).

3. **`zstd` not installed** — needed to verify firmware.
   Fix: `sudo apt install -y zstd`

### Next steps (once unblocked)

1. Install meson + zstd (sudo)
2. Provide the kernel Image from the Q6A
3. Run a full `make droid -j16` (estimated: 2-4h)
4. After the build: assemble the SD image with gensdimg-uefi.sh
5. **Phase 2:** flash SD → first boot

---

## 2026-05-26 — Phase 1: first full build (interrupted manually)

### Done
- Blockers from the previous session resolved: meson symlink ✅, zstd ✅, kernel Image 62 MB ✅
- Started `make droid` (tune `-j<N>` to your build host)
- Build reached **~74%** (73417/98179 tasks, time: ~1h3m)
- Stopped **manually by the user** (it was late) — no errors, ninja state preserved

### State of artifacts in out/
- `out/target/product/dragon_q6a/` exists with partial artifacts
- Ninja will resume the build from 74% without recompiling

### Next steps
1. Resume: `cd <glodroid> && source build/envsetup.sh && lunch dragon_q6a-userdebug && make droid`
2. Remaining ~26% — estimated: ~30-60 min
3. After the build: assemble the SD image with `gensdimg-uefi.sh`
4. **Phase 2:** flash SD → first boot

---
