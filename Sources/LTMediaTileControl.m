#import "LTMediaTileControl.h"
#import "LTCompat.h"

static const CGFloat kLTTileLabelHeight = 15.0f;
static const CGFloat kLTTileLabelGap = 2.0f;
static const NSUInteger kLTTileLabelRows = 2;

CGFloat LTMediaTileControlHeightForWidth(CGFloat artworkSide) {
	return artworkSide + kLTTileLabelGap + (kLTTileLabelRows * kLTTileLabelHeight);
}

@implementation LTMediaTileControl

// FIX: an earlier version of this class (as LTAlbumTileControl) sized
// itself to frame.size.width square only, then placed its title/subtitle
// labels BELOW that — outside self.bounds. UIControl's default
// -pointInside:withEvent: hit-test only considers points inside its own
// bounds, so taps landing on the label text (not the artwork square)
// likely never registered as a touch on the control at all. Fixed by
// expanding self's own height to cover the labels too, so the tap target
// matches what's visually drawn — callers still pass a square-ish frame
// (width = artwork side); height is recalculated here regardless of what
// was passed in.
- (id)initWithFrame:(CGRect)frame {
	CGFloat artworkSide = frame.size.width;
	CGRect fullFrame = CGRectMake(frame.origin.x, frame.origin.y, artworkSide, LTMediaTileControlHeightForWidth(artworkSide));

	self = [super initWithFrame:fullFrame];
	if (self) {
		_artworkView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, artworkSide, artworkSide)];
		_artworkView.contentMode = UIViewContentModeScaleAspectFill;
		_artworkView.clipsToBounds = YES;
		_artworkView.backgroundColor = [UIColor colorWithWhite:0.18f alpha:1.0f];
		[self addSubview:_artworkView];

		_placeholderLabel = [[UILabel alloc] initWithFrame:_artworkView.frame];
		_placeholderLabel.textAlignment = LTTextAlignmentCenter;
		_placeholderLabel.font = [UIFont boldSystemFontOfSize:artworkSide * 0.35f];
		_placeholderLabel.textColor = [UIColor colorWithWhite:0.45f alpha:1.0f];
		_placeholderLabel.backgroundColor = [UIColor clearColor];
		[self addSubview:_placeholderLabel];

		CGFloat labelY = artworkSide + kLTTileLabelGap;
		_titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, labelY, artworkSide, kLTTileLabelHeight)];
		_titleLabel.font = [UIFont boldSystemFontOfSize:12];
		_titleLabel.textColor = [UIColor whiteColor];
		_titleLabel.backgroundColor = [UIColor clearColor];
		[self addSubview:_titleLabel];

		_subtitleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, labelY + kLTTileLabelHeight, artworkSide, kLTTileLabelHeight)];
		_subtitleLabel.font = [UIFont systemFontOfSize:11];
		_subtitleLabel.textColor = [UIColor lightGrayColor];
		_subtitleLabel.backgroundColor = [UIColor clearColor];
		[self addSubview:_subtitleLabel];
	}
	return self;
}

- (void)configureWithTitle:(NSString *)title subtitle:(NSString *)subtitle artworkPath:(NSString *)artworkPath {
	self.hidden = NO;
	self.userInteractionEnabled = YES;
	_titleLabel.text = title;
	_subtitleLabel.text = subtitle;

	// Lazy-decodes on first draw, not at load time — cheap per-tile since
	// only currently visible rows call this (the containing UITableView
	// reuses/recycles cells the same way it does plain rows): never
	// decode more than what's on screen.
	UIImage *artwork = (artworkPath != nil) ? [UIImage imageWithContentsOfFile:artworkPath] : nil;

	if (artwork != nil) {
		_artworkView.image = artwork;
		_placeholderLabel.hidden = YES;
	} else {
		_artworkView.image = nil;
		_placeholderLabel.text = ([title length] > 0) ? [[title substringToIndex:1] uppercaseString] : @"?";
		_placeholderLabel.hidden = NO;
	}
}

- (void)configureEmpty {
	self.hidden = YES;
	self.userInteractionEnabled = NO;
}

- (void)dealloc {
	[_artworkView release];
	[_placeholderLabel release];
	[_titleLabel release];
	[_subtitleLabel release];
	[super dealloc];
}

@end
