#!/bin/bash
#
# 根据 vendor/samsung/rubenswifi/proprietary/ 下实际存在的文件，
# 生成 Android.mk（每个目录一个）以及 rubenswifi-vendor.mk
#
# 用法：在 Android 源码根目录执行 ./setup-makefiles.sh
#
set -euo pipefail

VENDOR="${VENDOR:-vendor/samsung/rubenswifi}"
PROP="$VENDOR/proprietary"

[ -d "$PROP" ] || { echo "错误：$PROP 不存在，请先运行 extract-files.sh"; exit 1; }

echo "==> 清理旧的 Android.mk"
find "$PROP" -name Android.mk -delete
rm -f "$VENDOR/rubenswifi-vendor.mk"

PKGLIST="$(mktemp)"
trap 'rm -f "$PKGLIST"' EXIT
: > "$PKGLIST"

# 按目录遍历（只处理含文件的目录）
while IFS= read -r d; do
    [ "$d" = "." ] && continue
    srcdir="$PROP/$d"
    [ -n "$(find "$srcdir" -maxdepth 1 -type f ! -name Android.mk -print -quit)" ] || continue

    out="$srcdir/Android.mk"
    {
        echo "# 由 setup-makefiles.sh 自动生成，请勿手工修改"
        echo "LOCAL_PATH := \$(call my-dir)"
        echo
    } > "$out"

    for f in "$srcdir"/*; do
        [ -f "$f" ] || continue
        base="$(basename "$f")"
        [ "$base" = "Android.mk" ] && continue

        ext="${base##*.}"
        name="${base%.*}"

        case "$d" in
            bin*)      cls=EXECUTABLES ;;
            app*)      cls=APPS ;;
            vendor/bin*) cls=EXECUTABLES ;;
            *)         case "$ext" in
                           so)  cls=SHARED_LIBRARIES ;;
                           apk) cls=APPS ;;
                           *)   cls=ETC ;;
                       esac ;;
        esac

        case "$cls" in
            SHARED_LIBRARIES)
                case "$d" in
                    vendor/*) modpath='$(TARGET_OUT_VENDOR_SHARED_LIBRARIES)' ;;
                    *)        modpath='$(TARGET_OUT_SHARED_LIBRARIES)' ;;
                esac
                suffix='.so'
                ;;
            EXECUTABLES)
                case "$d" in
                    vendor/bin*) modpath='$(TARGET_OUT_VENDOR_EXECUTABLES)' ;;
                    *)           modpath='$(TARGET_OUT_EXECUTABLES)' ;;
                esac
                suffix=''
                ;;
            APPS)
                case "$d" in
                    vendor/app*) modpath='$(TARGET_OUT_VENDOR_APPS)' ;;
                    *)           modpath='$(TARGET_OUT_APPS)' ;;
                esac
                suffix='.apk'
                ;;
            ETC)
                # 目标路径由源目录决定，而不是固定丢到 /system/etc
                case "$d" in
                    lib)          modpath='$(TARGET_OUT_SHARED_LIBRARIES)' ;;
                    vendor/lib)   modpath='$(TARGET_OUT_VENDOR_SHARED_LIBRARIES)' ;;
                    bin)          modpath='$(TARGET_OUT_EXECUTABLES)' ;;
                    vendor/bin)   modpath='$(TARGET_OUT_VENDOR_EXECUTABLES)' ;;
                    etc)          modpath='$(TARGET_OUT_ETC)' ;;
                    etc/*)        modpath="\$(TARGET_OUT_ETC)/${d#etc/}" ;;
                    *)            modpath="\$(TARGET_OUT)/$d" ;;
                esac
                suffix=''
                ;;
        esac

        {
            echo "include \$(CLEAR_VARS)"
            echo "LOCAL_MODULE := $name"
            echo "LOCAL_MODULE_OWNER := samsung"
            echo "LOCAL_SRC_FILES := $base"
            [ -n "$suffix" ] && echo "LOCAL_MODULE_SUFFIX := $suffix"
            echo "LOCAL_MODULE_CLASS := $cls"
            echo "LOCAL_MODULE_PATH := $modpath"
            echo "LOCAL_MODULE_TAGS := optional"
            if [ "$cls" = "SHARED_LIBRARIES" ]; then
                echo "LOCAL_MULTILIB := 32"
            fi
            if [ "$cls" = "EXECUTABLES" ]; then
                echo "LOCAL_MODULE_SUFFIX := \"\""
            fi
            echo "include \$(BUILD_PREBUILT)"
            echo
        } >> "$out"

        echo "$name" >> "$PKGLIST"
    done
done < <(cd "$PROP" && find . -type d | sed 's|^\./||' | sort)

# 生成 vendor mk
{
    echo "# 由 setup-makefiles.sh 自动生成，请勿手工修改"
    echo "# 所有专有文件作为 PRODUCT_PACKAGES 引入"
    n=$(sort -u "$PKGLIST" | wc -l)
    i=0
    sort -u "$PKGLIST" | while read -r mod; do
        i=$((i + 1))
        if [ "$i" -eq 1 ]; then
            printf 'PRODUCT_PACKAGES += \\\n'
        fi
        if [ "$i" -lt "$n" ]; then
            printf '    %s \\\n' "$mod"
        else
            printf '    %s\n' "$mod"
        fi
    done
} > "$VENDOR/rubenswifi-vendor.mk"

n_files=$(find "$PROP" -type f ! -name Android.mk | wc -l)
n_dirs=$(find "$PROP" -name Android.mk | wc -l)
n_pkgs=$(sort -u "$PKGLIST" | wc -l)

echo "==> 完成：$n_files 个文件 / $n_dirs 个 Android.mk / $n_pkgs 个模块"
echo "==> 已生成 $VENDOR/rubenswifi-vendor.mk"
