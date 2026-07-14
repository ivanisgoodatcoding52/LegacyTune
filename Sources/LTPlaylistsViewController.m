#import "LTPlaylistsViewController.h"
#import "LTPlaylistStore.h"
#import "LTPlaylist.h"
#import "LTPlaylistDetailViewController.h"
#import "LTTextPromptViewController.h"

@interface LTPlaylistsViewController (Private)
- (void)reload;
- (void)addTapped;
- (void)createPlaylistNamed:(NSString *)name;
@end

@implementation LTPlaylistsViewController

- (id)init {
	self = [super init];
	if (self) {
		self.title = @"Playlists";
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
		initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(addTapped)] autorelease];
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
	[_playlists release];
	_playlists = [[[LTPlaylistStore sharedStore] allPlaylists] retain];
	[_tableView reloadData];
}

- (void)addTapped {
	LTTextPromptViewController *prompt = [[LTTextPromptViewController alloc]
		initWithTitle:@"New Playlist" placeholder:@"Playlist name" target:self action:@selector(createPlaylistNamed:)];
	[self.navigationController pushViewController:prompt animated:YES];
	[prompt release];
}

- (void)createPlaylistNamed:(NSString *)name {
	if ([name length] == 0) {
		return;
	}
	[[LTPlaylistStore sharedStore] createPlaylistWithName:name];
	[self reload];
}

#pragma mark - UITableViewDataSource / Delegate

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return [_playlists count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	static NSString *cellIdentifier = @"LTPlaylistCell";
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
	if (cell == nil) {
		cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier] autorelease];
		cell.textLabel.textColor = [UIColor whiteColor];
		cell.backgroundColor = [UIColor blackColor];
		cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
	}

	LTPlaylist *playlist = [_playlists objectAtIndex:indexPath.row];
	cell.textLabel.text = playlist.name;

	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:YES];

	LTPlaylist *playlist = [_playlists objectAtIndex:indexPath.row];
	LTPlaylistDetailViewController *detail = [[LTPlaylistDetailViewController alloc] initWithPlaylist:playlist];
	[self.navigationController pushViewController:detail animated:YES];
	[detail release];
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
	return YES;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
	if (editingStyle == UITableViewCellEditingStyleDelete) {
		LTPlaylist *playlist = [_playlists objectAtIndex:indexPath.row];
		[[LTPlaylistStore sharedStore] deletePlaylist:playlist];
		[self reload];
	}
}

- (void)dealloc {
	[_tableView release];
	[_playlists release];
	[super dealloc];
}

@end
