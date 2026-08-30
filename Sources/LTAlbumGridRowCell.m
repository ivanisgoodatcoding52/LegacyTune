#import "LTAlbumGridRowCell.h"
#import "LTAlbumSummary.h"

const NSUInteger kLTAlbumGridColumns = 2;
static const CGFloat kLTAlbumGridMargin = 10.0f;
static const CGFloat kLTAlbumGridSpacing = 10.0f;
static const CGFloat kLTAlbumGridRowVerticalPadding = 12.0f;

CGFloat LTAlbumGridRowHeightForWidth(CGFloat width) {
	CGFloat tileSide = (width - (2 * kLTAlbumGridMargin) - ((kLTAlbumGridColumns - 1) * kLTAlbumGridSpacing)) / kLTAlbumGridColumns;
	// FIX (matches the LTMediaTileControl rename/fix): the tile now
	// reports its OWN full height (artwork + both labels) via
	// LTMediaTileControlHeightForWidth, instead of this file adding a
	// separately-guessed label height on top of a square tile — the old
	// version here would have gone stale the moment LTMediaTileControl's
	// internal label sizing changed, silently clipping the subtitle line.
	return LTMediaTileControlHeightForWidth(tileSide) + kLTAlbumGridRowVerticalPadding;
}

@implementation LTAlbumGridRowCell

- (id)initWithReuseIdentifier:(NSString *)reuseIdentifier width:(CGFloat)width {
	self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuseIdentifier];
	if (self) {
		self.selectionStyle = UITableViewCellSelectionStyleNone;
		self.backgroundColor = [UIColor blackColor];

		CGFloat tileSide = (width - (2 * kLTAlbumGridMargin) - ((kLTAlbumGridColumns - 1) * kLTAlbumGridSpacing)) / kLTAlbumGridColumns;

		_tiles = [[NSMutableArray alloc] initWithCapacity:kLTAlbumGridColumns];
		for (NSUInteger i = 0; i < kLTAlbumGridColumns; i++) {
			CGFloat x = kLTAlbumGridMargin + (i * (tileSide + kLTAlbumGridSpacing));
			// Pass a square frame (width = height = tileSide) — LTMediaTileControl
			// expands its own height internally to fit the labels below.
			LTMediaTileControl *tile = [[LTMediaTileControl alloc] initWithFrame:CGRectMake(x, 6, tileSide, tileSide)];
			[self.contentView addSubview:tile];
			[_tiles addObject:tile];
			[tile release];
		}
	}
	return self;
}

- (void)configureWithSummaries:(NSArray *)summaries startingFlatIndex:(NSUInteger)startingFlatIndex target:(id)target action:(SEL)action {
	for (NSUInteger i = 0; i < kLTAlbumGridColumns; i++) {
		LTMediaTileControl *tile = [_tiles objectAtIndex:i];

		[tile removeTarget:nil action:NULL forControlEvents:UIControlEventTouchUpInside];

		if (i < [summaries count]) {
			LTAlbumSummary *summary = [summaries objectAtIndex:i];
			[tile configureWithTitle:summary.album subtitle:summary.artist artworkPath:summary.artworkPath];
			tile.tag = startingFlatIndex + i;
			[tile addTarget:target action:action forControlEvents:UIControlEventTouchUpInside];
		} else {
			[tile configureEmpty];
		}
	}
}

- (void)dealloc {
	[_tiles release];
	[super dealloc];
}

@end
