#
# Copyright (C) 2026 The LineageOS Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#

$(call inherit-product, $(SRC_TARGET_DIR)/product/languages_full.mk)

# msm8226 公共部分
$(call inherit-product, device/samsung/msm8226-common/msm8226.mk)

# 本机配置
$(call inherit-product, device/samsung/rubenswifi/device.mk)

# 覆盖层
DEVICE_PACKAGE_OVERLAYS += device/samsung/rubenswifi/overlay

PRODUCT_NAME := lineage_rubenswifi
PRODUCT_DEVICE := rubenswifi
PRODUCT_BRAND := samsung
PRODUCT_MODEL := SM-T360
PRODUCT_MANUFACTURER := samsung
