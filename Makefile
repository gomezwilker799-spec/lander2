ARCHS = arm64
TARGET = iphone:clang:latest:15.0
INSTALL_TARGET_PROCESSES = Discord

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = DiscordPro
DiscordPro_FILES = Tweak.xm
DiscordPro_CFLAGS = -fobjc-arc
DiscordPro_FRAMEWORKS = Foundation CoreFoundation

include $(THEOS_MAKE_PATH)/tweak.mk
