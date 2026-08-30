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

@end
