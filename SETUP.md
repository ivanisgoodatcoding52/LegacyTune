# Building LegacyTune

LegacyTune builds with [Theos](https://theos.dev) and the community iOS SDKs.

## One-time setup

1. Install Theos and export its location:
   ```
   export THEOS=~/theos
   ```
2. Put the SDKs you need into `$THEOS/sdks/`
   (e.g. from the `Sn0wCooder/theos-sdks` repo):
   - Tier A: `iPhoneOS4.3.sdk`
   - Tier B: `iPhoneOS6.1.sdk`
3. Replace the placeholder bundle id (`com.yourname.legacytune`) and
   maintainer in each tier's `control` and `Resources/Info.plist`.
4. Add `icon.png` / `icon@2x.png` to each tier's `Resources/` (referenced by
   `CFBundleIconFiles`; the build does not fail without them, the app just has
   no icon).

## Build and install

```
cd TierA-ARMv6-iOS3     # or TierB-ARMv7-iOS6
make package            # produces a .deb in ./packages
make package install    # also installs (needs THEOS_DEVICE_IP set)
```

## Why one shared `Sources/` for both tiers

Tier B could use newer APIs (gesture recognizers, native alert text input),
but keeping a single source tree means the two tiers can't silently drift.
Only the Makefile differs: Tier A passes `-fobjc-legacy-dispatch` because
ARMv6's objc dispatch needs it; Tier B must not.

## Upgrading an existing install

The database migrates itself on launch (for example, the Recently Played Home
section is added to existing installs), so installing a new `.deb` over an old
one keeps playlists and favorites.
