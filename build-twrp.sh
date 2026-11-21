#!/bin/bash
#
# 在当前目录（即仓库根，同时作为 AOSP 根）内编译 TWRP recovery.img
# 本脚本可在 GitHub Actions 或任意 Ubuntu 20.04/22.04 上运行
#
set -eo pipefail

MANIFEST="https://github.com/minimal-manifest-twrp/platform_manifest_twrp_omni.git"
# 用 8.1(Oreo)：msm8226 三星平板最成熟的 TWRP 基座，ramdisk 比 9.0 小得多，
# 能直接装进 10MB recovery 分区，无需 xz/砍 dtb 等有启动风险的骚操作
TWRP_BRANCH="${TWRP_BRANCH:-twrp-8.1}"
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
echo "==> ramdisk 压缩改为 XZ（10MB 分区，gzip 装不下）"
# 内核侧已开 CONFIG_RD_XZ（kernel-prep.sh），其解码器用 vmalloc 分配字典，8MB 字典安全。
mkdir -p tools
cat > tools/minigzip-xz <<'XZEOF'
#!/bin/bash
# 兼容 minigzip 的管道调用方式：mkbootfs ... | minigzip > out.img
exec xz -6e -c "$@"
XZEOF
chmod +x tools/minigzip-xz
GZDEF="$(grep -l '^MINIGZIP := ' build/make/core/config.mk build/core/config.mk 2>/dev/null || true)"
if [ -z "$GZDEF" ]; then
    echo "!! 找不到 MINIGZIP 定义，构建树结构与预期不符"
    exit 1
fi
for f in $GZDEF; do
    sed -i "s|^MINIGZIP := .*|MINIGZIP := $PWD/tools/minigzip-xz|" "$f"
    echo "    已替换 $f"
done

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
set +e
mka recoveryimage -j"$JOBS"
BUILD_RC=$?
set -e

OUT="out/target/product/rubenswifi"
echo
echo "==> 尺寸报告（分区上限 10,485,760 字节）"
ls -l "$OUT"/recovery.img "$OUT"/kernel "$OUT"/ramdisk.img "$OUT"/dt.img 2>/dev/null || true
for f in "$OUT"/recovery.img "$OUT"/kernel "$OUT"/ramdisk.img; do
    [ -f "$f" ] && echo "    $(basename $f): $(stat -c%s "$f") 字节"
done

if [ $BUILD_RC -ne 0 ]; then
    echo "!! 编译失败（rc=$BUILD_RC），详见上方输出"
    exit $BUILD_RC
fi

# recoveryimage 在依赖配置不完整时也可能返回成功，必须检查实际启动入口。
RECOVERY_ROOT="$OUT/recovery/root"
MISSING=0
for f in init sbin/recovery sbin/ueventd sbin/twrp sbin/adbd \
         init.recovery.service.rc init.recovery.usb.rc etc/recovery.fstab; do
    if [ ! -e "$RECOVERY_ROOT/$f" ]; then
        echo "!! recovery ramdisk 缺少 $f"
        MISSING=1
    else
        echo "    OK: $f"
    fi
done
if [ $MISSING -ne 0 ]; then
    echo "!! 拒绝生成不含完整启动入口的 recovery 产物"
    exit 1
fi

IMAGE_SIZE=$(stat -c%s "$OUT/recovery.img")
if [ "$IMAGE_SIZE" -gt 10485760 ]; then
    echo "!! recovery.img 为 $IMAGE_SIZE 字节，超过 10,485,760 字节分区上限"
    exit 1
fi

echo
echo "==> 产物："
ls -lh "$OUT"/recovery.img
