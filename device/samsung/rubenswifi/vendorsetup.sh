#!/bin/bash
# 在 source build/envsetup.sh 之后执行本脚本，会注册 lunch 目标
export DEVICE=rubenswifi
export DEVICE_COMMON=msm8226-common
add_lunch_combo lineage_rubenswifi-userdebug
add_lunch_combo lineage_rubenswifi-eng
