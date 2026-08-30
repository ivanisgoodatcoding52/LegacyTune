#import <Foundation/Foundation.h>

// Trimmed scope: 2 fixed sections (favorites, recently_added), reorder
// only — no hide/show, no adding new sections. See conversation notes.
@interface LTHomeSection : NSObject
@property (nonatomic, copy) NSString *sectionKey;
@property (nonatomic, assign) NSInteger sortOrder;
+ (id)sectionWithRow:(NSDictionary *)row;
- (NSString *)displayTitle; // "Favorites" / "Recently Added", derived from sectionKey
@end

// A user-pinned Favorite. itemType is "artist" or "album" only in this
// pass (Playlists/Genres favorites were cut from scope). title/subtitle/
// artworkPath are a resolved-at-add-time snapshot (not re-joined on every
// read) — cheap to display, at the cost of going stale if the underlying
// artist/album's artwork changes later. Acceptable tradeoff for a
// favorites list of this size; revisit if that staleness becomes visible.
@interface LTHomeFavorite : NSObject
@property (nonatomic, assign) NSInteger favoriteId;
@property (nonatomic, copy) NSString *itemType;   // "artist" | "album"
@property (nonatomic, copy) NSString *itemKey;    // artist or album name, used as the filter value
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *subtitle;
@property (nonatomic, copy) NSString *artworkPath; // may be nil -> placeholder tile
@property (nonatomic, assign) NSInteger sortOrder;
+ (id)favoriteWithRow:(NSDictionary *)row;
@end
