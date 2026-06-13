# SPDX-License-Identifier: Apache-2.0
#
# Radxa Dragon Q6A — prebuilt kernel handling
#
# GloDroid's kernel.mk is skipped when TARGET_PREBUILT_KERNEL is set.
# We need to provide $(PRODUCT_OUT)/kernel ourselves.

LOCAL_PATH := $(call my-dir)

ifeq ($(TARGET_PRODUCT),dragon_q6a)
ifneq ($(TARGET_PREBUILT_KERNEL),)

$(PRODUCT_OUT)/kernel: $(TARGET_PREBUILT_KERNEL)
	mkdir -p $(dir $@)
	cp $< $@

endif
endif
