# PROGRESS — natywny Android na Radxa Dragon Q6A

## Status ogólny
**Faza aktywna:** Faza 1 — Build GloDroid + target dragon_q6a  
**Kabel UART:** ❌ Nie dotarł jeszcze (zamówiony ~2026-05-22, ~3 dni)

---

## 2026-05-22 — Inicjalizacja projektu, weryfikacja środowiska

### Środowisko build (WSL2)
| Check | Wynik | OK? |
|-------|-------|-----|
| Ścieżka | `/home/huber/q6a/project` (natywny FS) | ✅ |
| Wolne miejsce | 953 GB / 1007 GB | ✅ |
| RAM w WSL2 | **~25 GB + 12 GB swap** (podbity) | ✅ |
| CPU | 16 rdzeni | ✅ |
| Sieć | github.com OK | ✅ |

---

## 2026-05-22 — Faza 0: Rekonesans zakończony ✅

### Zebrane dane z Radxa OS na Q6A
- dmesg (boot + GPU/display)
- lsblk / layout partycji
- zawartość /boot/efi (systemd-boot + pliki kernela)
- konfiguracja kernela (zcat /proc/config.gz)
- vulkaninfo (Turnip potwierdzony)
- extlinux.conf + systemd-boot entries

### Kluczowe wyniki

**Boot chain (zweryfikowany):**
Qualcomm UEFI v2.7 (SPI) → **systemd-boot** (BOOTAA64.EFI, 909 KB) → kernel + DTB z partycji ESP

- Bootloader to **systemd-boot**, nie U-Boot. extlinux.conf = legacy fallback.
- Kernel, DTB i initrd są w partycji EFI (FAT32, 1 GB).
- DTB: `qcs6490-radxa-dragon-q6a.dtb` (184 KB) dostępny bezpośrednio w ESP.

**Kernel 6.18.2-4-qcom:** Binder, Sync, DMA-BUF Heaps, DRM_MSM — wszystko wbudowane. Gotowy do Androida bez rekompilacji (bring-up).

**GPU:** Turnip Adreno 643, Vulkan 1.3.275 — działa. Firmware: `a660_sqe.fw` + `a660_gmu.bin`.

**Display:** DPU 7.2 → DP kontroler → QMP PHY → hdmi-bridge → HDMI typ A. card0=simpledrm (EFI fb), card1=msm_drm (właściwy DRM).

**DoD Fazy 0:** ✅ ARCHITECTURE.md napisany z jasną decyzją boot flow opartą na realnych danych.

### TBD z Fazy 0 — ZAMKNIĘTE 2026-05-25
- [x] `loader.conf` — `timeout 3` (prostota)
- [x] `RadxaOS-6.18.2-4-qcom.conf` — pełny wpis z UUID, cmdline, ścieżkami
- [x] DTB binarny — zdekompilowany, analiza zakończona (patrz 2026-05-25)

### Następny krok
**Faza 1:** przygotowanie środowiska build GloDroid + szkielet target `dragon_q6a`.

---

## 2026-05-22 — Faza 1: start (przerwane)

### Wykonano
- Zainstalowano zależności: `ccache 4.5.1`, `device-tree-compiler 1.6.1`, `openjdk-11-jdk 11.0.30`
- Zainstalowano `repo launcher v2.54` w `~/.local/bin/`
- Ustalono właściwy branch GloDroid: `master` (Android 13.0.0_r11); branch `android-13.0.0` nie istnieje
- Utworzono `~/q6a/glodroid/`

### Zablokowane — brakujący git config
`repo init` wymaga tożsamości git. Nie wykonano.

### Następna sesja — 3 kroki w tej kolejności

**Krok 1 — git config (30 sekund):**
```bash
git config --global user.email "jerszjerszjersz@proton.me"
git config --global user.name "Huber"
```

