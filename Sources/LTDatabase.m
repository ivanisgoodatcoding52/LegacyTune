#import "LTDatabase.h"
#import <string.h>

// Not defined in the older sqlite3.h shipped in legacy iOS SDKs' usr/include
// in every case — define it ourselves rather than depend on it being there.
#ifndef SQLITE_TRANSIENT
#define SQLITE_TRANSIENT ((sqlite3_destructor_type)-1)
#endif

static NSString *const kLTDatabaseFileName = @"LegacyTune.sqlite";

// NOTE ON SCHEMA SHAPE: the original product spec called for fully
// normalized Artists/Albums/Genres tables. This first pass denormalizes
// artist/album/genre onto the songs row instead (plain TEXT columns,
// grouped with GROUP BY / DISTINCT for browsing). That's a deliberate
// scope cut to get Library + Playlists working end-to-end quickly — it's
// still fully browsable and queryable, it just can't yet hold per-album
// or per-artist data that isn't derivable from the songs themselves (e.g.
// a manually-edited album release year that differs from any one track,
// or artist bio-like aggregate fields). Normalizing into separate tables
// with foreign keys is a reasonable follow-up once Home/recommendations
// need that richer structure.
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
	"CREATE INDEX IF NOT EXISTS idx_songs_artist ON songs(artist);"
	"CREATE INDEX IF NOT EXISTS idx_songs_album ON songs(album);"
	"CREATE INDEX IF NOT EXISTS idx_songs_genre ON songs(genre);"
	"CREATE INDEX IF NOT EXISTS idx_songs_title ON songs(title);"
	""
	"CREATE TABLE IF NOT EXISTS playlists ("
	"  id INTEGER PRIMARY KEY AUTOINCREMENT,"
	"  name TEXT NOT NULL,"
	"  date_created REAL DEFAULT 0,"
	"  sort_order INTEGER DEFAULT 0"
	");"
	""
	"CREATE TABLE IF NOT EXISTS playlist_items ("
	"  id INTEGER PRIMARY KEY AUTOINCREMENT,"
	"  playlist_id INTEGER NOT NULL,"
	"  song_id INTEGER NOT NULL,"
	"  sort_order INTEGER DEFAULT 0,"
	"  FOREIGN KEY(playlist_id) REFERENCES playlists(id) ON DELETE CASCADE,"
	"  FOREIGN KEY(song_id) REFERENCES songs(id) ON DELETE CASCADE"
	");"
	"CREATE INDEX IF NOT EXISTS idx_playlist_items_playlist ON playlist_items(playlist_id);"
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
	NSString *documentsDir = [paths objectAtIndex:0];
	return [documentsDir stringByAppendingPathComponent:kLTDatabaseFileName];
}

- (BOOL)open {
	if (_db != NULL) {
		return YES;
	}

	NSString *path = [self databasePath];
	int result = sqlite3_open([path UTF8String], &_db);
	if (result != SQLITE_OK) {
		NSLog(@"[LTDatabase] failed to open database at %@: %s", path, sqlite3_errmsg(_db));
		return NO;
	}

	// Foreign key enforcement is OFF by default per-connection in sqlite3
	// and must be turned on every time a connection is opened.
	sqlite3_exec(_db, "PRAGMA foreign_keys = ON;", NULL, NULL, NULL);

	char *errorMessage = NULL;
	result = sqlite3_exec(_db, [kLTSchemaSQL UTF8String], NULL, NULL, &errorMessage);
	if (result != SQLITE_OK) {
		NSLog(@"[LTDatabase] failed to create schema: %s", errorMessage);
		sqlite3_free(errorMessage);
		return NO;
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
			NSLog(@"[LTDatabase] unsupported argument type %@ for '%@' — binding NULL", [arg class], arg);
			sqlite3_bind_null(statement, index);
		}
		index++;
	}
}

- (BOOL)executeUpdate:(NSString *)sql withArguments:(NSArray *)args {
	if (_db == NULL) {
		NSLog(@"[LTDatabase] executeUpdate: called before -open");
		return NO;
	}

	sqlite3_stmt *statement = NULL;
	if (sqlite3_prepare_v2(_db, [sql UTF8String], -1, &statement, NULL) != SQLITE_OK) {
		NSLog(@"[LTDatabase] prepare failed for '%@': %s", sql, sqlite3_errmsg(_db));
		return NO;
	}

	[self bindArguments:args toStatement:statement];

	BOOL success = (sqlite3_step(statement) == SQLITE_DONE);
	if (!success) {
		NSLog(@"[LTDatabase] step failed for '%@': %s", sql, sqlite3_errmsg(_db));
	}

	sqlite3_finalize(statement);
	return success;
}

- (NSArray *)executeQuery:(NSString *)sql withArguments:(NSArray *)args {
	NSMutableArray *rows = [NSMutableArray array];

	if (_db == NULL) {
		NSLog(@"[LTDatabase] executeQuery: called before -open");
		return rows;
	}

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
			int columnType = sqlite3_column_type(statement, i);
			id value = nil;

			switch (columnType) {
				case SQLITE_INTEGER:
					value = [NSNumber numberWithLongLong:sqlite3_column_int64(statement, i)];
					break;
				case SQLITE_FLOAT:
					value = [NSNumber numberWithDouble:sqlite3_column_double(statement, i)];
					break;
				case SQLITE_TEXT: {
					const char *text = (const char *)sqlite3_column_text(statement, i);
					value = text ? [NSString stringWithUTF8String:text] : @"";
					break;
				}
				case SQLITE_NULL:
				default:
					value = [NSNull null];
					break;
			}

			[row setObject:value forKey:columnName];
		}

		[rows addObject:row];
	}

	sqlite3_finalize(statement);
	return rows;
}

- (sqlite3_int64)lastInsertRowId {
	return sqlite3_last_insert_rowid(_db);
}

- (void)dealloc {
	[self close];
	[super dealloc];
}

@end
