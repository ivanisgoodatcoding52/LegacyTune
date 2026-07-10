########################################################################
# LegacyTune — Tier A build (ARMv6, iPhone 2G/3G, iPod touch 1st/2nd gen)
#
# This Makefile targets iOS 3.0 as the minimum deployment target and
# compiles against the iPhoneOS4.2 SDK (safe upper bound for ARMv6
# hardware, which never shipped past iOS 4.2.1).
#
# Before building:
#   1. Install Theos (see SETUP.md).
#   2. Drop iPhoneOS4.2.sdk into $THEOS/sdks/ (see SETUP.md).
#   3. export THEOS=~/theos   (or wherever you installed it)
#
# Build with:   make package
# Install with: make package install
########################################################################

ARCHS = armv6
TARGET = iphone:clang:4.2:3.0

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = LegacyTune

LegacyTune_FILES = $(wildcard Sources/*.m)
LegacyTune_FRAMEWORKS = UIKit Foundation CoreGraphics QuartzCore AudioToolbox AVFoundation
LegacyTune_CFLAGS = -Wall -Wno-unused-variable -std=gnu99 -fobjc-legacy-dispatch
LegacyTune_INFOPLIST = Resources/Info.plist

include $(THEOS_MAKE_PATH)/application.mk

# Convenience target: respring after install so the icon shows up immediately
after-install::
	install.exec "killall -9 SpringBoard"
