# LegacyTune

An offline, Spotify-inspired music player for legacy iOS devices. It reads the
device's own media library (`MPMediaQuery`), mirrors it into a local SQLite
database, and plays through `MPMusicPlayerController` so it works across the
whole iOS 3.0 – 6.x range.

## Features

- **Home** – Favorites (pinned artists/albums), Recently Added, and Recently
  Played strips; sections can be reordered with Edit.
- **Library** – browse by album, artist, genre; album grid with cached artwork.
- **Search** – debounced search over title / artist / album / genre.
- **Playlists** – create, rename, reorder, add songs.
- **Player** – scrubber, shuffle, repeat (off / all / one), previous-restarts-
  if->3s convention.
- **Play history** – play count and last-played are recorded per song.

## Layout

| Path | What |
|---|---|
| `Sources/` | Shared Objective-C source (manual retain/release, no ARC) |
| `TierA-ARMv6-iOS3/` | Theos build for ARMv6 devices, iOS 3.0+ (iPhone 2G/3G, iPod touch 1/2) |
| `TierB-ARMv7-iOS6/` | Theos build for ARMv7 devices, iOS 6.0+ (3GS and later, iPad) |

Both tiers compile the same `Sources/`, so code must stay compatible with the
iOS 4.3 SDK (see `Sources/LTCompat.h`). See [SETUP.md](SETUP.md) to build.

## Notes for contributors

- The code is **MRC**: balance every `retain`/`alloc` with a `release`, and
  don't hold unretained pointers to `NSTimer`s.
- Persistent IDs are stored as `%llu` strings; the scanner and
  `LTPlaybackController` must format them identically.
- The library scanner prunes songs that disappeared from the device (and, via
  foreign-key cascade, their playlist entries). It skips pruning on an empty
  scan.
