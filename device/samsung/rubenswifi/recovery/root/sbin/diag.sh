#!/sbin/sh
# 诊断脚本：不依赖 USB，用「屏幕+自动重启」两个信号判断 init/用户态是否跑起来
# 1) 向 framebuffer 写随机数据 → 屏幕出现彩色雪花，说明用户态和 /dev/graphics/fb0 都正常
# 2) 45 秒后主动重启 → 即使屏幕没反应，只要会重启也说明 init 活着
dd if=/dev/urandom of=/dev/graphics/fb0 bs=4096 count=1024 2>/dev/null
sleep 45
setprop sys.powerctl reboot
