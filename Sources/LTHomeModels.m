#import "LTHomeModels.h"

@implementation LTHomeSection

@synthesize sectionKey = _sectionKey;
@synthesize sortOrder = _sortOrder;

+ (id)sectionWithRow:(NSDictionary *)row {
	LTHomeSection *section = [[[LTHomeSection alloc] init] autorelease];
	section.sectionKey = [row objectForKey:@"section_key"];
	section.sortOrder = [[row objectForKey:@"sort_order"] integerValue];
	return section;
}

- (NSString *)displayTitle {
	if ([_sectionKey isEqualToString:@"favorites"]) return @"Favorites";
	if ([_sectionKey isEqualToString:@"recently_added"]) return @"Recently Added";
	return _sectionKey; // fallback, shouldn't normally be hit with only 2 seeded sections
}

- (void)dealloc {
	[_sectionKey release];
	[super dealloc];
}

@end

@implementation LTHomeFavorite

@synthesize favoriteId = _favoriteId;
@synthesize itemType = _itemType;
@synthesize itemKey = _itemKey;
@synthesize title = _title;
@synthesize subtitle = _subtitle;
@synthesize artworkPath = _artworkPath;
@synthesize sortOrder = _sortOrder;

+ (id)favoriteWithRow:(NSDictionary *)row {
	LTHomeFavorite *favorite = [[[LTHomeFavorite alloc] init] autorelease];
	favorite.favoriteId = [[row objectForKey:@"id"] integerValue];
	favorite.itemType = [row objectForKey:@"item_type"];
	favorite.itemKey = [row objectForKey:@"item_key"];
	favorite.title = [row objectForKey:@"title"];
	favorite.subtitle = [row objectForKey:@"subtitle"];
	id artworkPath = [row objectForKey:@"artwork_path"];
	favorite.artworkPath = [artworkPath isKindOfClass:[NSString class]] ? artworkPath : nil;
	favorite.sortOrder = [[row objectForKey:@"sort_order"] integerValue];
	return favorite;
}

- (void)dealloc {
	[_itemType release];
	[_itemKey release];
	[_title release];
	[_subtitle release];
	[_artworkPath release];
	[super dealloc];
}

@end
