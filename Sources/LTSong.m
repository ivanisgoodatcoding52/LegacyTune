#import "LTSong.h"

@implementation LTSong

@synthesize songId = _songId;
@synthesize title = _title;
@synthesize artist = _artist;
@synthesize album = _album;
@synthesize genre = _genre;
@synthesize trackNumber = _trackNumber;
@synthesize discNumber = _discNumber;
@synthesize duration = _duration;
@synthesize artworkPath = _artworkPath;
@synthesize favorite = _favorite;

+ (id)songWithRow:(NSDictionary *)row {
	LTSong *song = [[[LTSong alloc] init] autorelease];
	song.songId = [[row objectForKey:@"id"] integerValue];
	song.title = [row objectForKey:@"title"];
	song.artist = [row objectForKey:@"artist"];
	song.album = [row objectForKey:@"album"];
	song.genre = [row objectForKey:@"genre"];
	song.trackNumber = [[row objectForKey:@"track_number"] integerValue];
	song.discNumber = [[row objectForKey:@"disc_number"] integerValue];
	song.duration = [[row objectForKey:@"duration"] doubleValue];

	id artworkPath = [row objectForKey:@"artwork_path"];
	song.artworkPath = [artworkPath isKindOfClass:[NSString class]] ? artworkPath : nil;

	song.favorite = [[row objectForKey:@"favorite"] boolValue];
	return song;
}

- (void)dealloc {
	[_title release];
	[_artist release];
	[_album release];
	[_genre release];
	[_artworkPath release];
	[super dealloc];
}

@end
