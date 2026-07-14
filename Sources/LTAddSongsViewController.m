#import "LTAddSongsViewController.h"
#import "LTPlaylistStore.h"
#import "LTPlaylist.h"
#import "LTSong.h"
#import "LTDatabase.h"

@implementation LTAddSongsViewController

- (id)initWithPlaylist:(LTPlaylist *)playlist {
	self = [super init];
	if (self) {
		_playlist = [playlist retain];
		self.title = @"Add Songs";
	}
	return self;
}

- (void)loadView {
	CGRect frame = [[UIScreen mainScreen] applicationFrame];
	self.view = [[[UIView alloc] initWithFrame:frame] autorelease];
	self.view.backgroundColor = [UIColor blackColor];

	_tableView = [[UITableView alloc] initWithFrame:frame style:UITableViewStylePlain];
	_tableView.dataSource = self;
	_tableView.delegate = self;
	_tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	[self.view addSubview:_tableView];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];

	NSArray *rows = [[LTDatabase sharedDatabase] executeQuery:@"SELECT * FROM songs ORDER BY title COLLATE NOCASE ASC" withArguments:nil];
	NSMutableArray *songs = [NSMutableArray arrayWithCapacity:[rows count]];
	for (NSDictionary *row in rows) {
		[songs addObject:[LTSong songWithRow:row]];
	}
	[_allSongs release];
	_allSongs = [songs retain];

	NSArray *existing = [[LTPlaylistStore sharedStore] songsInPlaylist:_playlist];
	NSMutableSet *ids = [NSMutableSet setWithCapacity:[existing count]];
	for (LTSong *song in existing) {
		[ids addObject:[NSNumber numberWithInteger:song.songId]];
	}
	[_addedSongIds release];
	_addedSongIds = [ids retain];

	[_tableView reloadData];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return [_allSongs count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	static NSString *cellIdentifier = @"LTAddSongCell";
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
	if (cell == nil) {
		cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellIdentifier] autorelease];
		cell.textLabel.textColor = [UIColor whiteColor];
		cell.detailTextLabel.textColor = [UIColor lightGrayColor];
		cell.backgroundColor = [UIColor blackColor];
	}

	LTSong *song = [_allSongs objectAtIndex:indexPath.row];
	cell.textLabel.text = song.title;
	cell.detailTextLabel.text = song.artist;
	cell.accessoryType = [_addedSongIds containsObject:[NSNumber numberWithInteger:song.songId]]
		? UITableViewCellAccessoryCheckmark
		: UITableViewCellAccessoryNone;

	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:YES];

	LTSong *song = [_allSongs objectAtIndex:indexPath.row];
	NSNumber *songIdNumber = [NSNumber numberWithInteger:song.songId];

	if ([_addedSongIds containsObject:songIdNumber]) {
		return; // already in the playlist — remove it from the detail screen instead
	}

	[[LTPlaylistStore sharedStore] addSong:song toPlaylist:_playlist];
	[_addedSongIds addObject:songIdNumber];
	[tableView reloadRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationNone];
}

- (void)dealloc {
	[_playlist release];
	[_tableView release];
	[_allSongs release];
	[_addedSongIds release];
	[super dealloc];
}

@end