**Krok 2 — repo init + sync (uruchom w screen, trwa 3-8 h):**
```bash
cd ~/q6a/glodroid
repo init -u https://github.com/GloDroid/glodroid_manifest -b master --depth=1
# po sukcesie:
screen -S sync
repo sync -c -j8 --no-tags --no-clone-bundle
# Ctrl+A, D żeby odłączyć
```

**Krok 3 — pliki z Q6A (pendrive lub cat w terminalu):**
- `sudo cat /boot/efi/loader/loader.conf`
- `sudo cat /boot/efi/loader/entries/RadxaOS-6.18.2-4-qcom.conf`
- DTB binarny: `/boot/efi/RadxaOS/6.18.2-4-qcom/qcs6490-radxa-dragon-q6a.dtb` (184 KB)
- GPU firmware: `find /usr/lib/firmware /lib/firmware -name "a660*"` → skopiować oba pliki
- Kernel config: `/boot/config-6.18.2-4-qcom`

---

## 2026-05-23 — Faza 1: repo sync + git config

### Wykonano (przez użytkownika między sesjami)
- `git config --global` ustawiony (email + name)
- `repo init -u https://github.com/GloDroid/glodroid_manifest -b master --depth=1` OK
- `repo sync` zakończony — **136 GB** w `~/q6a/glodroid/`
- Pełne drzewo AOSP + GloDroid gotowe

---

## 2026-05-25 — Faza 1: analiza DTB + utworzenie targetu dragon_q6a

### Pliki z Q6A — odebrane i zweryfikowane

| Plik | Status |
|------|--------|
| `qcs6490-radxa-dragon-q6a.dtb` (184 388 B, świeży) | ✅ główny DTB |
| `a660_gmu.bin` (54 KB) | ✅ GPU GMU firmware |
| `a660_sqe.fw.zst` (18 KB) | ✅ GPU SQE firmware (skompresowany) |
| `a660_zap.mbn` (1.1 MB) + `.zst` (2.4 KB) | ⚠️ mamy oba, do weryfikacji po zainstalowaniu zstd |
| `config-6.18.2-4-qcom` (324 KB) | ✅ kernel config |
| `loader.conf` | ✅ systemd-boot: timeout 3 |
| `RadxaOS-6.18.2-4-qcom.conf` | ✅ wpis boot entry z cmdline |
| `dragon_q6a.dtb` (185 007 B, 13 maja) | ❌ ignorowany — zmodyfikowany z poprzedniego eksperymentu |

### Wyniki analizy DTB

**HDMI bridge zidentyfikowany:** `compatible = "radxa,ra620"` — Radxa RA620 (DP→HDMI converter)

**Display pipeline (zweryfikowany z DTB):**
```
DPU (sc7280-dpu, ae01000, port@2)
  → DP controller (sc7280-dp, ae90000, status=okay)
    → QMP PHY (data-lanes 0,1)
      → Radxa RA620 (hdmi-bridge)
        → HDMI connector typ A
DSI (ae94000): disabled
eDP (aea0000): disabled
```

**GPU (zweryfikowany z DTB):**
- `compatible = "qcom,adreno-635.0"`
- Firmware: `qcom/qcs6490/a660_zap.mbn` (uwaga: podkatalog `qcs6490/`!)
- OPP: 315 MHz → 900 MHz (9 poziomów)
- GMU: `qcom,adreno-gmu-635.0`

**MMC:**
- sdhc_1 = `mmc@7c4000` (eMMC, hs400+enhanced strobe)
- sdhc_2 = `mmc@8804000` (SD card)
- `androidboot.boot_devices=platform/soc@0/8804000.mmc`

**Kernel config — kluczowe ustalenia:**
- SELinux: `CONFIG_SECURITY_SELINUX=y` ale **NIE w CONFIG_LSM** (domyślnie bpf,yama,integrity...)
  → rozwiązanie: `lsm=...,selinux,...` w cmdline + `selinux=1`
- `BOOTPARAM=y` → selinux aktywowany przez cmdline
- F2FS=m, FUSE=m, LOOP=m, DM=m, SQUASHFS=m — moduły, nie built-in

