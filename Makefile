ARCHS = arm64
TARGET = iphone:clang:latest:15.0
INSTALL_TARGET_PROCESSES = Discord

include $(THEOS)/makefiles/common.mk

LIBRARY_NAME = DiscordPro
DiscordPro_FILES = Tweak.xm
DiscordPro_CFLAGS = -fobjc-arc -Wno-error
DiscordPro_LDFLAGS = -Wl,-no_undefined -Wl,-dead_strip -Wl,-compatibility_version,1 -Wl,-current_version,1
DiscordPro_FRAMEWORKS = CoreFoundation

include $(THEOS_MAKE_PATH)/library.mk
