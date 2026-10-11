#import "LTHomeViewController.h"
#import "LTHomeStore.h"
#import "LTHomeModels.h"
#import "LTHomeSectionCell.h"
#import "LTAlbumSummary.h"
#import "LTLibraryScanner.h"
#import "LTSongListViewController.h"
#import "LTFavoritesManagerViewController.h"

static NSString *const kLTHomeSectionCellIdentifier = @"LTHomeSectionCell";
static const NSUInteger kLTRecentlyAddedLimit = 20;

@interface LTHomeViewController (Private)
- (NSString *)greetingText;
- (void)reload;
- (NSArray *)favoritesCardData;
- (NSArray *)recentlyAddedCardData;
- (NSArray *)recentlyPlayedCardData;
- (NSArray *)albumCardDataFromSummaries:(NSArray *)albums;
- (void)favoriteTileTapped:(id)sender;
- (void)albumTileTapped:(id)sender;
- (void)recentlyPlayedTileTapped:(id)sender;
- (void)pushAlbumAtIndex:(NSUInteger)index fromAlbums:(NSArray *)albums;
- (void)manageFavoritesTapped;
- (void)scannerDidFinish:(NSNotification *)notification;
@end

@implementation LTHomeViewController

- (id)init {
	self = [super init];
	if (self) {
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(scannerDidFinish:) name:LTLibraryScannerDidFinishNotification object:nil];
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
	_tableView.backgroundColor = [UIColor blackColor];
	_tableView.separatorStyle = UITableViewCellSeparatorStyleNone; // sections have their own visual spacing already
	_tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	[self.view addSubview:_tableView];
}

- (void)viewDidLoad {
	[super viewDidLoad];
	// Home is the ROOT of its tab — safe to use leftBarButtonItem here,
	// no automatic Back button to lose (unlike the pushed screens this
	// tab leads to).
	self.navigationItem.leftBarButtonItem = self.editButtonItem;
}

- (void)setEditing:(BOOL)editing animated:(BOOL)animated {
	[super setEditing:editing animated:animated];
	[_tableView setEditing:editing animated:animated];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	self.title = [self greetingText];
	[self reload];
}

- (void)scannerDidFinish:(NSNotification *)notification {
	[self reload]; // Recently Added content may have changed
}

- (void)reload {
	// Recently Played stays out of the list until something has actually
	// been played, rather than showing as an empty strip.
	BOOL hasPlayHistory = ([[[LTHomeStore sharedStore] recentlyPlayedAlbumsWithLimit:1] count] > 0);
	NSMutableArray *visible = [NSMutableArray array];
	for (LTHomeSection *section in [[LTHomeStore sharedStore] sectionsOrdered]) {
		if (!hasPlayHistory && [section.sectionKey isEqualToString:@"recently_played"]) continue;
		[visible addObject:section];
	}
	[_sections release];
	_sections = [visible retain];
	[_tableView reloadData];
}

- (NSString *)greetingText {
	NSCalendar *calendar = [NSCalendar currentCalendar];
	NSDateComponents *components = [calendar components:NSHourCalendarUnit fromDate:[NSDate date]];
	NSInteger hour = [components hour];
	if (hour < 12) return @"Good morning";
	if (hour < 18) return @"Good afternoon";
	return @"Good evening";
}

#pragma mark - Card data (converts model objects into the plain-dictionary shape LTHomeSectionCell expects)

- (NSArray *)favoritesCardData {
	NSArray *favorites = [[LTHomeStore sharedStore] favoritesOrdered];
	NSMutableArray *cardData = [NSMutableArray arrayWithCapacity:[favorites count]];
	for (LTHomeFavorite *favorite in favorites) {
		NSDictionary *card = [NSDictionary dictionaryWithObjectsAndKeys:
			favorite.title, @"title",
			favorite.subtitle, @"subtitle",
			(favorite.artworkPath ?: (id)[NSNull null]), @"artworkPath",
			nil];
		[cardData addObject:card];
	}
	return cardData;
}

- (NSArray *)albumCardDataFromSummaries:(NSArray *)albums {
	NSMutableArray *cardData = [NSMutableArray arrayWithCapacity:[albums count]];
	for (LTAlbumSummary *summary in albums) {
		NSDictionary *card = [NSDictionary dictionaryWithObjectsAndKeys:
			summary.album, @"title",
			summary.artist, @"subtitle",
			(summary.artworkPath ?: (id)[NSNull null]), @"artworkPath",
			nil];
		[cardData addObject:card];
	}
	return cardData;
}

- (NSArray *)recentlyAddedCardData {
	return [self albumCardDataFromSummaries:[[LTHomeStore sharedStore] recentlyAddedAlbumsWithLimit:kLTRecentlyAddedLimit]];
}

