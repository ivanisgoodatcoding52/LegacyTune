#import "LTDatabase.h"
#import <string.h>

#ifndef SQLITE_TRANSIENT
#define SQLITE_TRANSIENT ((sqlite3_destructor_type)-1)
#endif

static NSString *const kLTDatabaseFileName = @"LegacyTune.sqlite";

static NSString *const kLTSchemaSQL =
	@"CREATE TABLE IF NOT EXISTS songs ("
	"  id INTEGER PRIMARY KEY AUTOINCREMENT,"
	"  persistent_id TEXT UNIQUE,"
	"  title TEXT NOT NULL DEFAULT '',"
	"  artist TEXT NOT NULL DEFAULT '',"
	"  album TEXT NOT NULL DEFAULT '',"
	"  genre TEXT NOT NULL DEFAULT '',"
	"  track_number INTEGER DEFAULT 0,"
	"  disc_number INTEGER DEFAULT 0,"
	"  duration REAL DEFAULT 0,"
	"  artwork_path TEXT,"
	"  date_added REAL DEFAULT 0,"
	"  play_count INTEGER DEFAULT 0,"
	"  skip_count INTEGER DEFAULT 0,"
	"  last_played REAL DEFAULT 0,"
	"  favorite INTEGER DEFAULT 0,"
	"  rating INTEGER DEFAULT 0"
	");"
	"CREATE INDEX IF NOT EXISTS idx_songs_artist_nocase ON songs(artist COLLATE NOCASE);"
	"CREATE INDEX IF NOT EXISTS idx_songs_album_nocase ON songs(album COLLATE NOCASE);"
	"CREATE INDEX IF NOT EXISTS idx_songs_genre_nocase ON songs(genre COLLATE NOCASE);"
	"CREATE INDEX IF NOT EXISTS idx_songs_title_nocase ON songs(title COLLATE NOCASE);"
	"CREATE TABLE IF NOT EXISTS playlists ("
	"  id INTEGER PRIMARY KEY AUTOINCREMENT,"
	"  name TEXT NOT NULL,"
	"  date_created REAL DEFAULT 0,"
	"  sort_order INTEGER DEFAULT 0"
	");"
	"CREATE TABLE IF NOT EXISTS playlist_items ("
	"  id INTEGER PRIMARY KEY AUTOINCREMENT,"
	"  playlist_id INTEGER NOT NULL,"
	"  song_id INTEGER NOT NULL,"
	"  sort_order INTEGER DEFAULT 0,"
	"  FOREIGN KEY(playlist_id) REFERENCES playlists(id) ON DELETE CASCADE,"
	"  FOREIGN KEY(song_id) REFERENCES songs(id) ON DELETE CASCADE"
	");"
	"CREATE INDEX IF NOT EXISTS idx_playlist_items_playlist ON playlist_items(playlist_id);"
	"CREATE TABLE IF NOT EXISTS home_sections ("
	"  id INTEGER PRIMARY KEY AUTOINCREMENT,"
	"  section_key TEXT UNIQUE NOT NULL,"
	"  sort_order INTEGER DEFAULT 0"
	");"
	"CREATE TABLE IF NOT EXISTS home_favorites ("
	"  id INTEGER PRIMARY KEY AUTOINCREMENT,"
	"  item_type TEXT NOT NULL,"   // 'artist' | 'album' | 'genre' | 'playlist'
	"  item_key TEXT NOT NULL,"    // artist/album/genre name, or playlist id (as text)
	"  title TEXT NOT NULL,"       // denormalized display snapshot — see LTHomeStore
	"  subtitle TEXT NOT NULL,"
	"  artwork_path TEXT,"
	"  sort_order INTEGER DEFAULT 0,"
	"  date_added REAL DEFAULT 0"
	");"
	;

// Home currently ships exactly two sections — Favorites (user-curated) and
// Recently Added (real data, from songs.date_added). Sections that would
// need play history (Recently Played, Top Artists/Albums by plays) are
// deliberately NOT seeded here — they get added once the playback engine
// exists and last_played/play_count carry real values, rather than
// showing as empty placeholders now.
static NSString *const kLTDefaultHomeSectionsSQL =
	@"INSERT INTO home_sections (section_key, sort_order) VALUES "
	"('favorites', 0),"
	"('recently_added', 1);"
	;

@interface LTDatabase (Private)
- (void)bindArguments:(NSArray *)args toStatement:(sqlite3_stmt *)statement;
@end

@implementation LTDatabase

static LTDatabase *_sharedDatabase = nil;

+ (LTDatabase *)sharedDatabase {
	if (_sharedDatabase == nil) {
		_sharedDatabase = [[LTDatabase alloc] init];
	}
	return _sharedDatabase;
}

- (NSString *)databasePath {
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
	return [[paths objectAtIndex:0] stringByAppendingPathComponent:kLTDatabaseFileName];
}

