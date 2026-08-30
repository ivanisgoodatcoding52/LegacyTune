#import "LTLibraryViewController.h"
#import "LTDatabase.h"
#import "LTSong.h"
#import "LTAlbumSummary.h"
#import "LTAlbumGridRowCell.h"
#import "LTLibraryScanner.h"
#import "LTSongListViewController.h"
#import "LTPlaybackController.h"

typedef enum {
	LTLibraryModeArtists = 0,
	LTLibraryModeAlbums,
	LTLibraryModeSongs,
	LTLibraryModeGenres
} LTLibraryMode;

static const NSUInteger kLTSongsPageSize = 100;
static const NSUInteger kLTSongsPrefetchThreshold = 20;
static NSString *const kLTGridRowCellIdentifier = @"LTAlbumGridRowCell";

@interface LTLibraryViewController (Private)
- (void)modeChanged;
- (void)scannerDidFinish:(NSNotification *)notification;
- (void)ensureCurrentModeLoaded;
- (NSArray *)cachedGroupedTitlesForCurrentMode;
- (void)loadGroupedTitlesForCurrentModeIfNeeded;
- (void)resetSongsPaging;
- (void)loadNextSongsPage;
- (void)loadAlbumSummariesIfNeeded;
- (void)updateGridToggleButtonVisibility;
- (void)toggleAlbumsGridTapped;
- (void)albumTileTapped:(id)sender;
@end

@implementation LTLibraryViewController

- (id)init {
	self = [super init];
	if (self) {
		self.title = @"Library";
		_groupedTitlesCache = [[NSMutableDictionary alloc] init];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(scannerDidFinish:) name:LTLibraryScannerDidFinishNotification object:nil];
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
	_tableView.backgroundColor = [UIColor blackColor];
	_tableView.separatorColor = [UIColor colorWithWhite:0.25f alpha:1.0f];
	_tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	[self.view addSubview:_tableView];
}

- (void)viewDidLoad {
	[super viewDidLoad];
	_gridToggleButton = [[UIBarButtonItem alloc] initWithTitle:@"Grid" style:UIBarButtonItemStyleBordered target:self action:@selector(toggleAlbumsGridTapped)];
	[self updateGridToggleButtonVisibility];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[self ensureCurrentModeLoaded];
}

- (void)modeChanged {
	[self updateGridToggleButtonVisibility];
	[self ensureCurrentModeLoaded];
	[_tableView reloadData];
}

- (void)updateGridToggleButtonVisibility {
	BOOL onAlbums = (_modeControl.selectedSegmentIndex == LTLibraryModeAlbums);
	self.navigationItem.rightBarButtonItem = onAlbums ? _gridToggleButton : nil;
	_gridToggleButton.title = _albumsGridEnabled ? @"List" : @"Grid";
}

- (void)toggleAlbumsGridTapped {
	_albumsGridEnabled = !_albumsGridEnabled;
	[self updateGridToggleButtonVisibility];
	[self ensureCurrentModeLoaded];
	[_tableView reloadData];
}

- (void)scannerDidFinish:(NSNotification *)notification {
	[_groupedTitlesCache removeAllObjects];
	[_albumSummaries release];
	_albumSummaries = nil;
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
	} else if (_modeControl.selectedSegmentIndex == LTLibraryModeAlbums && _albumsGridEnabled) {
		[self loadAlbumSummariesIfNeeded];
	} else {
		[self loadGroupedTitlesForCurrentModeIfNeeded];
	}
}

- (NSArray *)cachedGroupedTitlesForCurrentMode {
	return [_groupedTitlesCache objectForKey:[NSNumber numberWithInteger:_modeControl.selectedSegmentIndex]];
}

