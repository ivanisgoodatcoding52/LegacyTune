#import <UIKit/UIKit.h>
#import "LTMediaTileControl.h"

extern const NSUInteger kLTAlbumGridColumns;
extern CGFloat LTAlbumGridRowHeightForWidth(CGFloat width);

// One UITableView row holding kLTAlbumGridColumns (2) side-by-side
// LTMediaTileControls. Reused via the normal dequeueReusableCellWithIdentifier
// path, same as any other cell — this is what keeps the grid scrolling
// smoothly instead of allocating/decoding every album up front (the exact
// mistake that caused the original Library freeze).
@interface LTAlbumGridRowCell : UITableViewCell {
	NSMutableArray *_tiles; // LTMediaTileControl*, count == kLTAlbumGridColumns
}

- (id)initWithReuseIdentifier:(NSString *)reuseIdentifier width:(CGFloat)width;

// summaries has 1 or kLTAlbumGridColumns entries (LTAlbumSummary*) for
// this row; startingFlatIndex is the flat album index of summaries[0],
// used to tag each tile so taps can be mapped back to an album.
- (void)configureWithSummaries:(NSArray *)summaries startingFlatIndex:(NSUInteger)startingFlatIndex target:(id)target action:(SEL)action;

@end
