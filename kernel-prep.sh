#!/bin/bash
# rubenswifi (SM-T360) 内核准备工作（在 Linux 上执行）
# 用法：./kernel-prep.sh /path/to/kernel/samsung/msm8226
#
# 作用：
#   1. 由同仓库的 lineage_matissewifi_defconfig（同为 msm8226 三星平板）派生
#      msm8226-sec_rubenswifi_defconfig，并把机型宏切到 RUBENSWIFI
#   2. 校验 rubenswifi 的 DTS 与 dtb 构建列表是否齐全
#
# 注意：必须用本内核仓库自带的 lineage_* defconfig 作基底。
# 三星官方 3.4 老 defconfig 缺少 CONFIG_ARCH_MSM=y，会导致 mach/ 头文件路径缺失，
# 内核编译直接失败（mach/msm_rtb.h: No such file or directory）。

set -e
KDIR="${1:?用法: $0 <kernel 源码目录>}"
cd "$KDIR"

echo "==> 1/2 生成 defconfig"
SRC=arch/arm/configs/lineage_matissewifi_defconfig
DST=arch/arm/configs/msm8226-sec_rubenswifi_defconfig
[ -f "$SRC" ] || { echo "找不到 $SRC"; exit 1; }

cp "$SRC" "$DST"

# 关闭 matisse 机型宏
for opt in CONFIG_SEC_MATISSE_PROJECT CONFIG_SEC_MATISSEWIFI_COMMON CONFIG_MACH_MATISSEWIFI_OPEN; do
    sed -i "s/^${opt}=y/# ${opt} is not set/" "$DST"
done

# 面板：matisse 用 TC_DSI2LVDS，rubens/millet 用 SDC WXGA
# LP8556-backlight.c 里的 channel_setting_rev1 只在 SDC_WXGA_PANEL + RUBENS_PROJECT 下定义
sed -i "s/^CONFIG_FB_MSM_MDSS_TC_DSI2LVDS_WXGA_PANEL=y/# CONFIG_FB_MSM_MDSS_TC_DSI2LVDS_WXGA_PANEL is not set/" "$DST"
sed -i "/^CONFIG_FB_MSM_MDSS_SDC_WXGA_PANEL/d; /^# CONFIG_FB_MSM_MDSS_SDC_WXGA_PANEL is not set/d" "$DST"
echo "CONFIG_FB_MSM_MDSS_SDC_WXGA_PANEL=y" >> "$DST"

# 打开 rubenswifi 机型宏（内核 Kconfig / Makefile.boot 已原生支持）
for opt in CONFIG_SEC_RUBENS_PROJECT CONFIG_SEC_RUBENSWIFI_COMMON CONFIG_MACH_RUBENSWIFI_OPEN; do
    sed -i "/^# *${opt} is not set/d" "$DST"
    sed -i "/^${opt}=/d" "$DST"
    echo "${opt}=y" >> "$DST"
done

# 平台必须存在，否则内核连 mach/ 头文件都找不到
for opt in CONFIG_ARCH_MSM CONFIG_ARCH_MSM8226; do
    grep -q "^${opt}=y" "$DST" || { echo "缺少 ${opt}=y，基底 defconfig 不合适"; exit 1; }
done

echo "    → $DST 已生成"
grep -E "^(CONFIG_ARCH_MSM8226|CONFIG_SEC_RUBENS|CONFIG_MACH_RUBENS)" "$DST" | sed 's/^/       /'

echo "==> 2/2 检查 DTS 与 dtb 列表"
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
