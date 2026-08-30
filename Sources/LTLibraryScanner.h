#import <Foundation/Foundation.h>

extern NSString *const LTLibraryScannerDidFinishNotification;

// Populates LTDatabase from the on-device media library via MPMediaQuery.
//
// KNOWN LIMITATION: MPMediaQuery only sees media that iTunes/Finder's
// sync process registered into the device's official Media Library
// database. Songs placed on the device by other means (dropped in over
// SSH/AFC, copied directly into a filesystem folder, etc.) are invisible
// to this API — that's a limitation of the API itself, not a scan
// completeness bug. Covering that case needs a separate folder scanner
// with its own ID3v2/MP4 tag reader (not built yet — see project notes).
// If your library "isn't fully scanned," this is very likely why: check
// whether the missing tracks were added via a normal iTunes/Finder sync
// or dropped onto the filesystem directly.
//
// PERFORMANCE: everything here — MPMediaQuery enumeration, artwork PNG
// encoding, all SQLite writes — runs on a background thread with its own
// LTDatabase connection. Never move any of this back onto the main thread.
@interface LTLibraryScanner : NSObject {
	BOOL _isScanning;
}

+ (LTLibraryScanner *)sharedScanner;
- (void)startScan;
@property (nonatomic, readonly) BOOL isScanning;

@end
