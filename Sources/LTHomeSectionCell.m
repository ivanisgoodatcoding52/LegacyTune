#import "LTHomeSectionCell.h"
#import "LTMediaTileControl.h"

static const CGFloat kLTHomeTileSide = 100.0f;
static const CGFloat kLTHomeTileSpacing = 10.0f;
static const CGFloat kLTHomeStripMargin = 12.0f;
static const CGFloat kLTHomeTitleHeight = 24.0f;
static const CGFloat kLTHomeTitleGap = 4.0f;
static const CGFloat kLTHomeBottomPadding = 10.0f;

CGFloat LTHomeSectionCellHeight(void) {
	// Doesn't depend on table width — unlike the Library album grid (which
	// fits exactly 2 columns to the screen), this is a horizontally
	// scrolling strip of fixed-size tiles, so only tile count (not screen
	// width) affects content width, and height is constant regardless.
	return kLTHomeTitleHeight + kLTHomeTitleGap + LTMediaTileControlHeightForWidth(kLTHomeTileSide) + kLTHomeBottomPadding;
}

@implementation LTHomeSectionCell

- (id)initWithReuseIdentifier:(NSString *)reuseIdentifier {
	self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuseIdentifier];
	if (self) {
		self.selectionStyle = UITableViewCellSelectionStyleNone;
		self.backgroundColor = [UIColor blackColor];

		_titleButton = [UIButton buttonWithType:UIButtonTypeCustom];
		[_titleButton retain];
		_titleButton.titleLabel.font = [UIFont boldSystemFontOfSize:17];
		[_titleButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
		_titleButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
		_titleButton.backgroundColor = [UIColor clearColor];
		[self.contentView addSubview:_titleButton];

		_scrollView = [[UIScrollView alloc] init]; // frame set in -layoutSubviews
		_scrollView.showsHorizontalScrollIndicator = NO;
		_scrollView.backgroundColor = [UIColor clearColor];
		[self.contentView addSubview:_scrollView];

		_tiles = [[NSMutableArray alloc] init];
	}
	return self;
}

- (void)layoutSubviews {
	[super layoutSubviews];
	CGFloat width = self.contentView.bounds.size.width;

	_titleButton.frame = CGRectMake(kLTHomeStripMargin, 0, width - (2 * kLTHomeStripMargin), kLTHomeTitleHeight);

	CGFloat scrollY = kLTHomeTitleHeight + kLTHomeTitleGap;
	CGFloat scrollHeight = LTMediaTileControlHeightForWidth(kLTHomeTileSide);
	_scrollView.frame = CGRectMake(0, scrollY, width, scrollHeight);
}

- (void)configureWithTitle:(NSString *)sectionTitle cardData:(NSArray *)cardData
	target:(id)target action:(SEL)action
	titleTarget:(id)titleTarget titleAction:(SEL)titleAction {

	[_titleButton setTitle:sectionTitle forState:UIControlStateNormal];
	[_titleButton removeTarget:nil action:NULL forControlEvents:UIControlEventTouchUpInside];
	if (titleTarget != nil && titleAction != NULL) {
		[_titleButton addTarget:titleTarget action:titleAction forControlEvents:UIControlEventTouchUpInside];
	}

	// Tiles are rebuilt each time rather than reused/recycled across
	// -configure calls — section item counts are small (a handful of
	// favorites, a handful of recently-added albums), so the allocation
	// cost here is negligible; not worth the extra bookkeeping a proper
	// tile-recycling pool would need for so few views.
	for (LTMediaTileControl *tile in _tiles) [tile removeFromSuperview];
	[_tiles removeAllObjects];

	CGFloat x = kLTHomeStripMargin;
	NSUInteger index = 0;
	for (NSDictionary *card in cardData) {
		LTMediaTileControl *tile = [[LTMediaTileControl alloc] initWithFrame:CGRectMake(x, 0, kLTHomeTileSide, kLTHomeTileSide)];

		id artworkPath = [card objectForKey:@"artworkPath"];
		[tile configureWithTitle:[card objectForKey:@"title"]
			subtitle:[card objectForKey:@"subtitle"]
			artworkPath:[artworkPath isKindOfClass:[NSString class]] ? artworkPath : nil];

		tile.tag = index;
		[tile addTarget:target action:action forControlEvents:UIControlEventTouchUpInside];

		[_scrollView addSubview:tile];
		[_tiles addObject:tile];
		[tile release];

		x += kLTHomeTileSide + kLTHomeTileSpacing;
		index++;
	}

	CGFloat contentWidth = ([cardData count] > 0) ? (x - kLTHomeTileSpacing + kLTHomeStripMargin) : 0;
	_scrollView.contentSize = CGSizeMake(contentWidth, LTMediaTileControlHeightForWidth(kLTHomeTileSide));
}

- (void)dealloc {
	[_titleButton release];
	[_scrollView release];
	[_tiles release];
	[super dealloc];
}

@end
