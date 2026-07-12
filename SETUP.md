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

## 3. Clone this project 

Shouldn't have to explain this one

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

## 4. Build

```bash
make package
```

## 5. Sanity-check on real (or emulated) hardware

There's no iOS Simulator support this far back; Theos apps for
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
