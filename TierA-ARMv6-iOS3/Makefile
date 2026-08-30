########################################################################
# LegacyTune — Tier A build (ARMv6, iPhone 2G/3G, iPod touch 1st/2nd gen)
# Targets iOS 3.0 minimum, compiles against iPhoneOS4.3 SDK.
#
# Sources/ is SHARED with Tier B (../Sources, one level up) — this is the
# same code, unmodified, just built for a different arch/SDK/deployment
# floor. See ../SETUP.md for why Tier B doesn't get iOS-6-only
# conveniences even though it could use them: keeping one source tree
# means Tier A's compatibility choices (UIControl instead of
# UIGestureRecognizer, etc.) carry over into Tier B unchanged rather than
# risk drift between two copies of the same files.
########################################################################

ARCHS = armv6
TARGET = iphone:clang:4.3:3.0

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = LegacyTune

LegacyTune_FILES = $(wildcard ../Sources/*.m)
LegacyTune_FRAMEWORKS = UIKit Foundation CoreGraphics QuartzCore AudioToolbox AVFoundation MediaPlayer
LegacyTune_LIBRARIES = sqlite3
LegacyTune_CFLAGS = -Wall -Wno-unused-variable -std=gnu99 -fobjc-legacy-dispatch -I../Sources
LegacyTune_INFOPLIST = Resources/Info.plist

include $(THEOS_MAKE_PATH)/application.mk

after-install::
	install.exec "killall -9 SpringBoard"
