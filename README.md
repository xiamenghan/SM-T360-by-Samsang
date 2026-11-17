# SM-T360 TWRP 云编译仓库

这个仓库本身就是 AOSP 根目录：`device/` 与 `vendor/` 已经按源码树结构放好，
GitHub Actions 会在云端拉 TWRP 最小 manifest、编译 `recovery.img` 并作为产物上传。

## 一、推到 GitHub

```bash
cd gh-repo
git init
git add .
git commit -m "SM-T360 (rubenswifi) TWRP device tree + CI"
git branch -M main
git remote add origin https://github.com/<你的用户名>/<仓库名>.git
git push -u origin main
```

仓库约 314 MB，首次 push 会比较慢。如果不想传 blobs，可以删掉 `vendor/` 再推，
但那样编出来的 recovery 会缺显示/存储相关库，**不建议**。

## 二、触发编译

推送后自动触发；也可以在仓库页面 **Actions → Build TWRP for SM-T360 → Run workflow** 手动触发。

- 运行环境：ubuntu-22.04，16 核，约 40–70 分钟
- TWRP 分支：`twrp-9.0`（对应 Android 9，与设备树的 lineage-16.0 目标一致）
- 内核：`LineageOS/android_kernel_samsung_msm8226` @ `lineage-16.0`
- rubenswifi 的 DTS 若不在社区内核里，脚本会自动下载三星官方 OSS 源码补齐

## 三、取产物

编译成功后，在 Actions 运行页面底部 **Artifacts** 下载 `twrp-recovery-rubenswifi`，
解压得到 `recovery.img`。

## 四、刷入验证

1. 平板关机
2. 按住 **音量下 + Home + 电源** → 出现警告 → **音量上** 确认，进入 Download 模式
3. Windows 上打开 Odin3（`Odin3_v3.13.1.zip`），只勾 **AP**，选 `recovery.img`
   - 注意：Odin 的 AP 槽一般需要 `.tar.md5`，直接把 `recovery.img` 打成 tar：
     ```bash
     tar -H ustar -cf twrp-rubenswifi.tar recovery.img
     md5sum -t twrp-rubenswifi.tar >> twrp-rubenswifi.tar
     mv twrp-rubenswifi.tar twrp-rubenswifi.tar.md5
     ```
4. `Options` 里只保留 **Auto Reboot** + **F.Reset Time**，**不要**勾 Re-Partition
5. 点 **Start**，看到绿色 PASS 后自动重启
6. 关机，按住 **音量上 + Home + 电源** 进 recovery

## 五、验证清单

| 项目 | 通过标准 |
|---|---|
| 内核启动 | 显示 TWRP 启动画面，不黑屏、不重启循环 |
| 屏幕 | 800×1280 显示正常，无花屏/偏移 |
| 触摸 | 能点按、滑动，坐标不偏移 |
| 分区 | Mount 菜单里能挂载 /system、/data、/cache |
| 存储 | 能读取内置存储与 SD 卡 |
| ADB | `adb devices` 能看到 `recovery` |

## 六、失败怎么办

- 黑屏/循环重启：多数是 DTB 或面板时序问题，把 `Actions` 里的 `build-log` 或设备 `last_kmsg` 发我
- 触摸无反应：检查 `idc/touch.idc` 与 DTS 是否匹配（本机是 Synaptics RMI4，I2C 0x20）
- 想恢复原厂：用 Odin 刷官方 `T360XXS1BRI2` 完整包即可，recovery 分区会被覆盖

## 七、风险

刷自编译 recovery 会熔断 KNOX（warranty bit 0x1，不可逆）。这台机器已过保，
且官方固件可随时刷回，功能上只影响 Knox 容器。
