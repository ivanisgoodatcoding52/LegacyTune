########################################################################
# LegacyTune — Tier A build (ARMv6, iPhone 2G/3G, iPod touch 1st/2nd gen)
#
# This Makefile targets iOS 3.0 as the minimum deployment target
# (MinimumOSVersion in Resources/Info.plist) and compiles against the
# iPhoneOS4.3 SDK. Building against a newer SDK than your actual runtime
# floor is fine — MinimumOSVersion / deployment target controls what the
# *binary* claims to require, the SDK version just controls which headers
# you compile against. Just don't call APIs that iOS 3.x doesn't have;
# the code in Sources/ already guards or avoids those (see comments at
# each iOS-4-only call site).
#
# Before building:
#   1. Install Theos (see SETUP.md).
#   2. Drop iPhoneOS4.3.sdk into $THEOS/sdks/ (see SETUP.md).
#   3. export THEOS=~/theos   (or wherever you installed it)
#
# Build with:   make package
# Install with: make package install
########################################################################

ARCHS = armv6
TARGET = iphone:clang:4.3:3.0

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = LegacyTune

LegacyTune_FILES = $(wildcard Sources/*.m)
LegacyTune_FRAMEWORKS = UIKit Foundation CoreGraphics QuartzCore AudioToolbox AVFoundation MediaPlayer
LegacyTune_LIBRARIES = sqlite3
LegacyTune_CFLAGS = -Wall -Wno-unused-variable -std=gnu99 -fobjc-legacy-dispatch
LegacyTune_INFOPLIST = Resources/Info.plist

include $(THEOS_MAKE_PATH)/application.mk

# Convenience target: respring after install so the icon shows up immediately
after-install::
	install.exec "killall -9 SpringBoard"
