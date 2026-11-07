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

TARGET = iphone:clang:latest:7.0

# Rootless và roothide đều cần arm64e (A12+), rootful chỉ cần arm64
ifneq ($(filter rootless roothide,$(THEOS_PACKAGE_SCHEME)),)
    ARCHS = arm64 arm64e
else
    ARCHS = arm64
endif

INSTALL_TARGET_PROCESSES = fatego

TWEAK_NAME = Unity60FPS Unity60FPSLoader

Unity60FPS_FILES = Tweak.x
Unity60FPS_CFLAGS = -fobjc-arc
Unity60FPS_LIBRARIES = dobby

Unity60FPSLoader_FILES = TweakLoader.x
Unity60FPSLoader_CFLAGS = -fobjc-arc

ADDITIONAL_CFLAGS += -Wno-error=unused-variable -Wno-error=unused-function -Wno-error=unused-value -include Prefix.pch

SUBPROJECTS += unity60fpspref

include $(THEOS)/makefiles/common.mk
include $(THEOS_MAKE_PATH)/tweak.mk
include $(THEOS_MAKE_PATH)/aggregate.mk