- (NSArray *)recentlyPlayedCardData {
	return [self albumCardDataFromSummaries:[[LTHomeStore sharedStore] recentlyPlayedAlbumsWithLimit:kLTRecentlyAddedLimit]];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return [_sections count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	LTHomeSection *section = [_sections objectAtIndex:indexPath.row];

	LTHomeSectionCell *cell = (LTHomeSectionCell *)[tableView dequeueReusableCellWithIdentifier:kLTHomeSectionCellIdentifier];
	if (cell == nil) {
		cell = [[[LTHomeSectionCell alloc] initWithReuseIdentifier:kLTHomeSectionCellIdentifier] autorelease];
	}

	BOOL isFavorites = [section.sectionKey isEqualToString:@"favorites"];
	if (isFavorites) {
		[cell configureWithTitle:section.displayTitle cardData:[self favoritesCardData]
			target:self action:@selector(favoriteTileTapped:)
			titleTarget:self titleAction:@selector(manageFavoritesTapped)];
	} else if ([section.sectionKey isEqualToString:@"recently_played"]) {
		[cell configureWithTitle:section.displayTitle cardData:[self recentlyPlayedCardData]
			target:self action:@selector(recentlyPlayedTileTapped:)
			titleTarget:nil titleAction:NULL];
	} else {
		[cell configureWithTitle:section.displayTitle cardData:[self recentlyAddedCardData]
			target:self action:@selector(albumTileTapped:)
			titleTarget:nil titleAction:NULL];
	}

	return cell;
}

#pragma mark - UITableViewDelegate

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	return LTHomeSectionCellHeight();
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
	return NO; // reorder only — no swipe-to-delete/hide in this pass's scope
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
	return YES;
}

- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)sourceIndexPath toIndexPath:(NSIndexPath *)destinationIndexPath {
	// _sections may omit a hidden section (Recently Played with no history),
	// so translate visible row indices into positions in the full stored
	// order by section key before telling the store.
	NSArray *allSections = [[LTHomeStore sharedStore] sectionsOrdered];
	NSString *movedKey = [(LTHomeSection *)[_sections objectAtIndex:sourceIndexPath.row] sectionKey];
	NSString *destKey = [(LTHomeSection *)[_sections objectAtIndex:destinationIndexPath.row] sectionKey];
	NSUInteger fullFrom = NSNotFound, fullTo = NSNotFound;
	for (NSUInteger i = 0; i < [allSections count]; i++) {
		NSString *key = [(LTHomeSection *)[allSections objectAtIndex:i] sectionKey];
		if ([key isEqualToString:movedKey]) fullFrom = i;
		if ([key isEqualToString:destKey]) fullTo = i;
	}
	if (fullFrom != NSNotFound && fullTo != NSNotFound) {
		[[LTHomeStore sharedStore] moveSectionFromIndex:fullFrom toIndex:fullTo];
	}

	LTHomeSection *moved = [[_sections objectAtIndex:sourceIndexPath.row] retain];
	[_sections removeObjectAtIndex:sourceIndexPath.row];
	[_sections insertObject:moved atIndex:destinationIndexPath.row];
	[moved release];
}

#pragma mark - Actions

- (void)favoriteTileTapped:(id)sender {
	NSUInteger index = [sender tag];
	NSArray *favorites = [[LTHomeStore sharedStore] favoritesOrdered];
	if (index >= [favorites count]) return;

	LTHomeFavorite *favorite = [favorites objectAtIndex:index];
	LTSongListViewController *songList = [[LTSongListViewController alloc]
		initWithFilterColumn:favorite.itemType value:favorite.itemKey title:favorite.title];
	[self.navigationController pushViewController:songList animated:YES];
	[songList release];
}

- (void)pushAlbumAtIndex:(NSUInteger)index fromAlbums:(NSArray *)albums {
	if (index >= [albums count]) return;

	LTAlbumSummary *summary = [albums objectAtIndex:index];
	LTSongListViewController *songList = [[LTSongListViewController alloc]
		initWithFilterColumn:@"album" value:summary.album title:summary.album];
	[self.navigationController pushViewController:songList animated:YES];
	[songList release];
}

- (void)albumTileTapped:(id)sender {
	[self pushAlbumAtIndex:[sender tag] fromAlbums:[[LTHomeStore sharedStore] recentlyAddedAlbumsWithLimit:kLTRecentlyAddedLimit]];
}

- (void)recentlyPlayedTileTapped:(id)sender {
	[self pushAlbumAtIndex:[sender tag] fromAlbums:[[LTHomeStore sharedStore] recentlyPlayedAlbumsWithLimit:kLTRecentlyAddedLimit]];
}

- (void)manageFavoritesTapped {
	LTFavoritesManagerViewController *manage = [[LTFavoritesManagerViewController alloc] init];
	[self.navigationController pushViewController:manage animated:YES];
	[manage release];
}

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[_tableView release];
	[_sections release];
	[super dealloc];
}

@end
