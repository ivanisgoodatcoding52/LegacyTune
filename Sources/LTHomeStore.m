#import "LTHomeStore.h"
#import "LTDatabase.h"

@implementation LTHomeStore

static LTHomeStore *_sharedStore = nil;

+ (LTHomeStore *)sharedStore {
	if (_sharedStore == nil) _sharedStore = [[LTHomeStore alloc] init];
	return _sharedStore;
}

#pragma mark - Sections

- (NSArray *)sectionsOrdered {
	NSArray *rows = [[LTDatabase sharedDatabase] executeQuery:@"SELECT * FROM home_sections ORDER BY sort_order ASC" withArguments:nil];
	NSMutableArray *sections = [NSMutableArray arrayWithCapacity:[rows count]];
	for (NSDictionary *row in rows) [sections addObject:[LTHomeSection sectionWithRow:row]];
	return sections;
}

- (void)moveSectionFromIndex:(NSUInteger)from toIndex:(NSUInteger)to {
	if (from == to) return;
	LTDatabase *db = [LTDatabase sharedDatabase];
	NSArray *rows = [db executeQuery:@"SELECT id FROM home_sections ORDER BY sort_order ASC" withArguments:nil];
	if (from >= [rows count] || to >= [rows count]) return;

	NSMutableArray *mutableRows = [NSMutableArray arrayWithArray:rows];
	NSDictionary *moved = [mutableRows objectAtIndex:from];
	[mutableRows removeObjectAtIndex:from];
	[mutableRows insertObject:moved atIndex:to];

	// Same rewrite-all-sort-orders-in-one-transaction pattern used for
	// playlist song reordering — fine at this scale (2 rows today).
	[db beginTransaction];
	NSInteger sortOrder = 0;
	for (NSDictionary *row in mutableRows) {
		[db executeUpdate:@"UPDATE home_sections SET sort_order = ? WHERE id = ?"
			withArguments:[NSArray arrayWithObjects:[NSNumber numberWithInteger:sortOrder], [row objectForKey:@"id"], nil]];
		sortOrder++;
	}
	[db commitTransaction];
}

#pragma mark - Favorites

- (NSArray *)favoritesOrdered {
	NSArray *rows = [[LTDatabase sharedDatabase] executeQuery:@"SELECT * FROM home_favorites ORDER BY sort_order ASC" withArguments:nil];
	NSMutableArray *favorites = [NSMutableArray arrayWithCapacity:[rows count]];
	for (NSDictionary *row in rows) [favorites addObject:[LTHomeFavorite favoriteWithRow:row]];
	return favorites;
}

- (void)addFavoriteWithType:(NSString *)itemType key:(NSString *)itemKey {
	LTDatabase *db = [LTDatabase sharedDatabase];

	NSString *title = itemKey;
	NSString *subtitle = nil;
	NSString *artworkPath = nil;

	if ([itemType isEqualToString:@"artist"]) {
		subtitle = @"Artist";
		NSArray *rows = [db executeQuery:@"SELECT MAX(artwork_path) AS artwork_path FROM songs WHERE artist = ?" withArguments:[NSArray arrayWithObject:itemKey]];
		if ([rows count] > 0) {
			id path = [[rows objectAtIndex:0] objectForKey:@"artwork_path"];
			artworkPath = [path isKindOfClass:[NSString class]] ? path : nil;
		}
	} else if ([itemType isEqualToString:@"album"]) {
		NSArray *rows = [db executeQuery:@"SELECT MIN(artist) AS artist, MAX(artwork_path) AS artwork_path FROM songs WHERE album = ?" withArguments:[NSArray arrayWithObject:itemKey]];
		if ([rows count] > 0) {
			NSDictionary *row = [rows objectAtIndex:0];
			subtitle = [row objectForKey:@"artist"];
			id path = [row objectForKey:@"artwork_path"];
			artworkPath = [path isKindOfClass:[NSString class]] ? path : nil;
		}
	} else {
		return; // only artist/album are supported this pass
	}

	NSInteger nextSort = 0;
	NSArray *maxRows = [db executeQuery:@"SELECT MAX(sort_order) AS maxSort FROM home_favorites" withArguments:nil];
	if ([maxRows count] > 0) {
		id maxSort = [[maxRows objectAtIndex:0] objectForKey:@"maxSort"];
		if ([maxSort isKindOfClass:[NSNumber class]]) nextSort = [maxSort integerValue] + 1;
	}

	[db executeUpdate:@"INSERT INTO home_favorites (item_type, item_key, title, subtitle, artwork_path, sort_order, date_added) VALUES (?, ?, ?, ?, ?, ?, ?)"
		withArguments:[NSArray arrayWithObjects:
			itemType, itemKey, title, (subtitle ?: @""),
			(artworkPath ?: (id)[NSNull null]),
			[NSNumber numberWithInteger:nextSort],
			[NSNumber numberWithDouble:[[NSDate date] timeIntervalSince1970]],
			nil]];
}

- (void)removeFavorite:(LTHomeFavorite *)favorite {
	[[LTDatabase sharedDatabase] executeUpdate:@"DELETE FROM home_favorites WHERE id = ?"
		withArguments:[NSArray arrayWithObject:[NSNumber numberWithInteger:favorite.favoriteId]]];
}

#pragma mark - Recently Added

- (NSArray *)recentlyAddedAlbumsWithLimit:(NSUInteger)limit {
	// Same grouping convention as the Library album grid (GROUP BY album,
	// not COLLATE NOCASE) so both views agree on album boundaries.
	NSString *sql = @"SELECT album, MIN(artist) AS artist, MAX(artwork_path) AS artwork_path, MAX(date_added) AS latest_added "
		"FROM songs WHERE album != '' GROUP BY album ORDER BY latest_added DESC LIMIT ?";
	NSArray *rows = [[LTDatabase sharedDatabase] executeQuery:sql withArguments:[NSArray arrayWithObject:[NSNumber numberWithUnsignedInteger:limit]]];

	NSMutableArray *summaries = [NSMutableArray arrayWithCapacity:[rows count]];
	for (NSDictionary *row in rows) [summaries addObject:[LTAlbumSummary summaryWithRow:row]];
	return summaries;
}

@end
