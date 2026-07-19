#import "LTLibraryScanner.h"
#import "LTDatabase.h"
#import <MediaPlayer/MediaPlayer.h>

// This community-repackaged SDK's MediaPlayer.framework is missing the
// _MPMediaItemPropertyDateAdded symbol at LINK time (not just from its
// headers — an earlier `extern` declaration compiled fine but the linker
// had nothing to resolve it against). MPMediaItem's -valueForProperty: is
// just a string-keyed lookup though, and Apple's MPMediaItemProperty*
// constants follow a fixed pattern: MPMediaItemProperty<Name> == @"<name>"
// (lowerCamelCase). Using the literal sidesteps the missing framework
// symbol entirely. Worst case if this were ever wrong: the lookup returns
// nil and date_added falls back to 0 (guarded below) — no crash.
static NSString *const kLTMediaItemPropertyDateAdded = @"dateAdded";

// Drain the autorelease pool every N items during the scan loop rather
// than only once at the very end. On a 128–256MB device, a library of a
// few thousand songs would otherwise pile up that many autoreleased
// NSStrings/NSNumbers/NSDictionaries before anything gets freed — a real
// memory-pressure risk on this hardware class, not just a style nicety.
static const NSUInteger kLTScannerPoolDrainInterval = 50;

NSString *const LTLibraryScannerDidFinishNotification = @"LTLibraryScannerDidFinishNotification";

@interface LTLibraryScanner (Private)
- (void)scanInBackground;
- (NSDictionary *)scanResultForItem:(MPMediaItem *)item;
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

// Runs entirely off the main thread on its own LTDatabase connection —
// see the header for why that matters. Structure: gather everything
// (metadata + artwork) into plain dictionaries first, then hand the whole
// batch to -[LTDatabase upsertSongs:] once, which does the SQLite side of
// things inside a single transaction with reused prepared statements.
- (void)scanInBackground {
	NSAutoreleasePool *outerPool = [[NSAutoreleasePool alloc] init];

	LTDatabase *backgroundDB = [[LTDatabase alloc] init];
	if (![backgroundDB open]) {
		NSLog(@"[LTLibraryScanner] failed to open background DB connection, aborting scan");
		[backgroundDB release];
		[self performSelectorOnMainThread:@selector(finishScan) withObject:nil waitUntilDone:NO];
		[outerPool release];
		return;
	}

	MPMediaQuery *query = [MPMediaQuery songsQuery];
	NSArray *items = [query items];
	NSUInteger itemCount = [items count];

	NSMutableArray *scanResults = [[NSMutableArray alloc] initWithCapacity:itemCount];

	NSAutoreleasePool *innerPool = [[NSAutoreleasePool alloc] init];
	NSUInteger sinceLastDrain = 0;

	for (MPMediaItem *item in items) {
		NSDictionary *result = [self scanResultForItem:item];
		if (result != nil) {
			[scanResults addObject:result];
		}

		sinceLastDrain++;
		if (sinceLastDrain >= kLTScannerPoolDrainInterval) {
			[innerPool release];
			innerPool = [[NSAutoreleasePool alloc] init];
			sinceLastDrain = 0;
		}
	}

	[innerPool release];

	// The one and only point this whole scan talks to SQLite — one
	// transaction for the entire library instead of one per song.
	[backgroundDB upsertSongs:scanResults];

	[scanResults release];
	[backgroundDB close];
	[backgroundDB release];

	[self performSelectorOnMainThread:@selector(finishScan) withObject:nil waitUntilDone:NO];

	[outerPool release];
}

- (NSDictionary *)scanResultForItem:(MPMediaItem *)item {
	// MPMediaItemPropertyPersistentID is an unsigned 64-bit value boxed
	// in an NSNumber. Format manually via %llu rather than relying on
	// -description or a nonexistent NSNumber -stringValue, so we don't
	// lose precision or get scientific notation for large IDs.
	NSNumber *persistentIDNumber = [item valueForProperty:MPMediaItemPropertyPersistentID];
	NSString *persistentID = [NSString stringWithFormat:@"%llu", [persistentIDNumber unsignedLongLongValue]];

	NSString *title = [item valueForProperty:MPMediaItemPropertyTitle];
	NSString *artist = [item valueForProperty:MPMediaItemPropertyArtist];
	NSString *album = [item valueForProperty:MPMediaItemPropertyAlbumTitle];
	NSString *genre = [item valueForProperty:MPMediaItemPropertyGenre];
	NSNumber *trackNumber = [item valueForProperty:MPMediaItemPropertyAlbumTrackNumber];
	NSNumber *discNumber = [item valueForProperty:MPMediaItemPropertyDiscNumber];
	NSNumber *duration = [item valueForProperty:MPMediaItemPropertyPlaybackDuration];
	NSDate *dateAdded = [item valueForProperty:kLTMediaItemPropertyDateAdded];

	if (title == nil) title = @"Unknown Title";
	if (artist == nil) artist = @"Unknown Artist";
	if (album == nil) album = @"Unknown Album";
	if (genre == nil) genre = @"";
	if (trackNumber == nil) trackNumber = [NSNumber numberWithInt:0];
	if (discNumber == nil) discNumber = [NSNumber numberWithInt:0];
	if (duration == nil) duration = [NSNumber numberWithDouble:0];

	// Message-to-nil returning a double is fine on this runtime/ABI in
	// practice, but don't lean on it — guard explicitly.
	NSTimeInterval dateAddedInterval = (dateAdded != nil) ? [dateAdded timeIntervalSince1970] : 0.0;

	NSString *artworkPath = [self cacheArtworkForItem:item persistentIDString:persistentID];

	NSMutableDictionary *result = [NSMutableDictionary dictionaryWithCapacity:10];
	[result setObject:persistentID forKey:@"persistentID"];
	[result setObject:title forKey:@"title"];
	[result setObject:artist forKey:@"artist"];
	[result setObject:album forKey:@"album"];
	[result setObject:genre forKey:@"genre"];
	[result setObject:trackNumber forKey:@"trackNumber"];
	[result setObject:discNumber forKey:@"discNumber"];
	[result setObject:duration forKey:@"duration"];
	[result setObject:[NSNumber numberWithDouble:dateAddedInterval] forKey:@"dateAdded"];
	[result setObject:(artworkPath ? (id)artworkPath : (id)[NSNull null]) forKey:@"artworkPath"];
	return result;
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
		// Correction from an earlier pass: -createDirectoryAtPath:withIntermediateDirectories:attributes:error:
		// has actually been available since iOS 2.0 (verified against
		// Apple's NSFileManager.h availability annotations), not iOS 5.0
		// as previously assumed here. That means the deprecated
		// single-argument -createDirectoryAtPath:attributes: this file
		// used to call (with a pragma to silence its deprecation-as-error)
		// was never actually necessary — the correct, non-deprecated call
		// works fine all the way back to our iOS 3.0 floor.
		[fileManager createDirectoryAtPath:artworkDir withIntermediateDirectories:YES attributes:nil error:NULL];
	}

	NSString *fileName = [persistentIDString stringByAppendingPathExtension:@"png"];
	NSString *fullPath = [artworkDir stringByAppendingPathComponent:fileName];

	if ([fileManager fileExistsAtPath:fullPath]) {
		return fullPath; // already cached from a previous scan — skip re-encoding
	}

	// This PNG encode + disk write is the single most expensive thing
	// this class does per song. It now happens on the background thread
	// (see the class header) — never move this back onto the main thread.
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
