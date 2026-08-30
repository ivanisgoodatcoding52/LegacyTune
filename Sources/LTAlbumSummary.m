#import "LTAlbumSummary.h"

@implementation LTAlbumSummary

@synthesize album = _album;
@synthesize artist = _artist;
@synthesize artworkPath = _artworkPath;

+ (id)summaryWithRow:(NSDictionary *)row {
	LTAlbumSummary *summary = [[[LTAlbumSummary alloc] init] autorelease];
	summary.album = [row objectForKey:@"album"];
	summary.artist = [row objectForKey:@"artist"];
	id artworkPath = [row objectForKey:@"artwork_path"];
	summary.artworkPath = [artworkPath isKindOfClass:[NSString class]] ? artworkPath : nil;
	return summary;
}

- (void)dealloc {
	[_album release];
	[_artist release];
	[_artworkPath release];
	[super dealloc];
}

@end
