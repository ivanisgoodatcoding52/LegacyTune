#import "LTSearchViewController.h"
#import "LTDatabase.h"
#import "LTSong.h"

static const NSTimeInterval kLTSearchDebounceInterval = 0.25;
static const NSUInteger kLTSearchResultLimit = 100;

@interface LTSearchViewController (Private)
- (void)searchTextChanged;
- (void)runSearchJob:(NSDictionary *)job;
- (void)deliverResults:(NSDictionary *)payload;
- (void)updateEmptyState;
@end

@implementation LTSearchViewController

- (id)init {
	self = [super init];
	if (self) {
		self.title = @"Search";
	}
	return self;
}

- (void)loadView {
	CGRect frame = [[UIScreen mainScreen] applicationFrame];
	self.view = [[[UIView alloc] initWithFrame:frame] autorelease];
	self.view.backgroundColor = [UIColor blackColor];

	_searchBar = [[UISearchBar alloc] initWithFrame:CGRectMake(0, 0, frame.size.width, 44)];
	_searchBar.delegate = self;
	_searchBar.placeholder = @"Songs, artists, albums, genres";
	_searchBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	[self.view addSubview:_searchBar];

	CGFloat tableY = CGRectGetMaxY(_searchBar.frame);
	CGRect contentFrame = CGRectMake(0, tableY, frame.size.width, frame.size.height - tableY);

	_tableView = [[UITableView alloc] initWithFrame:contentFrame style:UITableViewStylePlain];
	_tableView.dataSource = self;
	_tableView.delegate = self;
	_tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	[self.view addSubview:_tableView];

	_emptyStateLabel = [[UILabel alloc] initWithFrame:CGRectInset(contentFrame, 24, 24)];
	_emptyStateLabel.text = @"Search your library — type at least 2 characters.";
	_emptyStateLabel.textColor = [UIColor grayColor];
	_emptyStateLabel.font = [UIFont systemFontOfSize:14];
	_emptyStateLabel.textAlignment = UITextAlignmentCenter;
	_emptyStateLabel.numberOfLines = 0;
	_emptyStateLabel.backgroundColor = [UIColor clearColor];
	_emptyStateLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	[self.view addSubview:_emptyStateLabel];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[self updateEmptyState];
}

#pragma mark - UISearchBarDelegate

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
	// Debounce: reset the timer on every keystroke so a query only fires
	// once typing pauses, instead of once per character.
	[_debounceTimer invalidate];
	_debounceTimer = [NSTimer scheduledTimerWithTimeInterval:kLTSearchDebounceInterval
		target:self selector:@selector(searchTextChanged) userInfo:nil repeats:NO];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
	[searchBar resignFirstResponder];
	[_debounceTimer invalidate];
	[self searchTextChanged];
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar {
	searchBar.text = @"";
	[searchBar resignFirstResponder];
	[_debounceTimer invalidate];
	[_results release];
	_results = nil;
	[_tableView reloadData];
	[self updateEmptyState];
}

- (void)searchTextChanged {
	NSString *queryText = [_searchBar.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

	if ([queryText length] < 2) {
		[_results release];
		_results = nil;
		[_tableView reloadData];
		[self updateEmptyState];
		return;
	}

	// Bump the generation before dispatching so a stale in-flight search
	// (from an earlier keystroke) can recognize itself as superseded when
	// it eventually calls back to -deliverResults:.
	_searchGeneration++;
	NSDictionary *job = [NSDictionary dictionaryWithObjectsAndKeys:
		queryText, @"query",
		[NSNumber numberWithUnsignedInteger:_searchGeneration], @"generation",
		nil];

	[NSThread detachNewThreadSelector:@selector(runSearchJob:) toTarget:self withObject:job];
}

// Runs entirely off the main thread on its own LTDatabase connection —
// same pattern as LTLibraryScanner. Typing never waits on SQLite here.
- (void)runSearchJob:(NSDictionary *)job {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

	NSString *queryText = [job objectForKey:@"query"];
	NSNumber *generation = [job objectForKey:@"generation"];

	LTDatabase *backgroundDB = [[LTDatabase alloc] init];
	[backgroundDB open];

	NSString *likePattern = [NSString stringWithFormat:@"%%%@%%", queryText];
	// Leading wildcard means this can't use the NOCASE indexes for the
	// match itself (only a prefix search could) — it's a scan under the
	// hood. Bounded by LIMIT and run off-thread, which is the right
	// tradeoff for "instant search" at realistic library sizes on this
	// hardware, rather than depending on FTS support this SDK's bundled
	// sqlite3 build may or may not reliably have.
	NSString *sql = @"SELECT * FROM songs WHERE title LIKE ? OR artist LIKE ? OR album LIKE ? OR genre LIKE ? "
		"ORDER BY title COLLATE NOCASE ASC LIMIT ?";
	NSArray *args = [NSArray arrayWithObjects:
		likePattern, likePattern, likePattern, likePattern,
		[NSNumber numberWithUnsignedInteger:kLTSearchResultLimit], nil];

	NSArray *rows = [backgroundDB executeQuery:sql withArguments:args];

	NSMutableArray *songs = [NSMutableArray arrayWithCapacity:[rows count]];
	for (NSDictionary *row in rows) {
		[songs addObject:[LTSong songWithRow:row]];
	}

	[backgroundDB close];
	[backgroundDB release];

	NSDictionary *payload = [NSDictionary dictionaryWithObjectsAndKeys:
		songs, @"results",
		generation, @"generation",
		nil];

	[self performSelectorOnMainThread:@selector(deliverResults:) withObject:payload waitUntilDone:NO];

	[pool release];
}

- (void)deliverResults:(NSDictionary *)payload {
	NSNumber *resultGeneration = [payload objectForKey:@"generation"];
	if ([resultGeneration unsignedIntegerValue] != _searchGeneration) {
		return; // a newer search superseded this one while it was running — discard
	}

	[_results release];
	_results = [[payload objectForKey:@"results"] retain];
	[_tableView reloadData];
	[self updateEmptyState];
}

- (void)updateEmptyState {
	BOOL showEmptyState = ([_results count] == 0);
	_emptyStateLabel.hidden = !showEmptyState;

	if (_results != nil) {
		_emptyStateLabel.text = @"No matches.";
	} else {
		_emptyStateLabel.text = @"Search your library — type at least 2 characters.";
	}
}

#pragma mark - UITableViewDataSource / Delegate

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return [_results count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	static NSString *cellIdentifier = @"LTSearchResultCell";
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
	if (cell == nil) {
		cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellIdentifier] autorelease];
		cell.textLabel.textColor = [UIColor whiteColor];
		cell.detailTextLabel.textColor = [UIColor lightGrayColor];
		cell.backgroundColor = [UIColor blackColor];
	}

	LTSong *song = [_results objectAtIndex:indexPath.row];
	cell.textLabel.text = song.title;
	cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ — %@", song.artist, song.album];

	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	[_searchBar resignFirstResponder];
	// TODO: hand off to the playback engine once it exists.
}

- (void)dealloc {
	[_debounceTimer invalidate];
	[_searchBar release];
	[_tableView release];
	[_emptyStateLabel release];
	[_results release];
	[super dealloc];
}

@end
