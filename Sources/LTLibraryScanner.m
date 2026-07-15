#import "LTLibraryScanner.h"
#import "LTDatabase.h"
#import <MediaPlayer/MediaPlayer.h>

// The Sn0wCooder/qianjigui community-repackaged SDKs are known to drop a
// handful of constant declarations from their headers even though the
// symbol is genuinely present in the on-device MediaPlayer.framework
// binary (it's a real, documented API — the header extraction just missed
// it). Declaring the extern ourselves fixes the "undeclared identifier"
// compile error without needing a different SDK; the linker resolves the
// actual symbol from the framework stub at link time as normal. If a
// future SDK swap makes this a duplicate-declaration error, just delete
// this block.
extern NSString * const MPMediaItemPropertyDateAdded;

NSString *const LTLibraryScannerDidFinishNotification = @"LTLibraryScannerDidFinishNotification";

@interface LTLibraryScanner (Private)
- (void)scanInBackground;
- (void)upsertItem:(MPMediaItem *)item;
- (NSString *)cacheArtworkForItem:(MPMediaItem *)item persistentIDString:(NSString *)persistentIDString;
- (void)finishScan;
@end

@implementation LTLibraryScanner

@synthesize isScanning = _isScanning;

static LTLibraryScanner *_sharedScanner = nil;

+ (LTLibraryScanner *)sharedScanner {
	if (_sharedScanner == nil) {
		_sharedScanner = [[LTLibraryScanner alloc] init];
	}
	return _sharedScanner;
}

- (void)startScan {
	if (_isScanning) {
		return;
	}
	_isScanning = YES;
	[NSThread detachNewThreadSelector:@selector(scanInBackground) toTarget:self withObject:nil];
}

// Runs entirely off the main thread. sqlite3 access is NOT thread-safe the
// way LTDatabase uses it (see its header), so every actual DB call is
// bounced back to the main thread with waitUntilDone:YES — that keeps all
// sqlite3_* calls on one thread while still doing the MPMediaQuery
// enumeration (which can be slow-ish on a large library) off the main
// thread so the UI stays responsive during a scan.
- (void)scanInBackground {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

	MPMediaQuery *query = [MPMediaQuery songsQuery];
	NSArray *items = [query items];

	for (MPMediaItem *item in items) {
		[self performSelectorOnMainThread:@selector(upsertItem:) withObject:item waitUntilDone:YES];
	}

	[self performSelectorOnMainThread:@selector(finishScan) withObject:nil waitUntilDone:NO];

	[pool release];
}

