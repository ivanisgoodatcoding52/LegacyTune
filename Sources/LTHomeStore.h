#import <Foundation/Foundation.h>
#import "LTHomeModels.h"
#import "LTAlbumSummary.h"

@interface LTHomeStore : NSObject
+ (LTHomeStore *)sharedStore;

// Sections
- (NSArray *)sectionsOrdered;                                       // LTHomeSection*, sort_order ASC
- (void)moveSectionFromIndex:(NSUInteger)from toIndex:(NSUInteger)to;

// Favorites — Artist/Album only this pass (see LTHomeModels.h)
- (NSArray *)favoritesOrdered;                                      // LTHomeFavorite*, sort_order ASC
- (void)addFavoriteWithType:(NSString *)itemType key:(NSString *)itemKey;
- (void)removeFavorite:(LTHomeFavorite *)favorite;

// Recently Added — reuses LTAlbumSummary (same tile data shape as the
// Library album grid), ordered by each album's most recent date_added.
- (NSArray *)recentlyAddedAlbumsWithLimit:(NSUInteger)limit;

@end
