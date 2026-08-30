#import <UIKit/UIKit.h>

// Full-screen Now Playing screen: artwork, title/artist, scrubber with
// elapsed/remaining time, shuffle toggle, prev/play-pause/next, repeat
// cycle button. Presented modally from the mini player.
@interface LTPlayerViewController : UIViewController {
	UIImageView *_artworkView;
	UILabel *_placeholderLabel;
	UILabel *_titleLabel;
	UILabel *_artistLabel;
	UISlider *_scrubber;
	UILabel *_elapsedLabel;
	UILabel *_remainingLabel;
	UIButton *_shuffleButton;
	UIButton *_previousButton;
	UIButton *_playPauseButton;
	UIButton *_nextButton;
	UIButton *_repeatButton;
	NSTimer *_updateTimer;
	BOOL _isScrubbing; // suppress timer-driven scrubber updates while the user is dragging it
}

@end
