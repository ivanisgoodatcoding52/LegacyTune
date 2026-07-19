#import "LTPlaylistStore.h"
#import "LTDatabase.h"

@implementation LTPlaylistStore

static LTPlaylistStore *_sharedStore = nil;

+ (LTPlaylistStore *)sharedStore {
	if (_sharedStore == nil) {
		_sharedStore = [[LTPlaylistStore alloc] init];
	}
	return _sharedStore;
}

- (NSArray *)allPlaylists {
	NSArray *rows = [[LTDatabase sharedDatabase] executeQuery:@"SELECT * FROM playlists ORDER BY sort_order ASC, id ASC" withArguments:nil];

	NSMutableArray *playlists = [NSMutableArray arrayWithCapacity:[rows count]];
	for (NSDictionary *row in rows) {
		[playlists addObject:[LTPlaylist playlistWithRow:row]];
	}
	return playlists;
}

- (LTPlaylist *)createPlaylistWithName:(NSString *)name {
	LTDatabase *db = [LTDatabase sharedDatabase];

	NSInteger nextSort = 0;
	NSArray *maxRows = [db executeQuery:@"SELECT MAX(sort_order) AS maxSort FROM playlists" withArguments:nil];
	if ([maxRows count] > 0) {
		id maxSort = [[maxRows objectAtIndex:0] objectForKey:@"maxSort"];
		if ([maxSort isKindOfClass:[NSNumber class]]) {
			nextSort = [maxSort integerValue] + 1;
		}
	}

	NSNumber *now = [NSNumber numberWithDouble:[[NSDate date] timeIntervalSince1970]];
	[db executeUpdate:@"INSERT INTO playlists (name, date_created, sort_order) VALUES (?, ?, ?)"
		withArguments:[NSArray arrayWithObjects:name, now, [NSNumber numberWithInteger:nextSort], nil]];

	NSNumber *newId = [NSNumber numberWithLongLong:[db lastInsertRowId]];
	NSArray *rows = [db executeQuery:@"SELECT * FROM playlists WHERE id = ?" withArguments:[NSArray arrayWithObject:newId]];

	return [rows count] > 0 ? [LTPlaylist playlistWithRow:[rows objectAtIndex:0]] : nil;
}

- (void)renamePlaylist:(LTPlaylist *)playlist to:(NSString *)newName {
	[[LTDatabase sharedDatabase] executeUpdate:@"UPDATE playlists SET name = ? WHERE id = ?"
		withArguments:[NSArray arrayWithObjects:newName, [NSNumber numberWithInteger:playlist.playlistId], nil]];
	playlist.name = newName;
}

- (void)deletePlaylist:(LTPlaylist *)playlist {
	LTDatabase *db = [LTDatabase sharedDatabase];
	NSArray *args = [NSArray arrayWithObject:[NSNumber numberWithInteger:playlist.playlistId]];

	// ON DELETE CASCADE (with PRAGMA foreign_keys ON, set in LTDatabase
	// -open) already covers this, but deleting explicitly first is cheap
	// insurance against ever forgetting to enable that pragma later.
	[db executeUpdate:@"DELETE FROM playlist_items WHERE playlist_id = ?" withArguments:args];
	[db executeUpdate:@"DELETE FROM playlists WHERE id = ?" withArguments:args];
}

- (NSArray *)songsInPlaylist:(LTPlaylist *)playlist {
	NSString *sql = @"SELECT songs.* FROM songs "
		"INNER JOIN playlist_items ON playlist_items.song_id = songs.id "
		"WHERE playlist_items.playlist_id = ? "
		"ORDER BY playlist_items.sort_order ASC";

	NSArray *rows = [[LTDatabase sharedDatabase] executeQuery:sql
		withArguments:[NSArray arrayWithObject:[NSNumber numberWithInteger:playlist.playlistId]]];

	NSMutableArray *songs = [NSMutableArray arrayWithCapacity:[rows count]];
	for (NSDictionary *row in rows) {
		[songs addObject:[LTSong songWithRow:row]];
	}
	return songs;
}

- (void)addSong:(LTSong *)song toPlaylist:(LTPlaylist *)playlist {
	LTDatabase *db = [LTDatabase sharedDatabase];

	NSInteger nextSort = 0;
	NSArray *maxRows = [db executeQuery:@"SELECT MAX(sort_order) AS maxSort FROM playlist_items WHERE playlist_id = ?"
		withArguments:[NSArray arrayWithObject:[NSNumber numberWithInteger:playlist.playlistId]]];
	if ([maxRows count] > 0) {
		id maxSort = [[maxRows objectAtIndex:0] objectForKey:@"maxSort"];
		if ([maxSort isKindOfClass:[NSNumber class]]) {
			nextSort = [maxSort integerValue] + 1;
		}
	}

	[db executeUpdate:@"INSERT INTO playlist_items (playlist_id, song_id, sort_order) VALUES (?, ?, ?)"
		withArguments:[NSArray arrayWithObjects:
			[NSNumber numberWithInteger:playlist.playlistId],
			[NSNumber numberWithInteger:song.songId],
			[NSNumber numberWithInteger:nextSort],
			nil]];
}

- (void)removeSongAtIndex:(NSUInteger)index fromPlaylist:(LTPlaylist *)playlist {
	NSArray *songs = [self songsInPlaylist:playlist]; // re-fetch: authoritative sort_order-based ordering
	if (index >= [songs count]) {
		return;
	}
	LTSong *song = [songs objectAtIndex:index];

	[[LTDatabase sharedDatabase] executeUpdate:@"DELETE FROM playlist_items WHERE playlist_id = ? AND song_id = ?"
		withArguments:[NSArray arrayWithObjects:
			[NSNumber numberWithInteger:playlist.playlistId],
			[NSNumber numberWithInteger:song.songId],
			nil]];
}

- (void)moveSongInPlaylist:(LTPlaylist *)playlist fromIndex:(NSUInteger)from toIndex:(NSUInteger)to {
	if (from == to) {
		return;
	}

	LTDatabase *db = [LTDatabase sharedDatabase];
	NSArray *rows = [db executeQuery:@"SELECT id FROM playlist_items WHERE playlist_id = ? ORDER BY sort_order ASC"
		withArguments:[NSArray arrayWithObject:[NSNumber numberWithInteger:playlist.playlistId]]];

	if (from >= [rows count] || to >= [rows count]) {
		return;
	}

	NSMutableArray *mutableRows = [NSMutableArray arrayWithArray:rows];
	NSDictionary *moved = [mutableRows objectAtIndex:from];
	[mutableRows removeObjectAtIndex:from];
	[mutableRows insertObject:moved atIndex:to];

	// Simplest correct approach at this data scale: rewrite every
	// sort_order value for the playlist. Fine for realistic playlist
	// sizes; would want a smarter partial-renumbering scheme if playlists
	// grow into the thousands of tracks. Wrapped in a transaction so N
	// UPDATEs cost one fsync instead of N (same principle as the library
	// scanner's batch upsert).
	[db beginTransaction];
	NSInteger sortOrder = 0;
	for (NSDictionary *row in mutableRows) {
		[db executeUpdate:@"UPDATE playlist_items SET sort_order = ? WHERE id = ?"
			withArguments:[NSArray arrayWithObjects:
				[NSNumber numberWithInteger:sortOrder],
				[row objectForKey:@"id"],
				nil]];
		sortOrder++;
	}
	[db commitTransaction];
}

@end
