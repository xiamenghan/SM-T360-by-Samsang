#!/bin/bash
#
# 在当前目录（即仓库根，同时作为 AOSP 根）内编译 TWRP recovery.img
# 本脚本可在 GitHub Actions 或任意 Ubuntu 20.04/22.04 上运行
#
set -euo pipefail

MANIFEST="https://github.com/minimal-manifest-twrp/platform_manifest_twrp_omni.git"
TWRP_BRANCH="${TWRP_BRANCH:-twrp-9.0}"
KERNEL_REPO="https://github.com/LineageOS/android_kernel_samsung_msm8226.git"
KERNEL_BRANCH="${KERNEL_BRANCH:-lineage-16.0}"

JOBS="$(nproc)"
echo "==> 并行任务数: $JOBS"

# ---------------------------------------------------------------- 1. 同步源码
if [ ! -d .repo ]; then
    echo "==> 初始化 minimal manifest ($TWRP_BRANCH)"
    git config --global user.name  >/dev/null 2>&1 || git config --global user.name  "twrp-builder"
    git config --global user.email >/dev/null 2>&1 || git config --global user.email "builder@localhost"
    repo init --depth=1 -u "$MANIFEST" -b "$TWRP_BRANCH"
fi

echo "==> repo sync"
repo sync -j"$JOBS" --force-sync --no-clone-bundle --no-tags --quiet

# ---------------------------------------------------------------- 2. 内核
if [ ! -d kernel/samsung/msm8226/.git ]; then
    echo "==> 拉取内核 $KERNEL_BRANCH"
    git clone --depth=1 -b "$KERNEL_BRANCH" "$KERNEL_REPO" kernel/samsung/msm8226
fi

echo "==> 准备内核 defconfig 与 dtb 列表"
# 社区内核若缺 rubenswifi 的 DTS 或 rubenslte defconfig，从三星官方 OSS 源码补齐
STOCK_ZIP="kernel-src/kernel-stock-3.4.zip"
STOCK_URL="https://codeload.github.com/Samsung-OSS-Kernels/android_kernel_samsung_msm8226/zip/refs/heads/sm-t365_eur_ll_opensource"
NEED_STOCK=0
[ ! -f kernel/samsung/msm8226/arch/arm/boot/dts/msm8226/msm8226-sec-rubenswifieur-r02.dts ] && NEED_STOCK=1
[ ! -f kernel/samsung/msm8226/arch/arm/configs/msm8926-sec_rubenslte_defconfig ] && NEED_STOCK=1
if [ "$NEED_STOCK" = "1" ]; then
    echo "    社区内核缺少 rubenswifi DTS 或 rubenslte defconfig，拉取三星官方源码补齐"
    mkdir -p kernel-src
    if [ ! -f "$STOCK_ZIP" ]; then
        curl -L --retry 3 -o "$STOCK_ZIP" "$STOCK_URL"
    fi
    tmpd="$(mktemp -d)"
    unzip -q "$STOCK_ZIP" -d "$tmpd"
    src="$(find "$tmpd" -maxdepth 1 -type d -name 'android_kernel*' | head -1)"
    cp -n "$src"/arch/arm/boot/dts/msm8226/*rubens* \
          kernel/samsung/msm8226/arch/arm/boot/dts/msm8226/ 2>/dev/null || true
    cp -n "$src"/arch/arm/boot/dts/msm8226/dsi_panel_sdc_wxga* \
          kernel/samsung/msm8226/arch/arm/boot/dts/msm8226/ 2>/dev/null || true
    cp -n "$src"/arch/arm/configs/msm8926-sec_rubenslte_defconfig \
          kernel/samsung/msm8226/arch/arm/configs/ 2>/dev/null || true
    rm -rf "$tmpd"
fi
bash ./kernel-prep.sh kernel/samsung/msm8226

# ---------------------------------------------------------------- 3. 编译
export ALLOW_MISSING_DEPENDENCIES=true
export LC_ALL=C
export TZ=UTC
export TW_DEVICE_VERSION="${TW_DEVICE_VERSION:-lineage16-port}"

echo "==> envsetup"
set +u
source build/envsetup.sh
set -u

echo "==> lunch omni_rubenswifi-eng"
lunch omni_rubenswifi-eng

echo "==> 开始编译 recoveryimage"
mka recoveryimage -j"$JOBS"

OUT="out/target/product/rubenswifi"
echo
echo "==> 产物："
ls -lh "$OUT"/recovery.img 2>/dev/null || { echo "未找到 recovery.img，编译失败"; exit 1; }
