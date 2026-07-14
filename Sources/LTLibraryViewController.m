#import "LTLibraryViewController.h"
#import "LTDatabase.h"
#import "LTSong.h"
#import "LTLibraryScanner.h"
#import "LTSongListViewController.h"

typedef enum {
	LTLibraryModeArtists = 0,
	LTLibraryModeAlbums,
	LTLibraryModeSongs,
	LTLibraryModeGenres
} LTLibraryMode;

@interface LTLibraryViewController (Private)
- (void)reloadForCurrentMode;
- (void)modeChanged;
- (void)scannerDidFinish:(NSNotification *)notification;
@end

@implementation LTLibraryViewController

- (id)init {
	self = [super init];
	if (self) {
		self.title = @"Library";
		[[NSNotificationCenter defaultCenter] addObserver:self
			selector:@selector(scannerDidFinish:)
			name:LTLibraryScannerDidFinishNotification
			object:nil];
	}
	return self;
}

- (void)loadView {
	CGRect frame = [[UIScreen mainScreen] applicationFrame];
	self.view = [[[UIView alloc] initWithFrame:frame] autorelease];
	self.view.backgroundColor = [UIColor blackColor];

	NSArray *segmentTitles = [NSArray arrayWithObjects:@"Artists", @"Albums", @"Songs", @"Genres", nil];
	_modeControl = [[UISegmentedControl alloc] initWithItems:segmentTitles];
	_modeControl.frame = CGRectMake(10, 8, frame.size.width - 20, 30);
	_modeControl.selectedSegmentIndex = LTLibraryModeArtists;
	_modeControl.segmentedControlStyle = UISegmentedControlStyleBar;
	_modeControl.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	[_modeControl addTarget:self action:@selector(modeChanged) forControlEvents:UIControlEventValueChanged];
	[self.view addSubview:_modeControl];

	CGFloat tableY = CGRectGetMaxY(_modeControl.frame) + 8;
	_tableView = [[UITableView alloc] initWithFrame:CGRectMake(0, tableY, frame.size.width, frame.size.height - tableY) style:UITableViewStylePlain];
	_tableView.dataSource = self;
	_tableView.delegate = self;
	_tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	[self.view addSubview:_tableView];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[self reloadForCurrentMode];
}

- (void)modeChanged {
	[self reloadForCurrentMode];
}

- (void)scannerDidFinish:(NSNotification *)notification {
	[self reloadForCurrentMode];
}

- (void)reloadForCurrentMode {
	LTDatabase *db = [LTDatabase sharedDatabase];

	[_groupedTitles release];
	[_songs release];
	_groupedTitles = nil;
	_songs = nil;

	switch (_modeControl.selectedSegmentIndex) {
		case LTLibraryModeArtists: {
			NSArray *rows = [db executeQuery:@"SELECT DISTINCT artist FROM songs ORDER BY artist COLLATE NOCASE ASC" withArguments:nil];
			NSMutableArray *titles = [NSMutableArray arrayWithCapacity:[rows count]];
			for (NSDictionary *row in rows) {
				[titles addObject:[row objectForKey:@"artist"]];
			}
			_groupedTitles = [titles retain];
			break;
		}
		case LTLibraryModeAlbums: {
			NSArray *rows = [db executeQuery:@"SELECT DISTINCT album FROM songs ORDER BY album COLLATE NOCASE ASC" withArguments:nil];
			NSMutableArray *titles = [NSMutableArray arrayWithCapacity:[rows count]];
			for (NSDictionary *row in rows) {
				[titles addObject:[row objectForKey:@"album"]];
			}
			_groupedTitles = [titles retain];
			break;
		}
		case LTLibraryModeGenres: {
			NSArray *rows = [db executeQuery:@"SELECT DISTINCT genre FROM songs WHERE genre != '' ORDER BY genre COLLATE NOCASE ASC" withArguments:nil];
			NSMutableArray *titles = [NSMutableArray arrayWithCapacity:[rows count]];
			for (NSDictionary *row in rows) {
				[titles addObject:[row objectForKey:@"genre"]];
			}
			_groupedTitles = [titles retain];
			break;
		}
		case LTLibraryModeSongs:
		default: {
			NSArray *rows = [db executeQuery:@"SELECT * FROM songs ORDER BY title COLLATE NOCASE ASC" withArguments:nil];
			NSMutableArray *songs = [NSMutableArray arrayWithCapacity:[rows count]];
			for (NSDictionary *row in rows) {
				[songs addObject:[LTSong songWithRow:row]];
			}
			_songs = [songs retain];
			break;
		}
	}

	[_tableView reloadData];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	if (_modeControl.selectedSegmentIndex == LTLibraryModeSongs) {
		return [_songs count];
	}
	return [_groupedTitles count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	static NSString *cellIdentifier = @"LTLibraryCell";
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
	if (cell == nil) {
		cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellIdentifier] autorelease];
		cell.textLabel.textColor = [UIColor whiteColor];
		cell.detailTextLabel.textColor = [UIColor lightGrayColor];
		cell.backgroundColor = [UIColor blackColor];
		cell.selectionStyle = UITableViewCellSelectionStyleBlue;
	}

	if (_modeControl.selectedSegmentIndex == LTLibraryModeSongs) {
		LTSong *song = [_songs objectAtIndex:indexPath.row];
		cell.textLabel.text = song.title;
		cell.detailTextLabel.text = song.artist;
		cell.accessoryType = UITableViewCellAccessoryNone;
	} else {
		cell.textLabel.text = [_groupedTitles objectAtIndex:indexPath.row];
		cell.detailTextLabel.text = nil;
		cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
	}

	return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:YES];

	if (_modeControl.selectedSegmentIndex == LTLibraryModeSongs) {
		// TODO: hand off to the playback engine once it exists.
		return;
	}

	NSString *filterColumn = nil;
	switch (_modeControl.selectedSegmentIndex) {
		case LTLibraryModeArtists: filterColumn = @"artist"; break;
		case LTLibraryModeAlbums:  filterColumn = @"album";  break;
		case LTLibraryModeGenres:  filterColumn = @"genre";  break;
		default: break;
	}

	NSString *filterValue = [_groupedTitles objectAtIndex:indexPath.row];

	LTSongListViewController *songList = [[LTSongListViewController alloc]
		initWithFilterColumn:filterColumn value:filterValue title:filterValue];
	[self.navigationController pushViewController:songList animated:YES];
	[songList release];
}

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[_modeControl release];
	[_tableView release];
	[_groupedTitles release];
	[_songs release];
	[super dealloc];
}

@end
