########################################################################
# LegacyTune — Tier B build (ARMv7, iPhone 3GS+, iPod touch 3rd gen+, iPad)
# Targets iOS 6.0 minimum, compiles against iPhoneOS6.1 SDK.
#
# Sources/ is SHARED with Tier A (../Sources, one level up) — same code,
# unmodified. Deliberately NOT modernized to take advantage of this
# tier's higher floor (native UIAlertView text input, UIGestureRecognizer,
# etc. would all be safe to use at iOS 6.0+) — keeping one source tree
# for both tiers avoids two copies of the same logic silently drifting
# apart. If Tier B ever needs to diverge for real (e.g. a genuinely
# iPad-specific screen), that's a deliberate future decision, not
# something to casually introduce here.
#
# Unlike Tier A's Makefile, this one does NOT set -fobjc-legacy-dispatch —
# that flag exists specifically to work around ARMv6's older/fragile objc
# dispatch mechanism. ARMv7 has always used the modern dispatch and
# doesn't need it; carrying it over here would be cargo-culting a flag
# that doesn't apply to this architecture.
#
# Before building:
#   1. Theos + this tier's SDK: drop iPhoneOS6.1.sdk into $THEOS/sdks/
#      (same Sn0wCooder/theos-sdks repo used for Tier A's 4.3 SDK).
#   2. export THEOS=~/theos
#
# Build with:   make package
# Install with: make package install
########################################################################

ARCHS = armv7
TARGET = iphone:clang:6.1:6.0

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = LegacyTune

LegacyTune_FILES = $(wildcard ../Sources/*.m)
LegacyTune_FRAMEWORKS = UIKit Foundation CoreGraphics QuartzCore AudioToolbox AVFoundation MediaPlayer
LegacyTune_LIBRARIES = sqlite3
LegacyTune_CFLAGS = -Wall -Wno-unused-variable -std=gnu99 -I../Sources
LegacyTune_INFOPLIST = Resources/Info.plist

include $(THEOS_MAKE_PATH)/application.mk

after-install::
	install.exec "killall -9 SpringBoard"
