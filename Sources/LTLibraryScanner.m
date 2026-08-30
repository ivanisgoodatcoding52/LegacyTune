#import "LTLibraryScanner.h"
#import "LTDatabase.h"
#import <MediaPlayer/MediaPlayer.h>

// This community-repackaged SDK's MediaPlayer.framework is missing the
// _MPMediaItemPropertyDateAdded symbol at link time. MPMediaItem's
// -valueForProperty: is just a string-keyed lookup, and Apple's
// MPMediaItemProperty* constants follow a fixed pattern:
// MPMediaItemProperty<Name> == @"<name>". Using the literal sidesteps the
// missing framework symbol entirely.
static NSString *const kLTMediaItemPropertyDateAdded = @"dateAdded";
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
	if (_sharedScanner == nil) _sharedScanner = [[LTLibraryScanner alloc] init];
	return _sharedScanner;
}

- (void)startScan {
	if (_isScanning) return;
	_isScanning = YES;
	[NSThread detachNewThreadSelector:@selector(scanInBackground) toTarget:self withObject:nil];
}

- (void)scanInBackground {
	NSAutoreleasePool *outerPool = [[NSAutoreleasePool alloc] init];

	LTDatabase *backgroundDB = [[LTDatabase alloc] init];
	if (![backgroundDB open]) {
		[backgroundDB release];
		[self performSelectorOnMainThread:@selector(finishScan) withObject:nil waitUntilDone:NO];
		[outerPool release];
		return;
	}

	// No predicate on this query — it deliberately returns everything
	// MPMediaQuery can see. If songs are still missing after a scan, see
	// the KNOWN LIMITATION note in this class's header; it's not a filter
	// in this code cutting the results short.
	MPMediaQuery *query = [MPMediaQuery songsQuery];
	NSArray *items = [query items];

	NSMutableArray *scanResults = [[NSMutableArray alloc] initWithCapacity:[items count]];
	NSAutoreleasePool *innerPool = [[NSAutoreleasePool alloc] init];
	NSUInteger sinceLastDrain = 0;

	for (MPMediaItem *item in items) {
		NSDictionary *result = [self scanResultForItem:item];
		if (result != nil) [scanResults addObject:result];

		sinceLastDrain++;
		if (sinceLastDrain >= kLTScannerPoolDrainInterval) {
			[innerPool release];
			innerPool = [[NSAutoreleasePool alloc] init];
			sinceLastDrain = 0;
		}
	}
	[innerPool release];

	[backgroundDB upsertSongs:scanResults];

	[scanResults release];
	[backgroundDB close];
	[backgroundDB release];

	[self performSelectorOnMainThread:@selector(finishScan) withObject:nil waitUntilDone:NO];
	[outerPool release];
}

- (NSDictionary *)scanResultForItem:(MPMediaItem *)item {
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
	if (artwork == nil) return nil;

	NSArray *cachesPaths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
	NSString *artworkDir = [[cachesPaths objectAtIndex:0] stringByAppendingPathComponent:@"Artwork"];

	NSFileManager *fileManager = [NSFileManager defaultManager];
	if (![fileManager fileExistsAtPath:artworkDir]) {
		// Available since iOS 2.0 - fine on our iOS 3.0 floor.
		[fileManager createDirectoryAtPath:artworkDir withIntermediateDirectories:YES attributes:nil error:NULL];
	}

	NSString *fullPath = [artworkDir stringByAppendingPathComponent:[persistentIDString stringByAppendingPathExtension:@"png"]];
	if ([fileManager fileExistsAtPath:fullPath]) return fullPath;

	UIImage *image = [artwork imageWithSize:CGSizeMake(300, 300)];
	if (image == nil) return nil;

	[UIImagePNGRepresentation(image) writeToFile:fullPath atomically:YES];
	return fullPath;
}

- (void)finishScan {
	_isScanning = NO;
	[[NSNotificationCenter defaultCenter] postNotificationName:LTLibraryScannerDidFinishNotification object:self];
}

@end
