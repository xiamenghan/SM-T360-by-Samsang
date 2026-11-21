#
# TWRP 产品定义（配合 minimal-manifest-twrp/platform_manifest_twrp_omni）
#
# 单独成文件而不是复用 lineage_rubenswifi.mk，因为 TWRP 最小 manifest
# 不含 LineageOS 的 vendor/lineage 与 msm8226-common，需要自包含
#

# 最小系统基础模块：recoveryimage 的 baseline ramdisk 依赖这里安装 init/recovery。
# 缺少此继承会编译出没有 /init 和 /sbin/recovery 的不可启动镜像。
$(call inherit-product, $(SRC_TARGET_DIR)/product/embedded.mk)

# TWRP 基座：9.0 manifest 在 vendor/omni，8.1 manifest 可能在 vendor/twrp
ifneq ($(wildcard vendor/omni/config/common.mk),)
$(call inherit-product, vendor/omni/config/common.mk)
else ifneq ($(wildcard vendor/twrp/config/common.mk),)
$(call inherit-product, vendor/twrp/config/common.mk)
endif

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
    device/samsung/rubenswifi/idc/touch.idc:recovery/root/system/usr/idc/touch.idc \
    device/samsung/rubenswifi/recovery/root/init.recovery.qcom.rc:recovery/root/init.recovery.qcom.rc
