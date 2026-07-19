#import <Foundation/Foundation.h>
#import <sqlite3.h>

// Thin wrapper around the sqlite3 C API. Deliberately not using a
// third-party wrapper (e.g. FMDB) to keep the project dependency-free per
// the spec's "native Objective-C/UIKit implementation" goal.
//
// THREADING: sqlite3 handles are not safe to share across threads the way
// this class uses them (unsynchronized). The pattern this project follows:
// +sharedDatabase is a singleton used ONLY from the main thread by UI code.
// Any background worker (LTLibraryScanner, background search) creates its
// OWN instance — `[[LTDatabase alloc] init]` then `-open` — which opens a
// second connection to the same file. SQLite's own file locking (plus the
// busy timeout set in -open) makes that safe even if both connections
// happen to touch the DB at the same moment; a brief stall is possible but
// bounded, never a hard failure. Do NOT call the same LTDatabase instance
// from two threads concurrently.
@interface LTDatabase : NSObject {
	sqlite3 *_db;
}

+ (LTDatabase *)sharedDatabase;

// Opens (creating if necessary) the on-disk DB in Documents/LegacyTune.sqlite,
// runs schema creation, and applies performance pragmas. Safe to call
// multiple times — a no-op if already open on this instance.
- (BOOL)open;
- (void)close;

// args elements may be NSString, NSNumber, or NSNull (or nil, treated the
// same as NSNull). Placeholders in sql are positional "?".
- (BOOL)executeUpdate:(NSString *)sql withArguments:(NSArray *)args;

// Returns an array of NSDictionary, one per row, keyed by column name.
- (NSArray *)executeQuery:(NSString *)sql withArguments:(NSArray *)args;

- (sqlite3_int64)lastInsertRowId;

// Wrap a batch of writes in one transaction instead of N implicit ones.
// This is the single biggest lever for bulk-write performance on flash
// storage: SQLite's default autocommit mode fsyncs per statement, so N
// unwrapped writes means N fsyncs. N writes inside one
// begin/commit means one. Always pair with -commitTransaction (or
// -rollbackTransaction on failure) — don't leave a transaction open.
- (BOOL)beginTransaction;
- (BOOL)commitTransaction;
- (BOOL)rollbackTransaction;

// Bulk import path used by LTLibraryScanner. Each dictionary must have:
// persistentID, title, artist, album, genre (NSString), trackNumber,
// discNumber, duration, dateAdded (NSNumber), and artworkPath (NSString
// or NSNull). Runs the entire batch inside a single transaction with
// prepared statements reused across rows (reset + re-bound, not
// re-prepared from SQL text each time) — see the .m for why that matters
// on this hardware. Call this from a background LTDatabase instance, not
// +sharedDatabase, to keep the scan off the main thread entirely.
- (void)upsertSongs:(NSArray *)songDicts;

@end