- (void)upsertItem:(MPMediaItem *)item {
	LTDatabase *db = [LTDatabase sharedDatabase];

	// MPMediaItemPropertyPersistentID is an unsigned 64-bit value boxed in
	// an NSNumber. Format it manually rather than relying on -description
	// or -stringValue (NSNumber has no -stringValue on this Foundation),
	// and go through %llu specifically so we don't lose precision or get
	// scientific notation for large IDs.
	NSNumber *persistentIDNumber = [item valueForProperty:MPMediaItemPropertyPersistentID];
	NSString *persistentID = [NSString stringWithFormat:@"%llu", [persistentIDNumber unsignedLongLongValue]];

	NSArray *existingRows = [db executeQuery:@"SELECT id FROM songs WHERE persistent_id = ?"
		withArguments:[NSArray arrayWithObject:persistentID]];

	NSString *title = [item valueForProperty:MPMediaItemPropertyTitle];
	NSString *artist = [item valueForProperty:MPMediaItemPropertyArtist];
	NSString *album = [item valueForProperty:MPMediaItemPropertyAlbumTitle];
	NSString *genre = [item valueForProperty:MPMediaItemPropertyGenre];
	NSNumber *trackNumber = [item valueForProperty:MPMediaItemPropertyAlbumTrackNumber];
	NSNumber *discNumber = [item valueForProperty:MPMediaItemPropertyDiscNumber];
	NSNumber *duration = [item valueForProperty:MPMediaItemPropertyPlaybackDuration];
	NSDate *dateAdded = [item valueForProperty:MPMediaItemPropertyDateAdded];

	if (title == nil) title = @"Unknown Title";
	if (artist == nil) artist = @"Unknown Artist";
	if (album == nil) album = @"Unknown Album";
	if (genre == nil) genre = @"";
	if (trackNumber == nil) trackNumber = [NSNumber numberWithInt:0];
	if (discNumber == nil) discNumber = [NSNumber numberWithInt:0];
	if (duration == nil) duration = [NSNumber numberWithDouble:0];

	NSString *artworkPath = [self cacheArtworkForItem:item persistentIDString:persistentID];

	if ([existingRows count] > 0) {
		NSNumber *songId = [[existingRows objectAtIndex:0] objectForKey:@"id"];
		NSMutableArray *args = [NSMutableArray arrayWithObjects:title, artist, album, genre, trackNumber, discNumber, duration, nil];
		[args addObject:(artworkPath ? artworkPath : (id)[NSNull null])];
		[args addObject:songId];

		[db executeUpdate:@"UPDATE songs SET title=?, artist=?, album=?, genre=?, track_number=?, disc_number=?, duration=?, artwork_path=? WHERE id=?"
			withArguments:args];
	} else {
		NSMutableArray *args = [NSMutableArray arrayWithObjects:persistentID, title, artist, album, genre, trackNumber, discNumber, duration, nil];
		[args addObject:(artworkPath ? artworkPath : (id)[NSNull null])];
		[args addObject:[NSNumber numberWithDouble:[dateAdded timeIntervalSince1970]]];

		[db executeUpdate:@"INSERT INTO songs (persistent_id, title, artist, album, genre, track_number, disc_number, duration, artwork_path, date_added, play_count, skip_count, favorite, rating) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0, 0, 0, 0)"
			withArguments:args];
	}
}

- (NSString *)cacheArtworkForItem:(MPMediaItem *)item persistentIDString:(NSString *)persistentIDString {
	MPMediaItemArtwork *artwork = [item valueForProperty:MPMediaItemPropertyArtwork];
	if (artwork == nil) {
		return nil;
	}

	NSArray *cachesPaths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
	NSString *cachesDir = [cachesPaths objectAtIndex:0];
	NSString *artworkDir = [cachesDir stringByAppendingPathComponent:@"Artwork"];

	NSFileManager *fileManager = [NSFileManager defaultManager];
	if (![fileManager fileExistsAtPath:artworkDir]) {
		// Pre-iOS5 NSFileManager API: no withIntermediateDirectories:/error:
		// (that overload is iOS 5.0+). This one creates a single directory
		// level, which is all we need here.
		//
		// It's been deprecated since iOS 2.0 (deprecated the moment it
		// shipped, per Apple's own header), so on toolchains that build
		// warnings as errors this needs an explicit, scoped silence —
		// there's no non-deprecated replacement available on our iOS 3.0
		// floor, so this is a deliberate, permanent use, not an oversight.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
		[fileManager createDirectoryAtPath:artworkDir attributes:nil];
#pragma clang diagnostic pop
	}

	NSString *fileName = [persistentIDString stringByAppendingPathExtension:@"png"];
	NSString *fullPath = [artworkDir stringByAppendingPathComponent:fileName];

	if ([fileManager fileExistsAtPath:fullPath]) {
		return fullPath;
	}

	UIImage *image = [artwork imageWithSize:CGSizeMake(300, 300)];
	if (image == nil) {
		return nil;
	}

	NSData *pngData = UIImagePNGRepresentation(image);
	[pngData writeToFile:fullPath atomically:YES];

	return fullPath;
}

- (void)finishScan {
	_isScanning = NO;
	[[NSNotificationCenter defaultCenter] postNotificationName:LTLibraryScannerDidFinishNotification object:self];
}

@end