### Target `device/glodroid/dragon_q6a` — UTWORZONY

Pliki targetu:
```
device/glodroid/dragon_q6a/
├── Android.mk              — kopiuje prebuilt kernel do $(PRODUCT_OUT)/kernel
├── AndroidProducts.mk      — rejestruje dragon_q6a-userdebug
├── BoardConfig.mk          — GPU freedreno, KERNEL_BASE=0x80000000, SELinux cmdline
├── device.mk               — firmware GPU, Vulkan, Ethernet, no_suspend
├── dragon_q6a.mk           — product: arch, platform=qualcomm, prebuilt kernel
├── esp/                     — szablon partycji ESP dla systemd-boot
│   ├── loader/loader.conf
│   ├── loader/entries/android.conf
│   └── Android/             (tu trafi kernel Image + DTB + ramdisk)
├── firmware/                — GPU firmware (a660_*)
├── gensdimg-uefi.sh         — skrypt generujący obraz SD z ESP + Android partitions
└── prebuilt/
    ├── Image                — ⚠️ DUMMY (64 KB) — potrzebny prawdziwy z Q6A!
    └── qcs6490-radxa-dragon-q6a.dtb  ✅
```

### Testy buildu
- `lunch dragon_q6a-userdebug` ✅ — target rozpoznany
- `make fstab` ✅ — fstab.dragon_q6a wygenerowany poprawnie
- `make vulkan.freedreno` ❌ — wymaga `meson` (zainstalowany pip3 --user, wymaga symlink do /usr/local/bin)

### BLOKERY

1. **`meson` nie w PATH buildu** — GloDroid AOSPEXT ustawia `PATH=/usr/bin:/bin:/sbin`, pomijając `~/.local/bin`.
   Fix: `sudo ln -sf /home/huber/.local/bin/meson /usr/local/bin/meson`

2. **Brak prawdziwego kernela Image** — dummy 64 KB, potrzebny prawdziwy z Q6A:
   ```bash
   # Na Q6A:
   sudo cp /boot/efi/RadxaOS/6.18.2-4-qcom/linux /media/pendrive/Image
   ```
   Plik ~36 MB (skompresowany) lub ~64 MB (nieskompresowany).

3. **`zstd` nie zainstalowany** — potrzebny do weryfikacji firmware.
   Fix: `sudo apt install -y zstd`

### Następne kroki (po odblokowaniu)

1. Zainstalować meson + zstd (sudo)
2. Dostarczyć kernel Image z Q6A
3. Uruchomić pełny `make droid -j16` (szacowany czas: 2-4h)
4. Po buildzie: złożyć obraz SD z gensdimg-uefi.sh
5. **Faza 2:** flash SD → pierwszy boot

---

## 2026-05-26 — Faza 1: pierwszy pełny build (przerwany ręcznie)

### Wykonano
- Blokery z poprzedniej sesji rozwiązane: meson symlink ✅, zstd ✅, kernel Image 62 MB ✅
- Uruchomiono `make droid -j8` (`-j8` ze względu na temperaturę CPU >99°C przy wyższych wartościach)
- Build dotarł do **~74%** (73417/98179 zadań, czas: ~1h3m)
- Zatrzymany **ręcznie przez użytkownika** (było późno) — brak błędów, stan ninja zachowany

### Stan artefaktów w out/
- `out/target/product/dragon_q6a/` istnieje z częściowymi artefaktami
- Ninja wznowi build od 74% bez ponownej kompilacji

### Następne kroki
1. Wznowić: `cd ~/q6a/glodroid && source build/envsetup.sh && lunch dragon_q6a-userdebug && make droid -j8`
2. Pozostałe ~26% — szacowany czas: ~30-60 min
3. Po buildzie: złożyć obraz SD z `gensdimg-uefi.sh`
4. **Faza 2:** flash SD → pierwszy boot

**Uwaga:** `-j8` to maksimum ze względu na temperaturę CPU. Nie zwiększać.

---
