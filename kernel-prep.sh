#!/bin/bash
# rubenswifi 内核准备工作（在 Linux 上执行）
# 用法：./kernel-prep.sh /path/to/kernel/samsung/msm8226
#
# 作用：
#   1. 由官方 msm8926-sec_rubenslte_defconfig 派生 msm8226-sec_rubenswifi_defconfig
#   2. 把 rubenswifi 的 dtb 加进构建列表
#   3. 校验 DTS 文件是否齐全

set -e
KDIR="${1:?用法: $0 <kernel 源码目录>}"
cd "$KDIR"

echo "==> 1/3 生成 defconfig"
SRC=arch/arm/configs/msm8926-sec_rubenslte_defconfig
DST=arch/arm/configs/msm8226-sec_rubenswifi_defconfig
[ -f "$SRC" ] || { echo "找不到 $SRC"; exit 1; }

cp "$SRC" "$DST"

# 平台从 MSM8926(LTE) 切到 MSM8226(WiFi)
sed -i 's/^CONFIG_ARCH_MSM8926_LTE=y/# CONFIG_ARCH_MSM8926_LTE is not set/' "$DST"
grep -q '^CONFIG_ARCH_MSM8226=y' "$DST" || echo 'CONFIG_ARCH_MSM8226=y' >> "$DST"

# WiFi 版无基带，关掉 modem/电话相关
for opt in CONFIG_MSM_BAM_DMUX CONFIG_RMNET_IPA CONFIG_MSM_RMNET_BAM \
           CONFIG_SEC_MODEM CONFIG_MSM_SMD_TTY CONFIG_USB_GADGET_DIAG; do
    sed -i "s/^${opt}=y/# ${opt} is not set/" "$DST"
done

echo "    → $DST 已生成"

echo "==> 2/3 检查 DTS"
DTS_DIR=arch/arm/boot/dts/msm8226
for f in msm8226-sec-rubenswifieur-r02.dts \
         msm8226-sec-rubenswifieur-r03.dts \
         msm8226-sec-rubenswifieur-r04.dts; do
    if [ -f "$DTS_DIR/$f" ]; then
        echo "    ✓ $f"
    else
        echo "    ✗ 缺失 $f —— 需要从 Samsung-OSS-Kernels 分支 sm-t365_eur_ll_opensource 取回"
    fi
done

echo "==> 3/3 检查 dtb 构建列表"
MK="$DTS_DIR/Makefile"
if [ -f "$MK" ] && ! grep -q 'rubenswifi' "$MK"; then
    cp "$MK" "$MK.bak"
    cat >> "$MK" <<'EOF'

# rubenswifi (SM-T360)
dtb-$(CONFIG_ARCH_MSM8226) += msm8226-sec-rubenswifieur-r02.dtb \
                             msm8226-sec-rubenswifieur-r03.dtb \
                             msm8226-sec-rubenswifieur-r04.dtb
EOF
    echo "    → 已追加 dtb 条目（备份 $MK.bak）"
else
    echo "    跳过（Makefile 不存在或已包含）"
fi

echo
echo "完成。接着执行："
echo "  make ARCH=arm msm8226-sec_rubenswifi_defconfig"
echo "  make ARCH=arm CROSS_COMPILE=arm-linux-androideabi- -j\$(nproc)"
