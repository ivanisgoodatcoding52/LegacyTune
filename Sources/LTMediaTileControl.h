#import <UIKit/UIKit.h>

// One artwork-square tile: image, title, subtitle below. Used by both the
// Library album grid (title=album, subtitle=artist) and Home's horizontal
// section strips (Favorites, Recently Added — title/subtitle mean
// whatever that context needs, e.g. artist name + "Artist").
//
// A UIControl (not UIView + UITapGestureRecognizer) — UIGestureRecognizer
// is iOS 3.2+ only; this project's floor is iOS 3.0. UIControl's
// target-action has worked since iOS 2.0.
@interface LTMediaTileControl : UIControl {
	UIImageView *_artworkView;
	UILabel *_placeholderLabel;
	UILabel *_titleLabel;
	UILabel *_subtitleLabel;
}

// artworkPath may be nil — falls back to a generated placeholder (colored
// square + first-letter initial), matching the spec's artwork priority
// order (embedded > cached > generated placeholder).
- (void)configureWithTitle:(NSString *)title subtitle:(NSString *)subtitle artworkPath:(NSString *)artworkPath;

// Empties the tile visually and disables interaction — used for a
// trailing empty slot when a grid row is short one item.
- (void)configureEmpty;

@end
