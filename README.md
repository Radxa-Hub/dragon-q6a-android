# Native Android 13 on the Radxa Dragon Q6A

A from-scratch [GloDroid](https://github.com/GloDroid)-based **native Android 13**
port for the **Radxa Dragon Q6A** (Qualcomm QCS6490), booting from SD card via
UEFI + systemd-boot. This repository holds the device tree, the prebuilt
artifacts needed to build and flash, the cmdline/ramdisk history, and the full
UART bring-up debug journey.

> Status: **boots to the Android 13 UI with working display and WiFi.** This was
> a long hardware-in-the-loop bring-up — see `docs/PROGRESS.md` and `boot-logs/`
> for the blow-by-blow.

## What works

| Subsystem | Status | Notes |
|-----------|--------|-------|
| Boot chain | ✅ | Qualcomm UEFI (SPI) → systemd-boot → kernel + DTB + ramdisk from ESP |
| Boot to UI | ✅ | `sys.boot_completed=1`, zero reboots |
| Display | ✅ | DPU → DP → Radxa RA620 HDMI bridge; `initcall_blacklist=simpledrm` so HWC takes the panel. EDID forced for Waveshare 7" 1024×600 |
| GPU | ✅ | Adreno 643, Turnip/freedreno; a660 firmware uncompressed in vendor |
| USB host + touch | ✅ | dwc3 host, onboard hub; USB touchscreen as a real touchscreen (IDC forces `touch.deviceType=touchScreen`, else it acts as a mouse cursor) |
| WiFi | ✅ | AIC8800D80 (USB), fullmac; wpa_supplicant + wificond, no vendor HAL |
| adb over TCP | ✅ | `service.adb.tcp.port=5555` (USB-C is power-only — no adb-by-cable on this board) |
| Bluetooth | ✅ | AIC8800D80 BT = standard USB transport; `bluetooth.ko` + `aic_btusb_usb.ko` bring up hci0, GloDroid `btlinux` HAL drives it. Needs `rt_group_sched=0` (disarms an RT_GROUP_SCHED abort-loop) |

## Hardware

- **Board:** Radxa Dragon Q6A (Qualcomm QCS6490 / Kodiak)
- **Display:** Waveshare 7" HDMI LCD (C), 1024×600 IPS + USB touch
- **Storage:** boots from SD card (`mmc@8804000`); eMMC untouched
- **WiFi/BT:** AIC8800D80 combo, USB-attached behind the onboard hub
- **Debug:** UART0 on the 40-pin header (GND=pin6, board-TX=pin8, board-RX=pin10, 115200 8N1, 1.8 V)

## Quick flash (ready-made image)

A ready-to-flash community image (`.img.zst`, ~890 MB) will be attached to the
[Releases](../../releases) page. The first community image predates the WiFi
userspace fix (`wpa_supplicant` + corrected firmware path), so it is being
**refreshed** before publication — until the refreshed asset is up, **build from
source** (below).

Once published, flash with:

```bash
# decompress and flash to the SD card (replace sdX with your card!)
zstd -d dragon_q6a_sd_community.img.zst -o dragon_q6a_sd_community.img
sudo dd if=dragon_q6a_sd_community.img of=/dev/sdX bs=4M status=progress conv=fsync
```

Then insert the card and power on. First boot to UI takes ~2 minutes.

## Build from source

This device tree plugs into a GloDroid (Android 13, `master`) checkout:

```bash
# inside a synced glodroid tree:
cp -r device/glodroid/dragon_q6a <glodroid>/device/glodroid/
# the prebuilt kernel Image + DTB live under device/glodroid/dragon_q6a/prebuilt/
source build/envsetup.sh
lunch dragon_q6a-userdebug
make droid -j8          # -j8 keeps CPU temps in check on the build machine
# then assemble the SD image:
device/glodroid/dragon_q6a/gensdimg-uefi.sh
```

The kernel is the **RadxaOS prebuilt 6.18.2-4-qcom** (not rebuilt) — `prebuilt/Image`
and `prebuilts-radxa/modules.tar.gz` are committed directly. See `NOTICE` for the
GPL-2.0 source offer.

## Repository layout

```
device/glodroid/dragon_q6a/   the device tree (BoardConfig, device.mk, esp/, firmware/,
                              prebuilt/, gensdimg-uefi.sh) — drop into a GloDroid checkout
docs/                         DOCUMENTATION, ARCHITECTURE, PROGRESS + reference DTS/kernel config
prebuilts-radxa/              RadxaOS extracts (modules.tar.gz, BOOTAA64.EFI)
images/                       latest ramdisk + cmdline (.conf) history + Waveshare EDID
boot-logs/                    verbatim UART boot logs across the whole bring-up (v21 … v34)
scripts/                      helper scripts
```

## Notes on the bring-up

This port required solving a chain of QCS6490/GloDroid-specific issues, all
documented in the boot logs and `docs/PROGRESS.md`:

- **FMQ / memfd** — kernel lacks `CONFIG_ASHMEM`; needs `sys.use_memfd=true`.
- **fuse / netd / RescueParty loops** — `fuse.ko`, netfilter modules, and netd
  `setGlobalAlert` made non-fatal (kernel lacks `xt_quota2`).
- **Display** — `simpledrm` had to be blacklisted so the real msm DRM (`card0`)
  is the one HWC composes onto.
- **GPU firmware** — a660 SQE/GMU must be uncompressed in `/vendor/firmware`.
- **WiFi** — GloDroid is intentionally no-vendor-HAL; the only gap was a
  build flag (`GD_NO_DEFAULT_WIFI`) that dropped `wpa_supplicant`. The AIC
  fullmac driver creates `wlan0` on demand. Firmware loads from `/metadata`
  (the driver uses `filp_open`, so it must survive `switch_root`).

## License & attribution

Repository contributions: **Apache-2.0** (`LICENSE`). Prebuilt kernel/modules are
**GPL-2.0** (RadxaOS); GPU and WiFi/BT firmware are proprietary-redistributable
vendor blobs. Full attribution and the kernel source offer are in `NOTICE`.

This is an independent, unofficial project, not affiliated with or endorsed by
Google, Radxa, Qualcomm, or AICSemi.