- (void)loadGroupedTitlesForCurrentModeIfNeeded {
	NSNumber *modeKey = [NSNumber numberWithInteger:_modeControl.selectedSegmentIndex];
	if ([_groupedTitlesCache objectForKey:modeKey] != nil) return;

	NSString *column = nil;
	switch (_modeControl.selectedSegmentIndex) {
		case LTLibraryModeArtists: column = @"artist"; break;
		case LTLibraryModeAlbums:  column = @"album";  break;
		case LTLibraryModeGenres:  column = @"genre";  break;
		default: return;
	}

	NSString *sql = [NSString stringWithFormat:@"SELECT DISTINCT %@ FROM songs WHERE %@ != '' ORDER BY %@ COLLATE NOCASE ASC", column, column, column];
	NSArray *rows = [[LTDatabase sharedDatabase] executeQuery:sql withArguments:nil];
	NSMutableArray *titles = [NSMutableArray arrayWithCapacity:[rows count]];
	for (NSDictionary *row in rows) [titles addObject:[row objectForKey:column]];
	[_groupedTitlesCache setObject:titles forKey:modeKey];
}

- (void)loadAlbumSummariesIfNeeded {
	if (_albumSummaries != nil) return;

	// GROUP BY album (not "COLLATE NOCASE") to match the exact grouping
	// the plain Albums list uses (SELECT DISTINCT album) — keeps the grid
	// and list showing the same album boundaries. ORDER BY still uses
	// COLLATE NOCASE so alphabetical sorting reads naturally either way.
	// MIN(artist)/MAX(artwork_path) pick one representative value per
	// album group; for genuine compilations with mixed per-track artists
	// this is an approximation, not a guaranteed "correct" album artist —
	// acceptable for a browsing tile, not treated as authoritative
	// metadata anywhere else.
	NSString *sql = @"SELECT album, MIN(artist) AS artist, MAX(artwork_path) AS artwork_path "
		"FROM songs WHERE album != '' GROUP BY album ORDER BY album COLLATE NOCASE ASC";
	NSArray *rows = [[LTDatabase sharedDatabase] executeQuery:sql withArguments:nil];

	NSMutableArray *summaries = [NSMutableArray arrayWithCapacity:[rows count]];
	for (NSDictionary *row in rows) [summaries addObject:[LTAlbumSummary summaryWithRow:row]];
	_albumSummaries = [summaries retain];
}

- (void)resetSongsPaging {
	[_songsPage release];
	_songsPage = nil;
	_hasMoreSongs = YES;
	_isLoadingMoreSongs = NO;
}

