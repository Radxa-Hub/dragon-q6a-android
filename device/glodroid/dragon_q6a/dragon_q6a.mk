# SPDX-License-Identifier: Apache-2.0
#
# Radxa Dragon Q6A — Android 13 target for GloDroid
# SoC: QCS6490, GPU: Adreno 643 (Turnip), Boot: UEFI/systemd-boot from SD

# Architecture — QCS6490 is Kryo 670 (A78 + A55)
TARGET_ARCH := arm64
TARGET_ARCH_VARIANT := armv8-2a
TARGET_CPU_ABI := arm64-v8a
TARGET_CPU_ABI2 :=
TARGET_CPU_VARIANT := kryo385

TARGET_2ND_ARCH := arm
TARGET_2ND_ARCH_VARIANT := armv8-2a
TARGET_2ND_CPU_ABI := armeabi-v7a
TARGET_2ND_CPU_ABI2 := armeabi
TARGET_2ND_CPU_VARIANT := cortex-a55

PRODUCT_BOARD_PLATFORM := qualcomm
PRODUCT_NAME := dragon_q6a
PRODUCT_DEVICE := dragon_q6a
PRODUCT_BRAND := Radxa
PRODUCT_MODEL := DragonQ6A
PRODUCT_MANUFACTURER := Radxa

# Prebuilt kernel from Radxa OS 6.18.2-4-qcom — skip GloDroid kernel build
TARGET_PREBUILT_KERNEL := device/glodroid/dragon_q6a/prebuilt/Image

KERNEL_DTB_FILE := qcom/qcs6490-radxa-dragon-q6a.dtb

# MMC sysfs paths — sdhc_1 = eMMC (7c4000), sdhc_2 = SD card (8804000)
SYSFS_MMC0_PATH := soc@0/7c4000.mmc
SYSFS_MMC1_PATH := soc@0/8804000.mmc

$(call inherit-product, device/glodroid/dragon_q6a/device.mk)