- (BOOL)open {
	if (_db != NULL) return YES;

	NSString *path = [self databasePath];
	if (sqlite3_open([path UTF8String], &_db) != SQLITE_OK) {
		NSLog(@"[LTDatabase] failed to open database at %@: %s", path, sqlite3_errmsg(_db));
		return NO;
	}

	sqlite3_busy_timeout(_db, 3000);
	sqlite3_exec(_db, "PRAGMA foreign_keys = ON;", NULL, NULL, NULL);
	sqlite3_exec(_db, "PRAGMA synchronous = NORMAL;", NULL, NULL, NULL);
	sqlite3_exec(_db, "PRAGMA temp_store = MEMORY;", NULL, NULL, NULL);

	char *errorMessage = NULL;
	if (sqlite3_exec(_db, [kLTSchemaSQL UTF8String], NULL, NULL, &errorMessage) != SQLITE_OK) {
		NSLog(@"[LTDatabase] failed to create schema: %s", errorMessage);
		sqlite3_free(errorMessage);
		return NO;
	}

	// Seed the default Home layout exactly once — if home_sections is
	// already populated (a prior launch already seeded it, possibly with
	// the user's own reordering/hiding since applied), leave it alone.
	NSArray *existingSections = [self executeQuery:@"SELECT COUNT(*) AS c FROM home_sections" withArguments:nil];
	NSInteger sectionCount = ([existingSections count] > 0) ? [[[existingSections objectAtIndex:0] objectForKey:@"c"] integerValue] : 0;
	if (sectionCount == 0) {
		char *seedError = NULL;
		if (sqlite3_exec(_db, [kLTDefaultHomeSectionsSQL UTF8String], NULL, NULL, &seedError) != SQLITE_OK) {
			NSLog(@"[LTDatabase] failed to seed default home sections: %s", seedError);
			sqlite3_free(seedError);
		}
	}

	return YES;
}

- (void)close {
	if (_db != NULL) {
		sqlite3_close(_db);
		_db = NULL;
	}
}

- (void)bindArguments:(NSArray *)args toStatement:(sqlite3_stmt *)statement {
	NSUInteger index = 1;
	for (id arg in args) {
		if (arg == nil || arg == [NSNull null]) {
			sqlite3_bind_null(statement, index);
		} else if ([arg isKindOfClass:[NSString class]]) {
			sqlite3_bind_text(statement, index, [(NSString *)arg UTF8String], -1, SQLITE_TRANSIENT);
		} else if ([arg isKindOfClass:[NSNumber class]]) {
			NSNumber *number = (NSNumber *)arg;
			const char *objCType = [number objCType];
			if (strcmp(objCType, @encode(double)) == 0 || strcmp(objCType, @encode(float)) == 0) {
				sqlite3_bind_double(statement, index, [number doubleValue]);
			} else {
				sqlite3_bind_int64(statement, index, [number longLongValue]);
			}
		} else {
			sqlite3_bind_null(statement, index);
		}
		index++;
	}
}

- (BOOL)executeUpdate:(NSString *)sql withArguments:(NSArray *)args {
	if (_db == NULL) return NO;
	sqlite3_stmt *statement = NULL;
	if (sqlite3_prepare_v2(_db, [sql UTF8String], -1, &statement, NULL) != SQLITE_OK) {
		NSLog(@"[LTDatabase] prepare failed for '%@': %s", sql, sqlite3_errmsg(_db));
		return NO;
	}
	[self bindArguments:args toStatement:statement];
	BOOL success = (sqlite3_step(statement) == SQLITE_DONE);
	if (!success) NSLog(@"[LTDatabase] step failed for '%@': %s", sql, sqlite3_errmsg(_db));
	sqlite3_finalize(statement);
	return success;
}

- (NSArray *)executeQuery:(NSString *)sql withArguments:(NSArray *)args {
	NSMutableArray *rows = [NSMutableArray array];
	if (_db == NULL) return rows;

	sqlite3_stmt *statement = NULL;
	if (sqlite3_prepare_v2(_db, [sql UTF8String], -1, &statement, NULL) != SQLITE_OK) {
		NSLog(@"[LTDatabase] prepare failed for '%@': %s", sql, sqlite3_errmsg(_db));
		return rows;
	}
	[self bindArguments:args toStatement:statement];

	int columnCount = sqlite3_column_count(statement);
	while (sqlite3_step(statement) == SQLITE_ROW) {
		NSMutableDictionary *row = [NSMutableDictionary dictionaryWithCapacity:columnCount];
		for (int i = 0; i < columnCount; i++) {
			NSString *columnName = [NSString stringWithUTF8String:sqlite3_column_name(statement, i)];
			id value = nil;
			switch (sqlite3_column_type(statement, i)) {
				case SQLITE_INTEGER: value = [NSNumber numberWithLongLong:sqlite3_column_int64(statement, i)]; break;
				case SQLITE_FLOAT: value = [NSNumber numberWithDouble:sqlite3_column_double(statement, i)]; break;
				case SQLITE_TEXT: {
					const char *text = (const char *)sqlite3_column_text(statement, i);
					value = text ? [NSString stringWithUTF8String:text] : @"";
					break;
				}
				default: value = [NSNull null]; break;
			}
			[row setObject:value forKey:columnName];
		}
		[rows addObject:row];
	}
	sqlite3_finalize(statement);
	return rows;
}

