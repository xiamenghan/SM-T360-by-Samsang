ifeq ($(BOARD_KERNEL_SEPARATED_DT),true)
LOCAL_PATH := $(call my-dir)

include $(CLEAR_VARS)

LOCAL_SRC_FILES := \
	dtbtool.c

LOCAL_CFLAGS += \
	-Wall

## Hybrid v1/v2 dtbTool. 命名为 dtbToolCM 以匹配 Android 9 构建系统默认查找的 host 工具
LOCAL_MODULE := dtbToolCM
LOCAL_MODULE_TAGS := optional

include $(BUILD_HOST_EXECUTABLE)
endif
