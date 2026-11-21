#
# Copyright (C) 2026 The LineageOS Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#

DEVICE_PATH := device/samsung/rubenswifi

# 机型断言
TARGET_OTA_ASSERT_DEVICE := rubenswifi,rubens,rubenswifixx

# ---------------------------------------------------------------- 平台
# 若存在 msm8226-common 则继承（完整 ROM 构建时）；
# 若不存在（TWRP 最小 manifest），用下面的自包含配置
ifneq ($(wildcard device/samsung/msm8226-common/BoardConfigCommon.mk),)
include device/samsung/msm8226-common/BoardConfigCommon.mk
else
TARGET_BOARD_PLATFORM := msm8226
TARGET_BOARD_PLATFORM_GPU := qcom-adreno305
TARGET_BOOTLOADER_BOARD_NAME := msm8226

TARGET_ARCH := arm
TARGET_ARCH_VARIANT := armv7-a-neon
TARGET_CPU_ABI := armeabi-v7a
TARGET_CPU_ABI2 := armeabi
TARGET_CPU_VARIANT := cortex-a7
TARGET_CPU_SMP := true
TARGET_USES_ION := true
TARGET_USES_QCOM_BSP := true
BOARD_USES_ALSA_AUDIO := true
BOARD_USES_QCOM_HARDWARE := true

# 图形
USE_OPENGL_RENDERER := true
BOARD_EGL_NEEDS_HANDLE_VALUE := true
TARGET_USES_GRALLOC1 := false
endif

# ---------------------------------------------------------------- 内核
TARGET_KERNEL_CONFIG := msm8226-sec_rubenswifi_defconfig
TARGET_KERNEL_SOURCE := kernel/samsung/msm8226
# msm 3.4 内核产物是 zImage；缺此变量时构建系统会拿 arch/arm/boot/ 目录当文件拷贝
BOARD_KERNEL_IMAGE_NAME := zImage

# 必须与原厂 recovery 的 cmdline 对齐：
#   - lcd_id=0x5e8c10 是 mdss_sdc_wxga_dsi_panel.c 里 __setup("lcd_id=0x") 的开关，
#     缺失时 lcd_attached=0，面板初始化函数全部 early-return，屏幕永远停在开机 logo。
#   - mdss_mdp.panel 指定 rubens 的面板节点（与 dsi_panel_sdc_wxga_video_rubenslte.dtsi 内
#     的节点名一致），否则 mdss 可能选不到面板。
#   - samsung.* / androidboot.boot_recovery 等为三星 LK 与 init 依赖的参数。
BOARD_KERNEL_CMDLINE := console=null androidboot.console=null androidboot.hardware=qcom user_debug=23 \
    lcd_id=0x5e8c10 pmic_info=3 androidboot.debug_level=0x4f4c sec_debug.enable=0 sec_debug.enable_user=0 \
    samsung.hardware=SM-T360 samsung.board_rev=3 androidboot.emmc_checksum=3 \
    androidboot.bootloader=T360XXS1BRI2 androidboot.boot_recovery=1 androidboot.sec_atd.tty=/dev/ttyHSL0 \
    msm_rtb.filter=0x37 ehci-hcd.park=3 androidboot.bootdevice=msm_sdcc.1 \
    mdss_mdp.panel=1:dsi:0:qcom,mdss_dsi_sdc_wxga_video_lte
# mkbootimg 的最终地址 = base + offset。SM-T360 要求 kernel 0x00008000、
# ramdisk 0x02000000、tags 0x01e00000；base 误设为 0x8000 会让全部地址错位。
BOARD_KERNEL_BASE := 0x00000000
BOARD_KERNEL_PAGESIZE := 2048
BOARD_MKBOOTIMG_ARGS := --kernel_offset 0x00008000 --ramdisk_offset 0x02000000 --second_offset 0x00f00000 --tags_offset 0x01e00000
BOARD_KERNEL_SEPARATED_DT := true
BOARD_DTBTOOL_ARGS := -2

# ---------------------------------------------------------------- 分区
# 实测值（/proc/partitions，KB × 1024），勿凭猜测修改
BOARD_BOOTIMAGE_PARTITION_SIZE := 10485760        # p14  boot     10 MB
BOARD_RECOVERYIMAGE_PARTITION_SIZE := 10485760    # p15  recovery 10 MB
BOARD_SYSTEMIMAGE_PARTITION_SIZE := 2411724800    # p23  system 2300 MB
BOARD_CACHEIMAGE_PARTITION_SIZE := 314572800      # p24  cache   300 MB
BOARD_USERDATAIMAGE_PARTITION_SIZE := 12843573248 # p26  userdata 12248 MB

BOARD_CACHEIMAGE_FILE_SYSTEM_TYPE := ext4
BOARD_SYSTEMIMAGE_FILE_SYSTEM_TYPE := ext4
BOARD_USERDATAIMAGE_FILE_SYSTEM_TYPE := ext4
TARGET_USERIMAGES_USE_EXT4 := true
TARGET_USERIMAGES_USE_F2FS := true

BOARD_FLASH_BLOCK_SIZE := 131072
BOARD_HAS_LARGE_FILESYSTEM := true
BOARD_SUPPRESS_SECURE_ERASE := true
COMMON_GLOBAL_CFLAGS += -DNO_SECURE_DISCARD

# ---------------------------------------------------------------- 恢复
TARGET_RECOVERY_FSTAB := $(DEVICE_PATH)/rootdir/etc/fstab.qcom
TARGET_RECOVERY_PIXEL_FORMAT := "RGBX_8888"
TARGET_RECOVERY_DEVICE_DIRS += $(DEVICE_PATH)
BOARD_HAS_NO_SELECT_BUTTON := true
RECOVERY_SDCARD_ON_DATA := true
BOARD_USES_MMCUTILS := true

# ---------------------------------------------------------------- TWRP
TW_THEME := portrait_hdpi
DEVICE_RESOLUTION := 800x1280
# 实测存在的背光节点（LP8556 经 leds 框架暴露）
TW_BRIGHTNESS_PATH := /sys/class/leds/lcd-backlight/brightness
TW_MAX_BRIGHTNESS := 255
TW_DEFAULT_BRIGHTNESS := 160
TW_SCREEN_BLANK_ON_BOOT := true
TW_HAS_DOWNLOAD_MODE := true
TW_NO_REBOOT_BOOTLOADER := true
TW_EXCLUDE_SUPERSU := true
# logcat 会增大 ramdisk（recovery.img 需装进 10MB 分区）
TW_EXCLUDE_TWRPAPP := true
TWRP_INCLUDE_ADDON := false

# recovery 分区只有 10MB，去掉体积大且非必需的组件：
# busybox 全套软链、nano、bash、python3。shell 工具改用 toolbox/toybox。
TW_USE_TOOLBOX := true
TW_EXCLUDE_NANO := true
TW_EXCLUDE_BASH := true
TW_EXCLUDE_PYTHON := true

# ---------------------------------------------------------------- 其他
TARGET_SPECIFIC_HEADER_PATH += $(DEVICE_PATH)/include