- (sqlite3_int64)lastInsertRowId { return sqlite3_last_insert_rowid(_db); }
- (BOOL)beginTransaction { return [self executeUpdate:@"BEGIN IMMEDIATE;" withArguments:nil]; }
- (BOOL)commitTransaction { return [self executeUpdate:@"COMMIT;" withArguments:nil]; }
- (BOOL)rollbackTransaction { return [self executeUpdate:@"ROLLBACK;" withArguments:nil]; }

- (void)upsertSongs:(NSArray *)songDicts {
	if (_db == NULL || [songDicts count] == 0) return;
	if (![self beginTransaction]) return;

	sqlite3_stmt *selectStmt = NULL, *insertStmt = NULL, *updateStmt = NULL;
	const char *selectSQL = "SELECT id FROM songs WHERE persistent_id = ?";
	const char *insertSQL = "INSERT INTO songs (persistent_id, title, artist, album, genre, track_number, disc_number, duration, artwork_path, date_added, play_count, skip_count, favorite, rating) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0, 0, 0, 0)";
	const char *updateSQL = "UPDATE songs SET title=?, artist=?, album=?, genre=?, track_number=?, disc_number=?, duration=?, artwork_path=? WHERE id=?";

	if (sqlite3_prepare_v2(_db, selectSQL, -1, &selectStmt, NULL) != SQLITE_OK ||
		sqlite3_prepare_v2(_db, insertSQL, -1, &insertStmt, NULL) != SQLITE_OK ||
		sqlite3_prepare_v2(_db, updateSQL, -1, &updateStmt, NULL) != SQLITE_OK) {
		if (selectStmt) sqlite3_finalize(selectStmt);
		if (insertStmt) sqlite3_finalize(insertStmt);
		if (updateStmt) sqlite3_finalize(updateStmt);
		[self rollbackTransaction];
		return;
	}

	for (NSDictionary *song in songDicts) {
		NSString *persistentID = [song objectForKey:@"persistentID"];
		sqlite3_reset(selectStmt);
		sqlite3_clear_bindings(selectStmt);
		sqlite3_bind_text(selectStmt, 1, [persistentID UTF8String], -1, SQLITE_TRANSIENT);

		sqlite3_int64 existingId = 0;
		BOOL exists = NO;
		if (sqlite3_step(selectStmt) == SQLITE_ROW) {
			existingId = sqlite3_column_int64(selectStmt, 0);
			exists = YES;
		}

		NSString *title = [song objectForKey:@"title"];
		NSString *artist = [song objectForKey:@"artist"];
		NSString *album = [song objectForKey:@"album"];
		NSString *genre = [song objectForKey:@"genre"];
		NSNumber *trackNumber = [song objectForKey:@"trackNumber"];
		NSNumber *discNumber = [song objectForKey:@"discNumber"];
		NSNumber *duration = [song objectForKey:@"duration"];
		id artworkPath = [song objectForKey:@"artworkPath"];

		sqlite3_stmt *targetStmt = exists ? updateStmt : insertStmt;
		sqlite3_reset(targetStmt);
		sqlite3_clear_bindings(targetStmt);

		int col = 1;
		if (!exists) sqlite3_bind_text(targetStmt, col++, [persistentID UTF8String], -1, SQLITE_TRANSIENT);
		sqlite3_bind_text(targetStmt, col++, [title UTF8String], -1, SQLITE_TRANSIENT);
		sqlite3_bind_text(targetStmt, col++, [artist UTF8String], -1, SQLITE_TRANSIENT);
		sqlite3_bind_text(targetStmt, col++, [album UTF8String], -1, SQLITE_TRANSIENT);
		sqlite3_bind_text(targetStmt, col++, [genre UTF8String], -1, SQLITE_TRANSIENT);
		sqlite3_bind_int64(targetStmt, col++, [trackNumber longLongValue]);
		sqlite3_bind_int64(targetStmt, col++, [discNumber longLongValue]);
		sqlite3_bind_double(targetStmt, col++, [duration doubleValue]);

		if ([artworkPath isKindOfClass:[NSString class]]) {
			sqlite3_bind_text(targetStmt, col++, [(NSString *)artworkPath UTF8String], -1, SQLITE_TRANSIENT);
		} else {
			sqlite3_bind_null(targetStmt, col++);
		}

		if (!exists) {
			NSNumber *dateAdded = [song objectForKey:@"dateAdded"];
			sqlite3_bind_double(targetStmt, col++, [dateAdded doubleValue]);
		} else {
			sqlite3_bind_int64(targetStmt, col++, existingId);
		}

		if (sqlite3_step(targetStmt) != SQLITE_DONE) {
			NSLog(@"[LTDatabase] upsertSongs: step failed for '%@': %s", title, sqlite3_errmsg(_db));
		}
	}

	sqlite3_finalize(selectStmt);
	sqlite3_finalize(insertStmt);
	sqlite3_finalize(updateStmt);
	[self commitTransaction];
}

- (void)dealloc {
	[self close];
	[super dealloc];
}

@end
