# SPDX-License-Identifier: Apache-2.0
#
# Device makefile for Radxa Dragon Q6A

# Q6A has no camera or bluetooth hardware/HAL. The default GloDroid camera-provider
# and btlinux HAL services crash in a loop (camera: "Could not load camera HAL
# module: -2" + "must be in VINTF manifest"), which trips system_server RescueParty
# -> reboot,recovery before boot completes. BoardConfig.mk sets these flags for the
# board/manifest side, but they must ALSO be set here (PRODUCT config) BEFORE
# inheriting device-common.mk, or its gates still pull the HAL PRODUCT_PACKAGES in.
GD_NO_DEFAULT_CAMERA := true
GD_NO_DEFAULT_BLUETOOTH := true

$(call inherit-product, device/glodroid/common/device-common.mk)

# GPU firmware — Adreno 643 (a660 family)
# The msm/adreno driver requests sqe+gmu as "qcom/a660_*.{fw,bin}" (NO soc subdir,
# uncompressed); only the zap shader is referenced via DTB firmware-name
# "qcom/qcs6490/a660_zap.mbn". Installing sqe/gmu under qcs6490/ (and sqe only as
# .zst) made the kernel fail with -2 (ENOENT) -> GPU never inits -> SF crash loop.
# Pair this with firmware_class.path=/vendor/firmware on the kernel cmdline.
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/firmware/a660_sqe.fw:$(TARGET_COPY_OUT_VENDOR)/firmware/qcom/a660_sqe.fw \
    $(LOCAL_PATH)/firmware/a660_gmu.bin:$(TARGET_COPY_OUT_VENDOR)/firmware/qcom/a660_gmu.bin \
    $(LOCAL_PATH)/firmware/a660_zap.mbn:$(TARGET_COPY_OUT_VENDOR)/firmware/qcom/qcs6490/a660_zap.mbn \

# Vulkan — Turnip (freedreno)
PRODUCT_PACKAGES += \
    vulkan.freedreno

PRODUCT_COPY_FILES += \
    frameworks/native/data/etc/android.hardware.vulkan.level-0.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.vulkan.level.xml \
    frameworks/native/data/etc/android.hardware.vulkan.version-1_1.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.vulkan.version.xml \
    frameworks/native/data/etc/android.software.vulkan.deqp.level-2022-03-01.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.software.vulkan.deqp.level.xml \

PRODUCT_VENDOR_PROPERTIES += \
    ro.hardware.vulkan=freedreno \

# OpenGL ES 3.1 (Freedreno/Turnip)
PRODUCT_VENDOR_PROPERTIES += \
    ro.opengles.version=196609

# Shared memory: force memfd for libcutils/FMQ.
# The prebuilt RadxaOS kernel 6.18.2-4-qcom is a mainline build with NO
# CONFIG_ASHMEM (ashmem was dropped from mainline in 5.18). libcutils defaults
# sys.use_memfd=false, which makes it fall back to /dev/ashmem; that device does
# not exist here, so every FMQ ring-buffer allocation fails (mmap -> mReadPtr
# null) and libfmq aborts. That killed SurfaceFlinger's HIDL composer, the audio
# HAL and the BT audio HAL -> reboot loop. Kernel has CONFIG_MEMFD_CREATE=y and
# ro.vndk.version=33 (>=Q) so the memfd path is allowed once this is true.
PRODUCT_VENDOR_PROPERTIES += \
    sys.use_memfd=true

# Display density for HDMI output (external monitor)
GD_LCD_DENSITY := 160

# Ethernet — RTL8111K/r8169 is primary network
PRODUCT_COPY_FILES += \
    frameworks/native/data/etc/android.hardware.ethernet.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.ethernet.xml \

# Disable suspend — no battery, always-on SBC
PRODUCT_COPY_FILES += \
    device/glodroid/common/no_suspend.rc:$(TARGET_COPY_OUT_VENDOR)/etc/init/no_suspend.dragon_q6a.rc \

# adb over TCP — the only adb path on this board: both USB controllers are
# host-only (no peripheral/gadget mode), so adb-by-cable is physically
# impossible. adbd listens on :5555 once a network (WiFi) is up.
PRODUCT_SYSTEM_PROPERTIES += \
    service.adb.tcp.port=5555
