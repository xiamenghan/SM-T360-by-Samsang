#
# TWRP 产品定义（配合 minimal-manifest-twrp/platform_manifest_twrp_omni）
#
# 单独成文件而不是复用 lineage_rubenswifi.mk，因为 TWRP 最小 manifest
# 不含 LineageOS 的 vendor/lineage 与 msm8226-common，需要自包含
#

$(call inherit-product, vendor/omni/config/common.mk)

# 专有文件（若已放置 vendor/samsung/rubenswifi）
$(call inherit-product-if-exists, vendor/samsung/rubenswifi/rubenswifi-vendor.mk)

PRODUCT_NAME := omni_rubenswifi
PRODUCT_DEVICE := rubenswifi
PRODUCT_BRAND := samsung
PRODUCT_MODEL := SM-T360
PRODUCT_MANUFACTURER := samsung
PRODUCT_CHARACTERISTICS := tablet

# 按键与触摸配置
PRODUCT_COPY_FILES += \
    device/samsung/rubenswifi/keylayout/gpio-keys.kl:recovery/root/system/usr/keylayout/gpio-keys.kl \
    device/samsung/rubenswifi/idc/touch.idc:recovery/root/system/usr/idc/touch.idc
