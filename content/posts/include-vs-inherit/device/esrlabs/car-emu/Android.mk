LOCAL_PATH := $(call my-dir)

# Statically create folder under /vendor partition
# This is done to provide read-write folder under read-only 
# vendor partition.
include $(CLEAR_VARS)
$(warning brand: $(PRODUCT_BRAND))
$(warning cache: $(PRODUCT_BUILD_CACHE_IMAGE))
$(warning gps: $(EMULATED_GPS))
LOCAL_MODULE := CreateESRFolder
LOCAL_MODULE_PATH := $(TARGET_OUT_VENDOR)
LOCAL_POST_INSTALL_CMD := mkdir -p $(TARGET_OUT_VENDOR)/esrlabs
include $(BUILD_PHONY_PACKAGE)