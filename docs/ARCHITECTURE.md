# ARCHITECTURE.md — Android 13 na Radxa Dragon Q6A (boot z karty SD)

Data: 2026-05-22 | Faza 0 zakończona

---

## Cel

Android 13 (GloDroid / AOSP) uruchamiany z microSD na Radxa Dragon Q6A, z akceleracją GPU 3D przez Mesa Turnip / Adreno 643. Boot wyłącznie z SD — firmware UEFI na SPI pozostaje nienaruszony.

---

## Zweryfikowany sprzęt

| Element | Wartość |
|---------|---------|
| SoC | QCS6490 (pokrewny SC7280), AArch64, EL1 |
| CPU | 4× Cortex-A55 + 4× Cortex-A78, 8 rdzeni |
| RAM | 8 GB |
| GPU | Adreno 643 (a6xx), Mesa Turnip Vulkan 1.3.275 ✅ |
| Storage w Radxa OS | microSD jako jedyny nośnik (mmcblk1) |
| UART debug | ttyMSM0 @ 0x994000, 115200n8, earlycon |
| Kernel Radxa OS | 6.18.2-4-qcom (mainline) |
| EFI | v2.7 by Qualcomm Technologies (SPI) |
| Display output | DPU 7.2 → DP kontroler → QMP PHY → hdmi-bridge → HDMI typ A |

---

## Łańcuch bootowania (zweryfikowany)

```
┌──────────────────────────────────────────────────────────┐
│  Qualcomm UEFI v2.7  (SPI flash — NIENARUSZALNE)         │
│  BIOS: BOOT.MXF.1.0.1-00549-KODIAKWP-1 / 2026-01-20     │
└─────────────────────┬────────────────────────────────────┘
                      │  ładuje BOOTAA64.EFI z ESP
                      ▼
┌──────────────────────────────────────────────────────────┐
│  systemd-boot aa64 (909 KB)                              │
│  /dev/mmcblk1p2 (ESP, 1 GB, FAT32)                       │
│  /boot/efi/EFI/BOOT/BOOTAA64.EFI                         │
│  /boot/efi/loader/loader.conf                            │
│  /boot/efi/loader/entries/*.conf                         │
└─────────────────────┬────────────────────────────────────┘
                      │  czyta wpis z /loader/entries/
                      ▼
┌──────────────────────────────────────────────────────────┐
│  Kernel + DTB + initrd (w ESP)                           │
│  /boot/efi/RadxaOS/6.18.2-4-qcom/linux        (64 MB)   │
│  /boot/efi/RadxaOS/6.18.2-4-qcom/qcs6490-…dtb (184 KB)  │
│  /boot/efi/RadxaOS/6.18.2-4-qcom/initrd.img   (38 MB)   │
└─────────────────────┬────────────────────────────────────┘
                      │
                      ▼
              Linux 6.18.2-4-qcom
              rootfs: mmcblk1p3 (ext4, UUID)
```

