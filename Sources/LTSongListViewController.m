#import "LTSongListViewController.h"
#import "LTDatabase.h"
#import "LTSong.h"

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
	_tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	[self.view addSubview:_tableView];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];

	// _filterColumn is always one of a small fixed set passed in by
	// LTLibraryViewController (never user-typed text) — see the header
	// note on why interpolating it here, unlike _filterValue, is safe.
	NSString *sql = [NSString stringWithFormat:@"SELECT * FROM songs WHERE %@ = ? ORDER BY album COLLATE NOCASE ASC, track_number ASC", _filterColumn];
	NSArray *rows = [[LTDatabase sharedDatabase] executeQuery:sql withArguments:[NSArray arrayWithObject:_filterValue]];

	NSMutableArray *songs = [NSMutableArray arrayWithCapacity:[rows count]];
	for (NSDictionary *row in rows) {
		[songs addObject:[LTSong songWithRow:row]];
	}
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
	// TODO: hand off to the playback engine once it exists — not built yet
	// (see LTPlayerViewController, still a placeholder screen).
}

- (void)dealloc {
	[_tableView release];
	[_songs release];
	[_filterColumn release];
	[_filterValue release];
	[super dealloc];
}

@end
