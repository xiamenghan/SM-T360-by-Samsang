#!/bin/bash
# rubenswifi (SM-T360) 内核准备工作（在 Linux 上执行）
# 用法：./kernel-prep.sh /path/to/kernel/samsung/msm8226
#
# 作用：
#   1. 由同仓库的 lineage_matissewifi_defconfig（同为 msm8226 三星平板）派生
#      msm8226-sec_rubenswifi_defconfig，切到 RUBENSWIFI 机型/面板/PMIC
#   2. 修补 mdnie 驱动缺失的 rubens 分支
#   3. 校验 rubenswifi 的 DTS 与 dtb 构建列表
#
# 注意：必须用本内核仓库自带的 lineage_* defconfig 作基底。
# 三星官方 3.4 老 defconfig 缺少 CONFIG_ARCH_MSM=y，会导致 mach/ 头文件路径缺失。

set -e
KDIR="${1:?用法: $0 <kernel 源码目录>}"
cd "$KDIR"

enable_opt() {
    local opt="$1" dst="$2"
    sed -i "/^# *${opt} is not set/d" "$dst"
    sed -i "/^${opt}=/d" "$dst"
    echo "${opt}=y" >> "$dst"
}

disable_opt() {
    local opt="$1" dst="$2"
    sed -i "/^${opt}=y/d" "$dst"
    echo "# ${opt} is not set" >> "$dst"
}

echo "==> 1/3 生成 defconfig"
SRC=arch/arm/configs/lineage_matissewifi_defconfig
DST=arch/arm/configs/msm8226-sec_rubenswifi_defconfig
[ -f "$SRC" ] || { echo "找不到 $SRC"; exit 1; }

cp "$SRC" "$DST"

# 关闭 matisse 机型宏
for opt in CONFIG_SEC_MATISSE_PROJECT CONFIG_SEC_MATISSEWIFI_COMMON CONFIG_MACH_MATISSEWIFI_OPEN; do
    disable_opt "$opt" "$DST"
done

# 面板：matisse 用 TC_DSI2LVDS，rubens/millet 用 SDC WXGA。
# LP8556-backlight.c 的 channel_setting_rev1 只在 SDC_WXGA_PANEL + RUBENS_PROJECT 下定义
disable_opt CONFIG_FB_MSM_MDSS_TC_DSI2LVDS_WXGA_PANEL "$DST"
enable_opt  CONFIG_FB_MSM_MDSS_SDC_WXGA_PANEL "$DST"

# 打开 rubenswifi 机型宏（内核 Kconfig / Makefile.boot 已原生支持）
for opt in CONFIG_SEC_RUBENS_PROJECT CONFIG_SEC_RUBENSWIFI_COMMON CONFIG_MACH_RUBENSWIFI_OPEN; do
    enable_opt "$opt" "$DST"
done

# rubens 用 MAX77804K PMIC（DTS 引用 msm8226-max77804k.dtsi），
# IR 遥控驱动引用的 set_led_flash 只在 CONFIG_LEDS_MAX77804K 下编译
enable_opt CONFIG_MFD_MAX77804K "$DST"
enable_opt CONFIG_LEDS_MAX77804K "$DST"
enable_opt CONFIG_MAX77804K_MUIC "$DST"
# MAX77804K_CHGIN_IM 等中断位定义在 max77804k_charger.h，
# 只有开启 CONFIG_CHARGER_MAX77804K 才会被 max77804k.h->sec_charger.h 引入
enable_opt CONFIG_CHARGER_MAX77804K "$DST"

# matisse 用的 SM5502 MUIC / SMB358 充电器与 rubens 的 MAX77804K 方案冲突，必须关掉
disable_opt CONFIG_SM5502_MUIC "$DST"
disable_opt CONFIG_MUIC_SM5502_SUPPORT_LANHUB_TA "$DST"
disable_opt CONFIG_CHARGER_SMB358 "$DST"

# 平台必须存在，否则内核连 mach/ 头文件都找不到
for opt in CONFIG_ARCH_MSM CONFIG_ARCH_MSM8226; do
    grep -q "^${opt}=y" "$DST" || { echo "缺少 ${opt}=y，基底 defconfig 不合适"; exit 1; }
done

echo "    → $DST 已生成"
grep -E "^(CONFIG_ARCH_MSM8226|CONFIG_SEC_RUBENS|CONFIG_MACH_RUBENS|CONFIG_MFD_MAX77804K|CONFIG_LEDS_MAX77804K|CONFIG_FB_MSM_MDSS_SDC_WXGA_PANEL)" "$DST" | sed 's/^/       /'

echo "==> 2/3 修补 mdnie 的 rubens 头文件引用"
# 社区内核的 mdnie 驱动缺 CONFIG_SEC_RUBENS_PROJECT 分支，
# 导致 COLOR_BLIND_1..6 未定义（这些符号在 mdnie_tft_data_rubens.h 中）
MDNIE=drivers/video/msm/mdss/mdnie_tft_msm8x26.c
if grep -q "mdnie_tft_data_rubens.h" "$MDNIE"; then
    echo "    已包含，跳过"
else
    sed -i '/#include "mdnie_tft_data_millet.h"/a #elif defined(CONFIG_SEC_RUBENS_PROJECT)\n#include "mdnie_tft_data_rubens.h"' "$MDNIE"
    echo "    → 已插入 rubens 分支"
fi

echo "==> 3/3 检查 DTS 与 dtb 列表"
DTS_DIR=arch/arm/boot/dts/msm8226
for f in msm8226-sec-rubenswifieur-r02.dts \
         msm8226-sec-rubenswifieur-r03.dts \
         msm8226-sec-rubenswifieur-r04.dts; do
    if [ -f "$DTS_DIR/$f" ]; then
        echo "    ✓ $f"
    else
        echo "    ✗ 缺失 $f"; exit 1
    fi
done

if grep -q "SEC_RUBENSWIFI_COMMON" arch/arm/mach-msm/Makefile.boot; then
    echo "    ✓ Makefile.boot 已含 rubenswifi dtb 列表"
else
    echo "    ✗ Makefile.boot 缺少 rubenswifi dtb 列表"; exit 1
fi

echo
echo "完成。"