**Kluczowa korekta:** `/boot/extlinux/extlinux.conf` (z menu „U-Boot menu") to LEGACY fallback — plik istnieje ale nie jest używany przy starcie. Aktywny bootloader to **systemd-boot**.

---

## Obecny layout SD (Radxa OS)

| Partycja | Rozmiar | FS   | Label  | Mount     | Zawartość |
|----------|---------|------|--------|-----------|-----------|
| mmcblk1p1 | 16 MB  | vfat | config | /config   | DTBO overlays Radxa |
| mmcblk1p2 | 1 GB   | vfat | efi    | /boot/efi | ESP: systemd-boot + kernel + DTB |
| mmcblk1p3 | 237 GB | ext4 | rootfs | /         | Linux rootfs (z /boot wewnątrz) |

---

## Docelowy layout SD dla Android

### Faza 2 (bring-up headless — minimal)

```
mmcblk1p1   16 MB  vfat  esp-small    (zachowany, Radxa config)
mmcblk1p2    1 GB  vfat  esp          systemd-boot + Android kernel + DTB
mmcblk1p3   ~8 GB  ext4  android-root Android rootfs (system + vendor headless)
mmcblk1p4  rest    ext4  userdata     Dane użytkownika
```

### Faza 4 (docelowy — pełny Android)

```
mmcblk1p1   16 MB   vfat   config      (zachowany lub usunięty)
mmcblk1p2    1 GB   vfat   esp         systemd-boot + Android kernel + DTB
mmcblk1p3    8 MB   raw    misc        Android A/B slot metadata
mmcblk1p4    6 GB   ext4   system      Android system (read-only)
mmcblk1p5    2 GB   ext4   vendor      vendor (Turnip blobs, HAL-e)
mmcblk1p6   rest    f2fs   userdata    Dane użytkownika, aplikacje
```

---

## Jak Android wystartuje z SD — decyzja

### Mechanizm boot

1. UEFI ładuje `systemd-bootaa64.efi` z partycji ESP.
2. systemd-boot wyświetla menu (lub autobootuje po timeoucie) i czyta `/loader/entries/android.conf`.
3. Z ESP ładowane są:
   - Android kernel `Image.gz`
   - DTB `qcs6490-radxa-dragon-q6a.dtb` (zmodyfikowany dla Androida)
   - (opcjonalnie) wczesny initrd/ramdisk
4. Kernel startuje, init montuje partycje wg `/etc/fstab.dragon_q6a`.

### Android cmdline (bring-up)

```
console=ttyMSM0,115200n8
earlycon
coherent_pool=2M
irqchip.gicv3_pseudo_nmi=0
androidboot.hardware=dragon_q6a
androidboot.selinux=permissive
androidboot.boot_devices=soc/7c4000.mmc
```

Precyzyjne parametry (fstab, boot_devices) zostaną ustalone po analizie DTB w Fazie 1.

### Wpis systemd-boot dla Androida (`/loader/entries/android.conf`)

```ini
title   Android 13 — Dragon Q6A
linux   /Android/Image.gz
devicetree /Android/qcs6490-radxa-dragon-q6a.dtb
options console=ttyMSM0,115200n8 earlycon androidboot.hardware=dragon_q6a androidboot.selinux=permissive
```

---

## Ocena kernela 6.18.2 pod Android

Kernel Radxa OS jest **prawie gotowy** do użycia z Androidem bez rekompilacji w Fazie 2.

| Wymaganie Androida | Konfiguracja | Status |
|--------------------|-------------|--------|
| Binder IPC | `ANDROID_BINDER_IPC=y` + `BINDERFS=y` | ✅ wbudowany |
| Binder devices | `binder,hwbinder,vndbinder` | ✅ |
| Sync timeline | `SYNC_FILE=y` | ✅ wbudowany |
| DMA-BUF Heaps | `DMABUF_HEAPS=y`, CMA + SYSTEM | ✅ wbudowany |
| MSM DRM | `DRM_MSM=y`, `DRM_MSM_DPU=y`, `DRM_MSM_DP=y` | ✅ wbudowany |
| DSI PHY 7nm | `DRM_MSM_DSI_7NM_PHY=y` | ✅ (QCS6490 = SC7280 family) |
| IOMMU | `QCOM_IOMMU=y` | ✅ |
| EXT4 | `EXT4_FS=y` | ✅ |
| TMPFS | `TMPFS=y` | ✅ |
| Simple DRM (fallback) | `DRM_SIMPLEDRM=y` | ✅ |
| F2FS | `F2FS_FS=m` | ⚠️ moduł — userdata może wymagać `=y` |
| SquashFS | `SQUASHFS=m` | ⚠️ moduł — system partition wymaga `=y` |

**Wniosek:** Do brinigupu wystarczy istniejący kernel. Przed Fazą 3 oceniamy czy potrzeba przebudować z `F2FS=y` i `SQUASHFS=y`.

---

## GPU i wyświetlanie — architektura

### DRM devices

| Device | Driver | DRM minor | Rola |
|--------|--------|-----------|------|
| EFI framebuffer | simpledrm | minor 0 → card0 | Fallback z UEFI, dostępny od startu |
| ae01000.display-controller | msm_drm 1.13 | minor 1 → card1 | Właściwy DRM (DPU 7.2) |
| 3d00000.gpu | adreno (freedreno) | renderD128 | GPU compute/render, Turnip |

### Łańcuch display (HDMI)

```
DPU 7.2 (ae01000)
    └─ DP controller (ae90000)
           └─ QMP PHY (88e8000)  ← shared USB3/DP
                  └─ hdmi-bridge (bridge chip, model TBD)
                         └─ hdmi-connector (HDMI typ A)
```

HDMI wychodzi przez **Radxa RA620** bridge DP→HDMI (`compatible = "radxa,ra620"` w DTB). Nie natywny enkoder HDMI — `DRM_MSM_HDMI=not set` celowo. DSI i eDP disabled w DTB — jedyne aktywne wyjście display to DP→HDMI.

### GPU firmware

```
qcom/qcs6490/a660_sqe.fw   — Adreno 643 SQE microcontroller
qcom/qcs6490/a660_gmu.bin  — GPU Management Unit
qcom/qcs6490/a660_zap.mbn  — ZAP shader (microcode ELF, DSP6)
```

**Uwaga:** DTB określa ścieżkę firmware jako `qcom/qcs6490/a660_zap.mbn` — z podkatalogiem `qcs6490/`.
Firmware musi być dostępny w Android `/vendor/firmware/qcom/qcs6490/`. Skopiowany z Radxa OS.

### Ścieżka GPU w Androidzie

```
Android HAL (Vulkan/GLES)
    └─ Mesa Turnip (libvulkan_freedreno.so)
           └─ DRM render node: /dev/dri/renderD128
                  └─ adreno 3d00000.gpu (msm kernel driver)

Android SurfaceFlinger
    └─ drm_hwcomposer (HWC2)
           └─ DRM KMS: /dev/dri/card1
                  └─ msm_drm DPU → DP → hdmi-bridge → HDMI
```

---

## Źródło bazowe — GloDroid

Baza: `github.com/GloDroid/glodroid_manifest`
Nowy target: `device/glodroid/dragon_q6a`

Wzorzec integracji Qualcomm: `GloDroidCommunity/qcom-msm8916-series` (inna architektura, ale ten sam glue HWC/gralloc/DRM).

Kernel: używamy mainline linux 6.18 (lub GloDroid's AOSPEXT mechanism dla external kernel) z DTB `qcs6490-radxa-dragon-q6a`.

---

## Ograniczenia i ryzyka

| Ryzyko | Poziom | Mitygacja |
|--------|--------|-----------|
| DPU→HDMI przez bridge — inicjalizacja | Średni | Analiza DTB, wzorce z Fairphone 5 / SC7280 upstream |
| GPU firmware dostępność w Android vendor | Niski | Kopiujemy z Radxa OS lub FlatBuild |
| F2FS/SquashFS jako moduł (nie built-in) | Niski | Bring-up z ext4; rebuild kernela przed Fazą 4 |
| Brak kabla UART | Średni | Fazy 0-1 nie wymagają; Faza 2 Tryb B (ADB/Ethernet) |
| gpu_cc sync_state timeout (23s) | Niski | Znany issue SC7280, nie blokuje działania GPU |
| WiFi (AIC8800) | Celowo pominięty | Sieć = Ethernet (r8169) |

---

## Następny krok — Faza 1

1. Zainstaluj zależności AOSP/GloDroid na WSL2 (Ubuntu 22.04).
2. `repo init` GloDroid manifest.
3. Utwórz szkielet `device/glodroid/dragon_q6a`.
4. Wkomponuj kernel 6.18 + DTB `qcs6490-radxa-dragon-q6a` do build flow.

Przed startem Fazy 1: potrzebujemy DTB binarny z Q6A do lokalnej analizy węzłów (patrz sekcja „TBD" poniżej).

---

## Zamknięte TBD (rozwiązane 2026-05-25)

- [x] `loader.conf`: `timeout 3`
- [x] `RadxaOS-6.18.2-4-qcom.conf`: pełny wpis — kernel, initrd, DTB, cmdline z UUID root, earlycon, cgroups
- [x] DTB zdekompilowany i przeanalizowany (8774 linii DTS)
- [x] Bridge chip: **Radxa RA620** (`compatible = "radxa,ra620"`)
- [x] GPU firmware path: `qcom/qcs6490/a660_zap.mbn`
- [x] SELinux: wbudowany ale nie w LSM list → aktywacja przez cmdline
