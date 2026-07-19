ARCHS = arm64
TARGET = iphone:clang:latest:15.0
INSTALL_TARGET_PROCESSES = Discord

include $(THEOS)/makefiles/common.mk

LIBRARY_NAME = DiscordPro
DiscordPro_FILES = Tweak.xm
DiscordPro_CFLAGS = -fobjc-arc
DiscordPro_FRAMEWORKS = UIKit

include $(THEOS_MAKE_PATH)/library.mk
