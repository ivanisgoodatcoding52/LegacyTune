#import <Foundation/Foundation.h>
#import <sqlite3.h>

@interface LTDatabase : NSObject {
	sqlite3 *_db;
}

+ (LTDatabase *)sharedDatabase;
- (BOOL)open;
- (void)close;
- (BOOL)executeUpdate:(NSString *)sql withArguments:(NSArray *)args;
- (NSArray *)executeQuery:(NSString *)sql withArguments:(NSArray *)args;
- (sqlite3_int64)lastInsertRowId;
- (BOOL)beginTransaction;
- (BOOL)commitTransaction;
- (BOOL)rollbackTransaction;
- (void)upsertSongs:(NSArray *)songDicts;

// Removes songs whose persistent_id is NOT in `persistentIDs` (the full set
// the scanner just saw), so tracks deleted from the device stop showing up.
// playlist_items rows cascade away with them. Does nothing for an empty
// array — an empty scan more likely means the media library was momentarily
// unavailable than that the user deleted everything.
- (void)pruneSongsNotInPersistentIDs:(NSArray *)persistentIDs;

// Bumps play_count and stamps last_played for one song (by songs.id).
- (void)recordPlayForSongId:(NSInteger)songId;

@end
