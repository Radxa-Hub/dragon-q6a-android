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
