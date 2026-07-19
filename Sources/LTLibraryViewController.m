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

static const NSUInteger kLTSongsPageSize = 100;
// Start fetching the next page once the user scrolls within this many
// rows of the end of what's currently loaded, so the next page is
// usually ready before they actually hit the bottom.
static const NSUInteger kLTSongsPrefetchThreshold = 20;

@interface LTLibraryViewController (Private)
- (void)modeChanged;
- (void)scannerDidFinish:(NSNotification *)notification;
- (void)ensureCurrentModeLoaded;
- (NSArray *)cachedGroupedTitlesForCurrentMode;
- (void)loadGroupedTitlesForCurrentModeIfNeeded;
- (void)resetSongsPaging;
- (void)loadNextSongsPage;
@end

@implementation LTLibraryViewController

- (id)init {
	self = [super init];
	if (self) {
		self.title = @"Library";
		_groupedTitlesCache = [[NSMutableDictionary alloc] init];
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
	// Cheap on every appearance: just ensures *something* is loaded for
	// the current mode. Does NOT re-query if we already have data —
	// that's the whole point of the cache.
	[self ensureCurrentModeLoaded];
}

- (void)modeChanged {
	[self ensureCurrentModeLoaded];
	[_tableView reloadData];
}

- (void)scannerDidFinish:(NSNotification *)notification {
	// The library actually changed — invalidate everything and reload
	// whatever mode is currently visible. All OTHER modes just get
	// dropped from cache and will re-query lazily next time the user
	// switches to them, rather than eagerly re-querying four separate
	// modes for one notification.
	[_groupedTitlesCache removeAllObjects];
	[self resetSongsPaging];
	[self ensureCurrentModeLoaded];
	[_tableView reloadData];
}

- (void)ensureCurrentModeLoaded {
	if (_modeControl.selectedSegmentIndex == LTLibraryModeSongs) {
		if (_songsPage == nil) {
			[self resetSongsPaging];
			[self loadNextSongsPage];
		}
	} else {
		[self loadGroupedTitlesForCurrentModeIfNeeded];
	}
}

- (NSArray *)cachedGroupedTitlesForCurrentMode {
	return [_groupedTitlesCache objectForKey:[NSNumber numberWithInteger:_modeControl.selectedSegmentIndex]];
}

- (void)loadGroupedTitlesForCurrentModeIfNeeded {
	NSNumber *modeKey = [NSNumber numberWithInteger:_modeControl.selectedSegmentIndex];
	if ([_groupedTitlesCache objectForKey:modeKey] != nil) {
		return; // already cached — this is the fast path for a tab switch back
	}

	LTDatabase *db = [LTDatabase sharedDatabase];
	NSString *column = nil;
	switch (_modeControl.selectedSegmentIndex) {
		case LTLibraryModeArtists: column = @"artist"; break;
		case LTLibraryModeAlbums:  column = @"album";  break;
		case LTLibraryModeGenres:  column = @"genre";  break;
		default: return;
	}

	// COLLATE NOCASE here matches the idx_songs_<column>_nocase indexes
	// created in LTDatabase, so this DISTINCT + ORDER BY is satisfied
	// directly from the index rather than requiring a full in-memory sort.
	NSString *sql = [NSString stringWithFormat:
		@"SELECT DISTINCT %@ FROM songs WHERE %@ != '' ORDER BY %@ COLLATE NOCASE ASC", column, column, column];
	NSArray *rows = [db executeQuery:sql withArguments:nil];

	NSMutableArray *titles = [NSMutableArray arrayWithCapacity:[rows count]];
	for (NSDictionary *row in rows) {
		[titles addObject:[row objectForKey:column]];
	}

	[_groupedTitlesCache setObject:titles forKey:modeKey];
}

- (void)resetSongsPaging {
	[_songsPage release];
	_songsPage = nil;
	_hasMoreSongs = YES;
	_isLoadingMoreSongs = NO;
}

- (void)loadNextSongsPage {
	if (_isLoadingMoreSongs || !_hasMoreSongs) {
		return;
	}
	_isLoadingMoreSongs = YES;

	if (_songsPage == nil) {
		_songsPage = [[NSMutableArray alloc] init];
	}

	NSUInteger offset = [_songsPage count];
	NSString *sql = @"SELECT * FROM songs ORDER BY title COLLATE NOCASE ASC LIMIT ? OFFSET ?";
	NSArray *args = [NSArray arrayWithObjects:
		[NSNumber numberWithUnsignedInteger:kLTSongsPageSize],
		[NSNumber numberWithUnsignedInteger:offset],
		nil];

	NSArray *rows = [[LTDatabase sharedDatabase] executeQuery:sql withArguments:args];
	for (NSDictionary *row in rows) {
		[_songsPage addObject:[LTSong songWithRow:row]];
	}

	_hasMoreSongs = ([rows count] == kLTSongsPageSize);
	_isLoadingMoreSongs = NO;
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	if (_modeControl.selectedSegmentIndex == LTLibraryModeSongs) {
		return [_songsPage count];
	}
	return [[self cachedGroupedTitlesForCurrentMode] count];
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
		LTSong *song = [_songsPage objectAtIndex:indexPath.row];
		cell.textLabel.text = song.title;
		cell.detailTextLabel.text = song.artist;
		cell.accessoryType = UITableViewCellAccessoryNone;
	} else {
		cell.textLabel.text = [[self cachedGroupedTitlesForCurrentMode] objectAtIndex:indexPath.row];
		cell.detailTextLabel.text = nil;
		cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
	}

	return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
	if (_modeControl.selectedSegmentIndex != LTLibraryModeSongs) {
		return;
	}
	if (!_hasMoreSongs || _isLoadingMoreSongs) {
		return;
	}

	NSUInteger loadedCount = [_songsPage count];
	if (indexPath.row + kLTSongsPrefetchThreshold >= loadedCount) {
		NSUInteger countBefore = loadedCount;
		[self loadNextSongsPage];
		NSUInteger countAfter = [_songsPage count];

		if (countAfter > countBefore) {
			NSMutableArray *newIndexPaths = [NSMutableArray arrayWithCapacity:(countAfter - countBefore)];
			for (NSUInteger i = countBefore; i < countAfter; i++) {
				[newIndexPaths addObject:[NSIndexPath indexPathForRow:i inSection:0]];
			}
			[tableView insertRowsAtIndexPaths:newIndexPaths withRowAnimation:UITableViewRowAnimationNone];
		}
	}
}

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

	NSString *filterValue = [[self cachedGroupedTitlesForCurrentMode] objectAtIndex:indexPath.row];

	LTSongListViewController *songList = [[LTSongListViewController alloc]
		initWithFilterColumn:filterColumn value:filterValue title:filterValue];
	[self.navigationController pushViewController:songList animated:YES];
	[songList release];
}

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[_modeControl release];
	[_tableView release];
	[_groupedTitlesCache release];
	[_songsPage release];
	[super dealloc];
}

@end
