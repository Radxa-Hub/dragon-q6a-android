# SPDX-License-Identifier: Apache-2.0
#
# Device makefile for Radxa Dragon Q6A

# Q6A has no camera HAL. The default GloDroid camera-provider crashes in a loop
# (camera: "Could not load camera HAL module: -2" + "must be in VINTF manifest"),
# which trips system_server RescueParty -> reboot,recovery before boot completes.
# This flag must ALSO be set here (PRODUCT config) BEFORE inheriting
# device-common.mk, or its gate still pulls the HAL PRODUCT_PACKAGES in.
GD_NO_DEFAULT_CAMERA := true

# Bluetooth IS enabled. It was previously disabled because com.android.bluetooth
# abort-looped on timer_create(CLOCK_BOOTTIME_ALARM)/SCHED_FIFO EPERM caused by
# CONFIG_RT_GROUP_SCHED=y in the prebuilt kernel -> RescueParty reboot. That mine
# is now disarmed by rt_group_sched=0 on the kernel cmdline (v35+). The AIC8800D80
# BT is a standard USB transport (iface e0/01/01); bluetooth.ko + aic_btusb_usb.ko
# in the ramdisk bring up hci0 (BD_ADDR confirmed live via HCIDEVUP), and GloDroid's
# btlinux HAL (android.hardware.bluetooth@1.1-service.btlinux) drives it.

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

# UI density. This also selects the navigation model: at 170 a small display is
# treated as a phone form factor and the system draws a 3-button navigation bar;
# on a large display the same value keeps a tablet form factor and navigation is
# provided by the taskbar. Either way there is always an on-screen Home/Back/Recents.
GD_LCD_DENSITY := 170

# Ethernet — RTL8111K/r8169 is primary network
PRODUCT_COPY_FILES += \
    frameworks/native/data/etc/android.hardware.ethernet.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.ethernet.xml \

# Disable suspend — no battery, always-on SBC
PRODUCT_COPY_FILES += \
    device/glodroid/common/no_suspend.rc:$(TARGET_COPY_OUT_VENDOR)/etc/init/no_suspend.dragon_q6a.rc \

# Touchscreen IDC — the WaveShare WS170120 USB panel (Vendor 0eef Product 0005)
# reports ABS_X/ABS_Y + BTN_TOUCH but no INPUT_PROP_DIRECT, so Android defaults it
# to POINTER mode (a mouse cursor that cannot tap). This IDC forces
# touch.deviceType=touchScreen -> DIRECT mode, real absolute touch.
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/idc/Vendor_0eef_Product_0005.idc:$(TARGET_COPY_OUT_VENDOR)/usr/idc/Vendor_0eef_Product_0005.idc \

# adb over TCP — the only adb path on this board: both USB controllers are
# host-only (no peripheral/gadget mode), so adb-by-cable is physically
# impossible. adbd listens on :5555 once a network (WiFi) is up.
PRODUCT_SYSTEM_PROPERTIES += \
    service.adb.tcp.port=5555

# --- UI / cosmetic bring-up (2026-06-14) ---

# Lawnchair = default launcher, baked as a non-privileged system app in /product.
# Launcher3QuickStep stays installed as the recents/overview provider
# (config_recentsComponentName); Lawnchair 14 has no A13 QuickStep build, so it
# provides HOME only. The HOME role is seeded once at boot by the .rc below
# (no clean static-overlay path for the HOME role default holder in A13).
PRODUCT_PACKAGES += \
    Lawnchair

PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/lawnchair-default-home.rc:$(TARGET_COPY_OUT_VENDOR)/etc/init/lawnchair-default-home.rc \

# Health HAL — the Q6A is a wall-powered SBC with no battery, so the stock
# example service reports 0%. This service subclasses it to report full AC power
# and `overrides` the example (single IHealth/default instance).
PRODUCT_PACKAGES += \
    android.hardware.health-service.dragon_q6a

# Orientation base policy — ignore app orientation requests on the panel
# (uniqueId local:0) so apps can't hijack rotation; the user picks rotation from
# the on-screen control (no accelerometer on this board → manual, not auto).
# SettingsProvider defaults (user_rotation=0, accelerometer_rotation=false) are
# already correct.
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/display_settings.xml:$(TARGET_COPY_OUT_VENDOR)/etc/display_settings.xml \

# ScreenRotate — built-in manual rotation control (Quick Settings tile + drawer
# app). Platform-signed so it can call IWindowManager.freezeRotation()
# (SET_ORIENTATION). Lets any user pick orientation from the UI without adb.
PRODUCT_PACKAGES += \
    ScreenRotate
