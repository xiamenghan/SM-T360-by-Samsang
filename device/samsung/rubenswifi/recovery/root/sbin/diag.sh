#!/sbin/sh
# 诊断脚本 v2：把内核日志和显示/USB 状态写到 /data/media/0/diag.txt，
# 开机回 Android 后可直接用 adb pull /sdcard/diag.txt 取回。
# 不再写 framebuffer（上一版写 fb 可能就是导致重启的原因）。

OUT=/tmp/diag.txt
{
  echo "===== dmesg ====="
  dmesg
  echo "===== /proc/cmdline ====="
  cat /proc/cmdline
  echo "===== /dev/graphics ====="
  ls -l /dev/graphics/ 2>&1
  echo "===== /sys/class/graphics ====="
  ls /sys/class/graphics/ 2>&1
  for f in /sys/class/graphics/fb0/modes /sys/class/graphics/fb0/virtual_size /sys/class/graphics/fb0/stride /sys/class/graphics/fb0/bits_per_pixel; do
    echo "-- $f"; cat $f 2>&1
  done
  echo "===== /sys/class/android_usb/android0 ====="
  ls -l /sys/class/android_usb/android0/ 2>&1
  echo "===== /sys/class/leds ====="
  ls /sys/class/leds/ 2>&1
  echo "===== /proc/mounts ====="
  cat /proc/mounts 2>&1
  echo "===== getprop ====="
  getprop 2>&1 | head -40
} > $OUT 2>&1

# 写到 /data/media/0，Android 里就是 /sdcard/diag.txt
mkdir -p /data
mount -t ext4 -o rw /dev/block/platform/msm_sdcc.1/by-name/userdata /data 2>>$OUT
mkdir -p /data/media/0 2>>$OUT
cp $OUT /data/media/0/diag.txt 2>>$OUT
sync

# 兜底：外置 SD 卡
mkdir -p /mnt/sd
for d in /dev/block/mmcblk1p1 /dev/block/mmcblk1; do
  mount -t vfat -o rw $d /mnt/sd 2>/dev/null && cp $OUT /mnt/sd/diag.txt 2>/dev/null && sync && break
done

sleep 20
setprop sys.powerctl reboot
