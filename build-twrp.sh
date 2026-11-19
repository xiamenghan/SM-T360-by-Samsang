#!/bin/bash
#
# 在当前目录（即仓库根，同时作为 AOSP 根）内编译 TWRP recovery.img
# 本脚本可在 GitHub Actions 或任意 Ubuntu 20.04/22.04 上运行
#
set -eo pipefail

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

echo "==> 准备内核 defconfig"
# 该内核仓库自带 rubenswifi DTS、dtb 列表与可用的 lineage_* 基底 defconfig
bash ./kernel-prep.sh kernel/samsung/msm8226

# ---------------------------------------------------------------- 3. ramdisk XZ 压缩
echo "==> ramdisk 压缩改为 XZ（recovery 分区 10MB，gzip 版本装不下）"
# AOSP 的 ramdisk 由 MINIGZIP(minigzip) 以 gzip 压缩；换成 xz 可再省 ~2MB。
# 内核侧已开 CONFIG_RD_XZ（kernel-prep.sh），可正常解压 XZ initramfs。
# 用 -6 预设：8MB 字典，内核早期解压内存友好。
mkdir -p tools
cat > tools/minigzip-xz <<'XZEOF'
#!/bin/bash
# 兼容 minigzip 的管道调用方式：mkbootfs ... | minigzip > out.img
exec xz -6 -c "$@"
XZEOF
chmod +x tools/minigzip-xz
GZDEF="$(grep -l '^MINIGZIP := ' build/make/core/config.mk build/core/config.mk 2>/dev/null || true)"
if [ -z "$GZDEF" ]; then
    echo "!! 找不到 MINIGZIP 定义，构建树结构与预期不符，退出以便人工确认"
    exit 1
fi
for f in $GZDEF; do
    sed -i "s|^MINIGZIP := .*|MINIGZIP := $PWD/tools/minigzip-xz|" "$f"
    echo "    已替换 $f"
done
grep -rn '^MINIGZIP := ' build/make/core/config.mk build/core/config.mk 2>/dev/null | sed 's/^/    /'

# ---------------------------------------------------------------- 4. 编译
export ALLOW_MISSING_DEPENDENCIES=true
export LC_ALL=C
export TZ=UTC
export TW_DEVICE_VERSION="${TW_DEVICE_VERSION:-lineage16-port}"

echo "==> envsetup"
set +u
source build/envsetup.sh

echo "==> lunch omni_rubenswifi-eng"
lunch omni_rubenswifi-eng

echo "==> 开始编译 recoveryimage"
mka recoveryimage -j"$JOBS"

OUT="out/target/product/rubenswifi"
echo
echo "==> 产物："
ls -lh "$OUT"/recovery.img 2>/dev/null || { echo "未找到 recovery.img，编译失败"; exit 1; }
