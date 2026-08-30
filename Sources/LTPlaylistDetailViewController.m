#import "LTPlaylistDetailViewController.h"
#import "LTPlaylistStore.h"
#import "LTPlaylist.h"
#import "LTSong.h"
#import "LTAddSongsViewController.h"
#import "LTPlaybackController.h"

@interface LTPlaylistDetailViewController (Private)
- (void)reload;
- (void)addSongsTapped;
- (void)toggleEditingTapped;
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
	_tableView.backgroundColor = [UIColor blackColor]; // fix: was default white
	_tableView.separatorColor = [UIColor colorWithWhite:0.25f alpha:1.0f];
	_tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	[self.view addSubview:_tableView];
}

- (void)viewDidLoad {
	[super viewDidLoad];

	// FIX: this screen is PUSHED onto the nav stack (unlike
	// LTPlaylistsViewController, which is the tab's root). Setting
	// navigationItem.leftBarButtonItem here — as an earlier version of
	// this file did, to self.editButtonItem — silently replaces
	// UINavigationController's automatic Back button. That was the exact
	// cause of "can't go back from a playlist." Fix: leave
	// leftBarButtonItem untouched (Back stays automatic), and put both
	// Edit and Add on the right side together instead, as a single
	// custom view — UIBarButtonItem's `rightBarButtonItems` array
	// property is iOS 5.0+ only, so two separate right-side buttons need
	// to be combined into one custom view on our iOS 3.0 floor.
	UIView *buttonContainer = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 92, 30)];
	buttonContainer.backgroundColor = [UIColor clearColor];

	UIButton *editButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
	editButton.frame = CGRectMake(0, 0, 44, 30);
	[editButton setTitle:@"Edit" forState:UIControlStateNormal];
	[editButton addTarget:self action:@selector(toggleEditingTapped) forControlEvents:UIControlEventTouchUpInside];
	[buttonContainer addSubview:editButton];

	UIButton *addButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
	addButton.frame = CGRectMake(48, 0, 44, 30);
	[addButton setTitle:@"Add" forState:UIControlStateNormal];
	[addButton addTarget:self action:@selector(addSongsTapped) forControlEvents:UIControlEventTouchUpInside];
	[buttonContainer addSubview:addButton];

	self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithCustomView:buttonContainer] autorelease];
	[buttonContainer release];
}

- (void)toggleEditingTapped {
	[self setEditing:!self.editing animated:YES];
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

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	if (self.editing) return; // reorder/delete mode is active — a tap here shouldn't also start playback
	[[LTPlaybackController sharedController] playSongs:_songs startingAtIndex:indexPath.row];
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
