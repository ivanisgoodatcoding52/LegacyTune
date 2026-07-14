#import "LTPlaylistDetailViewController.h"
#import "LTPlaylistStore.h"
#import "LTPlaylist.h"
#import "LTSong.h"
#import "LTAddSongsViewController.h"

@interface LTPlaylistDetailViewController (Private)
- (void)reload;
- (void)addSongsTapped;
@end

@implementation LTPlaylistDetailViewController

- (id)initWithPlaylist:(LTPlaylist *)playlist {
	self = [super init];
	if (self) {
		_playlist = [playlist retain];
		self.title = playlist.name;
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

- (void)viewDidLoad {
	[super viewDidLoad];
	self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc]
		initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(addSongsTapped)] autorelease];
	self.navigationItem.leftBarButtonItem = self.editButtonItem;
}

- (void)setEditing:(BOOL)editing animated:(BOOL)animated {
	[super setEditing:editing animated:animated];
	[_tableView setEditing:editing animated:animated];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[self reload];
}

- (void)reload {
	[_songs release];
	_songs = [[[LTPlaylistStore sharedStore] songsInPlaylist:_playlist] retain];
	[_tableView reloadData];
}

- (void)addSongsTapped {
	LTAddSongsViewController *picker = [[LTAddSongsViewController alloc] initWithPlaylist:_playlist];
	[self.navigationController pushViewController:picker animated:YES];
	[picker release];
}

#pragma mark - UITableViewDataSource / Delegate

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return [_songs count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	static NSString *cellIdentifier = @"LTPlaylistSongCell";
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
	if (cell == nil) {
		cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellIdentifier] autorelease];
		cell.textLabel.textColor = [UIColor whiteColor];
		cell.detailTextLabel.textColor = [UIColor lightGrayColor];
		cell.backgroundColor = [UIColor blackColor];
	}

	LTSong *song = [_songs objectAtIndex:indexPath.row];
	cell.textLabel.text = song.title;
	cell.detailTextLabel.text = song.artist;

	return cell;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
	return YES;
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
	return YES;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
	if (editingStyle == UITableViewCellEditingStyleDelete) {
		[[LTPlaylistStore sharedStore] removeSongAtIndex:indexPath.row fromPlaylist:_playlist];
		[self reload];
	}
}

- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)sourceIndexPath toIndexPath:(NSIndexPath *)destinationIndexPath {
	[[LTPlaylistStore sharedStore] moveSongInPlaylist:_playlist fromIndex:sourceIndexPath.row toIndex:destinationIndexPath.row];

	// Update the in-memory copy immediately for visual continuity; the
	// next -viewWillAppear -reload re-syncs from the DB as source of truth.
	NSMutableArray *mutableSongs = [NSMutableArray arrayWithArray:_songs];
	id moved = [[mutableSongs objectAtIndex:sourceIndexPath.row] retain];
	[mutableSongs removeObjectAtIndex:sourceIndexPath.row];
	[mutableSongs insertObject:moved atIndex:destinationIndexPath.row];
	[moved release];

	[_songs release];
	_songs = [mutableSongs retain];
}

- (void)dealloc {
	[_playlist release];
	[_tableView release];
	[_songs release];
	[super dealloc];
}

@end
