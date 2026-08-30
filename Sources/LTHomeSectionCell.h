#import <UIKit/UIKit.h>

extern CGFloat LTHomeSectionCellHeight(void);

// One Home section: a title button (tappable when a title action is
// bound, e.g. Favorites -> "Manage Favorites"; otherwise just inert text)
// + a horizontally-scrolling strip of LTMediaTileControl cards. Used for
// BOTH Favorites and Recently Added — one shared cell class/layout, only
// the data (and whether the title does anything) differs.
@interface LTHomeSectionCell : UITableViewCell {
	UIButton *_titleButton;
	UIScrollView *_scrollView;
	NSMutableArray *_tiles; // LTMediaTileControl*, rebuilt each -configure call since item count varies
}

- (id)initWithReuseIdentifier:(NSString *)reuseIdentifier;

// cardData is an array of NSDictionary, each with "title" (NSString),
// "subtitle" (NSString), and "artworkPath" (NSString or NSNull) — plain
// dictionaries rather than a shared model type, since LTAlbumSummary
// (album/artist/artworkPath) and LTHomeFavorite (title/subtitle/
// artworkPath) don't share property names and have nothing else in
// common; the caller normalizes either into this shape.
//
// titleTarget/titleAction are optional (pass nil/NULL for a section whose
// title shouldn't navigate anywhere, e.g. Recently Added).
- (void)configureWithTitle:(NSString *)sectionTitle cardData:(NSArray *)cardData
	target:(id)target action:(SEL)action
	titleTarget:(id)titleTarget titleAction:(SEL)titleAction;

@end
