#import "LTPlaylist.h"

@implementation LTPlaylist

@synthesize playlistId = _playlistId;
@synthesize name = _name;
@synthesize dateCreated = _dateCreated;

+ (id)playlistWithRow:(NSDictionary *)row {
	LTPlaylist *playlist = [[[LTPlaylist alloc] init] autorelease];
	playlist.playlistId = [[row objectForKey:@"id"] integerValue];
	playlist.name = [row objectForKey:@"name"];
	playlist.dateCreated = [[row objectForKey:@"date_created"] doubleValue];
	return playlist;
}

- (void)dealloc {
	[_name release];
	[super dealloc];
}

@end
