ARCHS = arm64
TARGET = iphone:clang:latest:15.0

include $(THEOS)/makefiles/common.mk

LIBRARY_NAME = DiscordPro
DiscordPro_FILES = Tweak.xm
DiscordPro_CFLAGS = -fobjc-arc
DiscordPro_FRAMEWORKS = CoreFoundation
DiscordPro_INSTALL_PATH = @executable_path/Frameworks
DiscordPro_LDFLAGS = -Wl,-rpath,@executable_path/Frameworks

include $(THEOS_MAKE_PATH)/library.mk
