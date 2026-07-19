#import <Foundation/Foundation.h>

extern NSString *const LTLibraryScannerDidFinishNotification;

// Populates LTDatabase from the on-device media library via MPMediaQuery.
//
// PERFORMANCE: everything in this class — the MPMediaQuery enumeration,
// artwork PNG encoding/writing, and all SQLite writes — runs on a single
// background thread with its OWN LTDatabase connection. NONE of it
// touches the main thread until the very end (a single notification
// post). Earlier versions of this class bounced to the main thread once
// per song for the DB write, which included synchronous PNG compression —
// on real hardware that froze the UI solid for the whole scan. Don't
// reintroduce a per-item main-thread hop here.
//
// SCOPE NOTE: this covers two of the spec's "Library Source" options —
// "Existing iPod/Music library database" and "Synced iTunes media" —
// since Apple has already parsed ID3/MP4 metadata for anything that made
// it into the on-device library via sync. Folder/file import (hand-rolled
// ID3v2/MP4 tag reading) is a separate, not-yet-built follow-up.
@interface LTLibraryScanner : NSObject {
	BOOL _isScanning;
}

+ (LTLibraryScanner *)sharedScanner;

// No-op if a scan is already in progress. Posts
// LTLibraryScannerDidFinishNotification on the main thread when done.
- (void)startScan;

@property (nonatomic, readonly) BOOL isScanning;

@end
