# ============================================================
# Mặc định: build ROOTLESS
#   make package              -> gói rootless (/var/jb)
#   make package ROOTHIDE=1   -> gói roothide (ẩn hoàn toàn)
# ============================================================
ifeq ($(ROOTHIDE),1)
    THEOS_PACKAGE_SCHEME = roothide
else
    THEOS_PACKAGE_SCHEME = rootless
endif
export THEOS_PACKAGE_SCHEME

# Thành:
TARGET = iphone:clang:16.5:14.0

# Rootless và roothide đều cần arm64e (A12+), rootful chỉ cần arm64
ifneq ($(filter rootless roothide,$(THEOS_PACKAGE_SCHEME)),)
    ARCHS = arm64 arm64e
else
    ARCHS = arm64
endif

INSTALL_TARGET_PROCESSES = fatego

TWEAK_NAME = Unity60FPS Unity60FPSLoader

# [FIX] Trỏ thẳng đường dẫn tuyệt đối và liên kết thư viện C++
Unity60FPS_FILES = Tweak.x
Unity60FPS_CFLAGS = -fobjc-arc -I$(THEOS_PROJECT_DIR)/vendor/dobby
Unity60FPS_OBJ_FILES = $(THEOS_PROJECT_DIR)/vendor/dobby/libdobby.a
Unity60FPS_LIBRARIES = c++ c++abi     # <--- THAY DÒNG LDFLAGS BẰNG DÒNG NÀY
ADDITIONAL_CFLAGS += -Wno-error=unguarded-availability-new

Unity60FPSLoader_FILES = TweakLoader.x
Unity60FPSLoader_CFLAGS = -fobjc-arc

ADDITIONAL_CFLAGS += -Wno-error=unused-variable -Wno-error=unused-function -Wno-error=unused-value -include $(THEOS_PROJECT_DIR)/Prefix.pch

SUBPROJECTS += unity60fpspref

include $(THEOS)/makefiles/common.mk
include $(THEOS_MAKE_PATH)/tweak.mk
include $(THEOS_MAKE_PATH)/aggregate.mk
