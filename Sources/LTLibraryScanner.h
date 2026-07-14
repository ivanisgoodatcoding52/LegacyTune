#import <Foundation/Foundation.h>

extern NSString *const LTLibraryScannerDidFinishNotification;

// Populates LTDatabase from the on-device media library via MPMediaQuery.
//
// SCOPE NOTE: this covers two of the spec's "Library Source" options —
// "Existing iPod/Music library database" and "Synced iTunes media" —
// because Apple has already parsed ID3/MP4 metadata for anything that made
// it into the on-device library via sync, so MPMediaItem gives us clean
// structured fields for free.
//
// NOT covered here: "User-selected folders" / "Imported ... files" /
// "Optional custom music directories". Those need a hand-rolled ID3v2/MP4
// atom tag reader, since AVAsset's metadata APIs are iOS 4.0+ only and
// this tier's floor is iOS 3.0. That's a separate, sizeable follow-up.
@interface LTLibraryScanner : NSObject {
	BOOL _isScanning;
}

+ (LTLibraryScanner *)sharedScanner;

// Runs asynchronously on a background thread; DB writes are marshaled back
// to the main thread (see the .m for why). Posts
// LTLibraryScannerDidFinishNotification on the main thread when done.
// No-op if a scan is already in progress.
- (void)startScan;

@property (nonatomic, readonly) BOOL isScanning;

@end
