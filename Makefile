ARCHS = arm64
TARGET = iphone:clang:latest:15.0
INSTALL_TARGET_PROCESSES = Discord

include $(THEOS)/makefiles/common.mk

LIBRARY_NAME = TweakCompleto
TweakCompleto_FILES = Tweak.xm
TweakCompleto_CFLAGS = -fobjc-arc
TweakCompleto_FRAMEWORKS = UIKit AVFoundation AudioToolbox CoreMedia CoreFoundation CoreVideo CoreGraphics CoreImage Photos PhotosUI QuartzCore Accelerate
TweakCompleto_INSTALL_PATH = @executable_path

include $(THEOS_MAKE_PATH)/library.mk