- (void)loadNextSongsPage {
	if (_isLoadingMoreSongs || !_hasMoreSongs) return;
	_isLoadingMoreSongs = YES;
	if (_songsPage == nil) _songsPage = [[NSMutableArray alloc] init];

	NSUInteger offset = [_songsPage count];
	NSArray *args = [NSArray arrayWithObjects:[NSNumber numberWithUnsignedInteger:kLTSongsPageSize], [NSNumber numberWithUnsignedInteger:offset], nil];
	NSArray *rows = [[LTDatabase sharedDatabase] executeQuery:@"SELECT * FROM songs ORDER BY title COLLATE NOCASE ASC LIMIT ? OFFSET ?" withArguments:args];
	for (NSDictionary *row in rows) [_songsPage addObject:[LTSong songWithRow:row]];

	_hasMoreSongs = ([rows count] == kLTSongsPageSize);
	_isLoadingMoreSongs = NO;
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	if (_modeControl.selectedSegmentIndex == LTLibraryModeSongs) return [_songsPage count];
	if (_modeControl.selectedSegmentIndex == LTLibraryModeAlbums && _albumsGridEnabled) {
		NSUInteger albumCount = [_albumSummaries count];
		return (albumCount + kLTAlbumGridColumns - 1) / kLTAlbumGridColumns; // ceil division
	}
	return [[self cachedGroupedTitlesForCurrentMode] count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	if (_modeControl.selectedSegmentIndex == LTLibraryModeAlbums && _albumsGridEnabled) {
		LTAlbumGridRowCell *gridCell = (LTAlbumGridRowCell *)[tableView dequeueReusableCellWithIdentifier:kLTGridRowCellIdentifier];
		if (gridCell == nil) {
			gridCell = [[[LTAlbumGridRowCell alloc] initWithReuseIdentifier:kLTGridRowCellIdentifier width:tableView.bounds.size.width] autorelease];
		}

		NSUInteger startingFlatIndex = indexPath.row * kLTAlbumGridColumns;
		NSUInteger endIndex = MIN(startingFlatIndex + kLTAlbumGridColumns, [_albumSummaries count]);
		NSArray *rowSummaries = [_albumSummaries subarrayWithRange:NSMakeRange(startingFlatIndex, endIndex - startingFlatIndex)];

		[gridCell configureWithSummaries:rowSummaries startingFlatIndex:startingFlatIndex target:self action:@selector(albumTileTapped:)];
		return gridCell;
	}

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

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	if (_modeControl.selectedSegmentIndex == LTLibraryModeAlbums && _albumsGridEnabled) {
		return LTAlbumGridRowHeightForWidth(tableView.bounds.size.width);
	}
	return 44.0f; // UITableView's own default — explicit here since implementing this delegate method at all overrides the implicit default for every row, not just grid rows.
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
	if (_modeControl.selectedSegmentIndex != LTLibraryModeSongs) return;
	if (!_hasMoreSongs || _isLoadingMoreSongs) return;

	NSUInteger loadedCount = [_songsPage count];
	if (indexPath.row + kLTSongsPrefetchThreshold >= loadedCount) {
		NSUInteger countBefore = loadedCount;
		[self loadNextSongsPage];
		NSUInteger countAfter = [_songsPage count];
		if (countAfter > countBefore) {
			NSMutableArray *newIndexPaths = [NSMutableArray arrayWithCapacity:(countAfter - countBefore)];
			for (NSUInteger i = countBefore; i < countAfter; i++) [newIndexPaths addObject:[NSIndexPath indexPathForRow:i inSection:0]];
			[tableView insertRowsAtIndexPaths:newIndexPaths withRowAnimation:UITableViewRowAnimationNone];
		}
	}
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:YES];

	if (_modeControl.selectedSegmentIndex == LTLibraryModeAlbums && _albumsGridEnabled) {
		return; // grid tiles handle their own taps via -albumTileTapped:, not row selection
	}
	if (_modeControl.selectedSegmentIndex == LTLibraryModeSongs) {
		// Queue is whatever's currently loaded in _songsPage (this mode is
		// paginated — see the class header). Skipping past the last
		// loaded song won't reach further into the library until more
		// pages have been scrolled into view. Acceptable tradeoff here:
		// Songs mode is a browse-everything utility view, not the
		// primary way most taps build a queue (Search results and
		// album/artist/genre-filtered lists are naturally bounded and
		// don't hit this at all).
		[[LTPlaybackController sharedController] playSongs:_songsPage startingAtIndex:indexPath.row];
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
	LTSongListViewController *songList = [[LTSongListViewController alloc] initWithFilterColumn:filterColumn value:filterValue title:filterValue];
	[self.navigationController pushViewController:songList animated:YES];
	[songList release];
}

- (void)albumTileTapped:(id)sender {
	NSUInteger flatIndex = [sender tag];
	if (flatIndex >= [_albumSummaries count]) return;

	LTAlbumSummary *summary = [_albumSummaries objectAtIndex:flatIndex];
	LTSongListViewController *songList = [[LTSongListViewController alloc] initWithFilterColumn:@"album" value:summary.album title:summary.album];
	[self.navigationController pushViewController:songList animated:YES];
	[songList release];
}

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[_modeControl release];
	[_tableView release];
	[_groupedTitlesCache release];
	[_songsPage release];
	[_albumSummaries release];
	[_gridToggleButton release];
	[super dealloc];
}

@end
