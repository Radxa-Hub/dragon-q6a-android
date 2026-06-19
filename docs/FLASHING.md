# Flashing the SD card

This image boots the Radxa Dragon Q6A entirely from a microSD card. The onboard
SPI firmware (Qualcomm XBL/UEFI) and any eMMC are left untouched, so flashing is
non-destructive to the board and fully reversible — just re-flash or swap the card.

- **Card size:** 8 GB minimum; 16 GB or larger recommended (the data partition is
  grown to fill the card).
- **What you need:** the release asset `dragon_q6a_sd_community.img.zst` and a card
  reader.

---

## Option A — graphical (any OS, easiest)

[balenaEtcher](https://etcher.balena.io/) and the Raspberry Pi Imager both read
`.zst` directly:

1. Select `dragon_q6a_sd_community.img.zst`.
2. Select your SD card.
3. Flash.

That is all the image itself needs to boot. To use the full card capacity for apps
and data, optionally grow the data partition afterwards (see *Grow the data
partition* below); otherwise the system still boots on the as-flashed layout.

---

## Option B — command line (Linux / WSL2 / macOS)

> ⚠️ `dd` writes to a raw block device. **Triple-check the target** — writing to the
> wrong disk destroys it. On Linux/WSL2 use `lsblk` to confirm the card is, e.g.,
> a removable ~239 GB "Storage Device"; on macOS use `diskutil list`.

### 1. Identify the card

```bash
lsblk -do NAME,SIZE,RM,TYPE,MODEL     # the card is the removable (RM=1) device, e.g. /dev/sdX
```

### 2. Wipe the old partition table (recommended)

Clearing any previous GPT — including the **backup GPT** at the end of the card —
avoids a stale partition table that some firmware complains about:

```bash
sudo sgdisk --zap-all /dev/sdX
sudo wipefs -a /dev/sdX
```

### 3. Decompress and write the image

```bash
zstd -d dragon_q6a_sd_community.img.zst -o dragon_q6a_sd_community.img
sudo dd if=dragon_q6a_sd_community.img of=/dev/sdX bs=4M conv=fsync status=progress
sync
```

You can also stream it without keeping the decompressed copy on disk:

```bash
zstd -dc dragon_q6a_sd_community.img.zst | sudo dd of=/dev/sdX bs=4M conv=fsync status=progress
sync
```

### 4. (Recommended) Grow the data partition

The image ships a small `userdata` partition. To use the whole card, move the
backup GPT to the real end of the card and extend partition 13:

```bash
sudo sgdisk -e /dev/sdX            # relocate backup GPT to end of card
sudo growpart /dev/sdX 13          # extend userdata to fill the card
sudo partprobe /dev/sdX
```

Android formats `/data` on first boot, so no manual filesystem resize is needed.

---

## Boot it

1. Eject the card and insert it into the Q6A.
2. Power on and **be patient on the very first boot.** It formats `/data`, runs
   first-boot optimization (dexopt), and **may reboot itself once or twice and sit
   on a black screen or the boot animation for a few minutes — this is normal.**
   Subsequent boots are much faster. Only treat it as a problem if it keeps
   power-cycling for more than ~5 minutes; then capture a UART log (below).

### Optional: watch the boot over UART

Useful if a display does not light up. Connect a **1.8 V** UART adapter (e.g.
CP2102) to UART0 on the 40-pin header (GND=pin6, board-TX=pin8, board-RX=pin10),
open a serial terminal at `115200 8N1`, and power-cycle the board. Reading only the
board's TX line is enough for logging.

---

## Installing to an NVMe SSD (optional)

From the **universal** release onward the **same image boots from either the SD
card or an NVMe SSD** — the kernel cmdline lists both boot devices
(`androidboot.boot_devices=...mmc,...1c08000.pcie`) and the PCIe PHY is baked into
the ramdisk, so `nvme0n1` is ready at first-stage and `/data`/`super` mount from
whichever medium holds the partitions.

- **Slot:** onboard M.2 **M-key 2230**, **PCIe Gen3 ×2** (`1c08000.pcie`).
- Real-world sequential throughput on the reference build: **~1.0 GB/s write,
  ~0.97 GB/s read** (single-stream `dd`; bursts higher).
- The board's **UEFI boots from NVMe**, so once the image is on the SSD it is a
  fully standalone install — the SD card can be removed.

> ⚠️ Writing the image to the SSD **erases everything on it** (including any
> existing Windows/Linux install).

### Method A — USB→M.2 adapter on a PC (recommended)

If you have a USB→M.2 (NVMe) enclosure/adapter, this is identical to flashing an SD
card: plug the SSD into the PC and follow **Option B** above, using the NVMe's
block device as the target (and `sgdisk -e` + `growpart <dev> 13` to grow `/data`
to the full SSD). Then move the SSD into the board's M.2 slot.

### Method B — no adapter, from a board already running this image

You can clone the running image straight onto the SSD from the board itself:

1. Flash the image to an **SD card** (Options A/B above) and boot the board once
   with the **NVMe seated in the M.2 slot**.
2. From a PC on the same network, over `adb` (TCP, `:5555`), stream the image onto
   the SSD:

   ```bash
   adb root
   zstd -dc dragon_q6a_universal_sd_nvme.img.zst \
     | adb shell 'dd of=/dev/block/nvme0n1 bs=4M conv=fsync'
   ```

3. **Grow `/data` to the full SSD.** The on-device `sgdisk` is limited, so the
   simplest path is to grow the partition table later from a PC with a USB→M.2
   adapter (`sgdisk -e` + `growpart … 13`). Without that step the install still
   boots fine — `/data` just uses the as-flashed size until grown.
4. Power off, **remove the SD card**, power on. The board's UEFI falls back to the
   NVMe ESP and boots Android straight from the SSD. (With both an SD and an
   NVMe install present, pick the boot device from the UEFI/systemd-boot menu.)

---

## Troubleshooting

- **No picture on an HDMI monitor** — the image is universal and reads the
  display's EDID. If a particular panel ships a bad/empty EDID, you can supply one:
  put the EDID blob at `Android/edid/<name>.bin` on the ESP (FAT) partition and add
  `drm.edid_firmware=HDMI-A-1:edid/<name>.bin` to the `options` line in
  `loader/entries/android.conf`.
- **Touch acts like a mouse** — the device tree's IDC maps known USB touch panels
  to a touchscreen. For an unlisted panel, add an IDC keyed to its USB VID/PID.
- **Board reboots before any UI** — capture the UART log; a first-stage init abort
  (e.g. an unresolved kernel module) restarts the board before the kernel reaches
  the UI. The log names the failing module/service.
