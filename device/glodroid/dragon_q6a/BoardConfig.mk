# SPDX-License-Identifier: Apache-2.0
#
# Board config for Radxa Dragon Q6A (QCS6490, UEFI boot)

# Disable subsystems not present or deferred on Q6A.
# WiFi (AIC8800D80 on USB, fullmac cfg80211) re-enabled 2026-06-11: kernel driver
# verified up to ieee80211 phy0; this gate was silently dropping wpa_supplicant
# (board.mk sets WPA_SUPPLICANT_VERSION — without it the module doesn't exist).
# Bluetooth re-enabled 2026-06-13: AIC8800D80 BT = standard USB transport, hci0
# confirmed live (HCIDEVUP ok, BD_ADDR f4:ab:5c:..); RT abort-loop disarmed via
# rt_group_sched=0 cmdline. Pulls in bluetooth/board.mk (manifest + sepolicy).
GD_NO_DEFAULT_CAMERA := true
GD_NO_DEFAULT_MODEM := true

include device/glodroid/common/board-common.mk

# GPU — Mesa Freedreno (Turnip Vulkan, Freedreno GLES)
BOARD_MESA3D_GALLIUM_DRIVERS := freedreno
BOARD_MESA3D_VULKAN_DRIVERS := freedreno

# Kernel base address — QCS6490 DRAM starts at 0x80000000
BOARD_KERNEL_BASE := 0x80000000

# Android kernel cmdline (goes into boot.img; also used as reference for systemd-boot entry)
BOARD_KERNEL_CMDLINE += console=ttyMSM0,115200n8 earlycon coherent_pool=2M
# Adreno firmware lives at /vendor/firmware/qcom/ — prebuilt kernel only searches
# /lib/firmware by default, so point the firmware loader at vendor explicitly.
BOARD_KERNEL_CMDLINE += firmware_class.path=/vendor/firmware
BOARD_KERNEL_CMDLINE += irqchip.gicv3_pseudo_nmi=0
BOARD_KERNEL_CMDLINE += selinux=1 androidboot.selinux=permissive
BOARD_KERNEL_CMDLINE += lsm=landlock,lockdown,yama,integrity,selinux,bpf

# DTB for boot.img — use our prebuilt directory
BOARD_PREBUILT_DTBIMAGE_DIR := device/glodroid/dragon_q6a/prebuilt

# Prebuilt kernel — no kernel.mk, no DTBO generation
BOARD_INCLUDE_RECOVERY_DTBO :=
BOARD_PREBUILT_DTBOIMAGE := device/glodroid/platform/kernel/dummy.dtb
