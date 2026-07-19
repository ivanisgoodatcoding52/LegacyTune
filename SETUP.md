# Setting up LegacyTune (Tier A: ARMv6, iOS 3.0–4.2.1)

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

## 2. Get an iPhoneOS SDK into Theos

Tier A builds against **iPhoneOS4.3** (building against a newer SDK than
your actual deployment floor is fine — see the comment at the top of the
Makefile for why). If `Sn0wCooder/theos-sdks` doesn't have an
`iPhoneOS4.2.sdk` folder for you specifically, 4.3 works just as well:

```bash
git clone https://github.com/Sn0wCooder/theos-sdks.git
cp -r theos-sdks/iPhoneOS4.3.sdk $THEOS/sdks/
```

Confirm it's picked up:

```bash
ls $THEOS/sdks/
# should list: iPhoneOS4.3.sdk
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

**Real and working:**

* `LTDatabase` — SQLite layer with NOCASE-collated indexes matching how
  the app actually queries (case-insensitive alphabetical browsing),
  tuned pragmas (`synchronous=NORMAL`, `temp_store=MEMORY`, a busy
  timeout), transaction helpers, and a prepared-statement batch-upsert
  path used by the scanner.
* `LTLibraryScanner` — populates `songs` from the on-device media library
  via `MPMediaQuery`. Runs entirely on a background thread with its own
  DB connection; the whole scan is one transaction; artwork PNG encoding
  never touches the main thread. (Earlier version of this class did all
  of that per-song on the main thread — that was the freeze.)
* `LTLibraryViewController` — Artists/Albums/Songs/Genres browsing.
  Per-mode results are cached and only re-fetched when the scanner
  reports new data, not on every tab switch. Songs mode is paginated
  (100 at a time, loaded as you scroll) instead of loading the whole
  library into memory at once.
* `LTPlaylistStore` / playlist screens — unchanged functionally, reorder
  writes now wrapped in a transaction too.
* `LTSearchViewController` — real instant search across title/artist/
  album/genre, debounced (250ms), running on its own background DB
  connection with stale-result discarding so fast typing never blocks or
  shows out-of-order results.
* `LTSettingsViewController` — real: rescan library, clear artwork cache
  (with live cache size), song/playlist counts, reset database (with
  confirmation), version/build-tier info. Honestly labeled about what's
  NOT here yet (see its footer text) rather than showing dead controls
  for unbuilt features.

**Still placeholder:**

* Home tab — deliberately untouched, custom design coming separately.
* `LTPlayerViewController` — no actual playback engine wired up yet.
  Tapping a song anywhere is still a no-op (`TODO` at each tap site).
* Folder/file import scanning (ID3v2/MP4 tag parsing).
* Theme engine, recommendations/smart playlists.

**A correction from an earlier pass:** an earlier version of this project
used the deprecated `-createDirectoryAtPath:attributes:` (with a pragma to
silence the deprecation warning) under the assumption that the modern
`-createDirectoryAtPath:withIntermediateDirectories:attributes:error:` was
iOS 5.0+ only. That was wrong — the modern method has been available
since iOS 2.0. Fixed in `LTLibraryScanner.m`; no pragma needed there
anymore.

Reasonable next step: the playback engine, since Library/Search can now
show real songs fast but tapping one still does nothing.
