# Setting up LegacyTune

This covers getting from zero to a built `.deb`/`.ipa` for the ARMv6 tier
specifically. macOS or Linux both work; Linux needs a couple of extra steps
noted below.

## 1. Install Theos

```bash
sudo git clone --recursive https://github.com/theos/theos.git /opt/theos
export THEOS=/opt/theos
echo 'export THEOS=/opt/theos' >> ~/.bash_profile   # or ~/.zshrc
```

On Linux you also need the cross-toolchain:

```bash
# grab the prebuilt Linux toolchain theos points to (see theos/theos wiki
# "Installation" page for the current link) and extract it into
# $THEOS/toolchain
```

On macOS, Xcode's command line tools cover the compiler side; Theos handles
the rest.

## 2. Get the iPhoneOS 4.2 SDK into Theos

Tier A only needs one SDK: **iPhoneOS4.2**, since no ARMv6 device ever ran
past iOS 4.2.1.

```bash
git clone https://github.com/Sn0wCooder/theos-sdks.git
cp -r theos-sdks/iPhoneOS4.2.sdk $THEOS/sdks/
```

Confirm it's picked up:

```bash
ls $THEOS/sdks/
# should list: iPhoneOS4.2.sdk
```

(If you later add the ARMv7 tier, you'll drop later SDKs — e.g. 6.1, 10.3 —
into this same `$THEOS/sdks/` directory. Theos picks whichever one your
Makefile's `TARGET` line names.)

## 3. Drop this project in place

Unzip the provided `LegacyTune.zip` anywhere convenient — it doesn't need to
live inside `$THEOS`:

```bash
unzip LegacyTune.zip -d ~/dev
cd ~/dev/LegacyTune
```

Structure:

```
LegacyTune/
├── Makefile              — Tier A build config (armv6, iOS 3.0 floor, 4.2 SDK)
├── control                — package metadata for Cydia/Sileo-style repos
├── Resources/
│   └── Info.plist         — MinimumOSVersion 3.0, single-orientation portrait
└── Sources/
    ├── main.m
    ├── LTAppDelegate.h/.m
    ├── LTRootContainerController.h/.m   — 5-tab UITabBarController + mini player
    ├── LTHomeViewController.h/.m
    ├── LTSearchViewController.h/.m
    ├── LTLibraryViewController.h/.m
    ├── LTPlaylistsViewController.h/.m
    ├── LTSettingsViewController.h/.m
    └── LTPlayerViewController.h/.m      — modal now-playing screen
```

Before your first build, edit two things:

* `control` — replace `com.yourname.legacytune` and the maintainer/author
  fields with your own identifier and name.
* `Resources/Info.plist` — same bundle identifier, must match `control`.

You'll also want a real `icon.png` (57×57) and `icon@2x.png` (114×114,
since even ARMv6-era Retina-adjacent devices may want it) dropped into
`Resources/`, referenced by `CFBundleIconFiles` in the plist.

## 4. Build

```bash
make package
```

This produces a `.deb` in the project root, suitable for installing via
`dpkg -i` on-device or hosting on a Cydia/Sileo repo.

To build and push straight to a jailbroken device over SSH:

```bash
export THEOS_DEVICE_IP=192.168.1.X   # your device's IP
make package install
```

(`after-install::` in the Makefile resprings SpringBoard automatically so
the new icon shows up.)

## 5. Sanity-check on real (or emulated) hardware

There's no iOS Simulator support this far back — Theos apps for
ARMv6/iPhoneOS 3–4 need an actual jailbroken device to run on. If you don't
have period-correct hardware handy, this is the point where an iPhone 3G or
an iPod touch 2nd gen (both ARMv6, both cap at iOS 4.2.1) becomes useful to
keep around for testing.

## What's stubbed vs. real right now

Everything currently compiles and launches into a working 5-tab shell with
a tappable mini player that presents a modal "player" screen — but every
screen's content is a placeholder label. None of the scanner, SQLite layer,
recommendation engine, or actual playback exists yet. Reasonable next step
after confirming this builds and installs: the SQLite schema + music
scanner, since everything else (Home, Search, Library) depends on having a
populated database to read from.
