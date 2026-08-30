#import "LTSongListViewController.h"
#import "LTDatabase.h"
#import "LTSong.h"
#import "LTPlaybackController.h"

@implementation LTSongListViewController

- (id)initWithFilterColumn:(NSString *)column value:(NSString *)value title:(NSString *)title {
	self = [super init];
	if (self) {
		self.title = title;
		_filterColumn = [column copy];
		_filterValue = [value copy];
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
	// Fix: table view's own background was left at the default white
	// before, which showed through as blank/white space around and
	// beneath cells even though the cells themselves were dark.
	_tableView.backgroundColor = [UIColor blackColor];
	_tableView.separatorColor = [UIColor colorWithWhite:0.25f alpha:1.0f];
	_tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	[self.view addSubview:_tableView];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	NSString *sql = [NSString stringWithFormat:@"SELECT * FROM songs WHERE %@ = ? ORDER BY album COLLATE NOCASE ASC, track_number ASC", _filterColumn];
	NSArray *rows = [[LTDatabase sharedDatabase] executeQuery:sql withArguments:[NSArray arrayWithObject:_filterValue]];
	NSMutableArray *songs = [NSMutableArray arrayWithCapacity:[rows count]];
	for (NSDictionary *row in rows) [songs addObject:[LTSong songWithRow:row]];
	[_songs release];
	_songs = [songs retain];
	[_tableView reloadData];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return [_songs count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	static NSString *cellIdentifier = @"LTSongCell";
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
	if (cell == nil) {
		cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellIdentifier] autorelease];
		cell.textLabel.textColor = [UIColor whiteColor];
		cell.detailTextLabel.textColor = [UIColor lightGrayColor];
		cell.backgroundColor = [UIColor blackColor];
	}
	LTSong *song = [_songs objectAtIndex:indexPath.row];
	cell.textLabel.text = song.title;
	cell.detailTextLabel.text = song.album;
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	[[LTPlaybackController sharedController] playSongs:_songs startingAtIndex:indexPath.row];
}

- (void)dealloc {
	[_tableView release];
	[_songs release];
	[_filterColumn release];
	[_filterValue release];
	[super dealloc];
}

@end
