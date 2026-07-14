#import <Foundation/Foundation.h>
#import <sqlite3.h>

// Thin wrapper around the sqlite3 C API. Deliberately not using a
// third-party wrapper (e.g. FMDB) to keep the project dependency-free per
// the spec's "native Objective-C/UIKit implementation" goal.
//
// THREADING: this class is not internally synchronized. LTLibraryScanner
// hops back to the main thread for every write (see its comments) so all
// actual sqlite3_* calls happen on one thread. If more background writers
// get added later, this needs a serial dispatch/NSOperationQueue in front
// of it — don't call it concurrently from multiple threads as-is.
@interface LTDatabase : NSObject {
	sqlite3 *_db;
}

+ (LTDatabase *)sharedDatabase;

// Opens (creating if necessary) the on-disk DB in Documents/LegacyTune.sqlite
// and runs schema creation. Safe to call multiple times — a no-op if
// already open. Call this once at app launch before touching anything else
// in the app that reads/writes the database.
- (BOOL)open;
- (void)close;

// args elements may be NSString, NSNumber, or NSNull (or nil, which is
// treated the same as NSNull). Placeholders in sql are positional "?".
- (BOOL)executeUpdate:(NSString *)sql withArguments:(NSArray *)args;

// Returns an array of NSDictionary, one per row, keyed by column name.
- (NSArray *)executeQuery:(NSString *)sql withArguments:(NSArray *)args;

- (sqlite3_int64)lastInsertRowId;

@end
