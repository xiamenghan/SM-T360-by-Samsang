#!/bin/bash
#
# 从本地 blobs 目录提取专有文件到 vendor/samsung/rubenswifi/proprietary/
# 与标准 LineageOS extract-files.sh 的区别：不需要连接设备，直接用已 dump 的 blobs
#
# 用法：
#   ./extract-files.sh                # 默认从 ./blobs 取
#   ./extract-files.sh /path/to/blobs
#
set -euo pipefail

VENDOR="${VENDOR:-vendor/samsung/rubenswifi}"
BLOBS="${1:-${BLOBS:-blobs}}"
FILES="device/samsung/rubenswifi/proprietary-files.txt"

[ -f "$FILES" ] || { echo "错误：找不到 $FILES（请在 Android 源码根目录执行）"; exit 1; }
[ -d "$BLOBS/system" ] || { echo "错误：找不到 blobs 目录 $BLOBS/system"; exit 1; }

echo "==> blobs 来源: $BLOBS"
echo "==> 输出目录  : $VENDOR/proprietary"

copied=0
missing=0

while IFS= read -r line; do
    # 去掉 CR、BOM，跳过空行与注释
    line="${line%$'\r'}"
    line="${line#$'\xef\xbb\xbf'}"
    [ -z "$line" ] && continue
    case "$line" in \#*) continue ;; esac

    # 兼容 <路径>|<附加信息> 写法
    src_rel="${line%%|*}"
    # 去掉 /system/ 前缀
    src_rel="${src_rel#/system/}"

    src="$BLOBS/system/$src_rel"
    dst="$VENDOR/proprietary/$src_rel"

    if [ -f "$src" ]; then
        mkdir -p "$(dirname "$dst")"
        cp -f "$src" "$dst"
        copied=$((copied + 1))
    else
        echo "  缺少: /system/$src_rel"
        missing=$((missing + 1))
    fi
done < "$FILES"

echo "==> 完成：复制 $copied 个，缺失 $missing 个"
if [ -d "$VENDOR/proprietary" ]; then
    du -sh "$VENDOR/proprietary"
fi

if [ "$missing" -gt 0 ]; then
    echo
    echo "提示：缺失项通常是需要 root 才能读取的文件（如 /system/etc/firmware/wcd9306/*.bin）。"
    echo "      先用 CF-Auto-Root 或自建 TWRP 取得 root，补 dump 后重跑本脚本。"
fi

echo
echo "下一步：./setup-makefiles.sh"
