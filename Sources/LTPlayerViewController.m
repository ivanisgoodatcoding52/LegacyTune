#import "LTPlayerViewController.h"
#import "LTPlaybackController.h"
#import "LTSong.h"
#import "LTCompat.h"

static NSString *LTFormattedTime(NSTimeInterval seconds) {
	if (seconds < 0) seconds = 0;
	NSInteger totalSeconds = (NSInteger)seconds;
	NSInteger minutes = totalSeconds / 60;
	NSInteger secs = totalSeconds % 60;
	return [NSString stringWithFormat:@"%ld:%02ld", (long)minutes, (long)secs];
}

@interface LTPlayerViewController (Private)
- (void)refreshForCurrentSong;
- (void)refreshTransportState;
- (void)tickScrubber;
- (void)closeTapped;
- (void)shuffleTapped;
- (void)previousTapped;
- (void)playPauseTapped;
- (void)nextTapped;
- (void)repeatTapped;
- (void)scrubberBeganDragging;
- (void)scrubberValueChanged;
- (void)scrubberEndedDragging;
- (void)playbackStateChanged:(NSNotification *)notification;
@end

@implementation LTPlayerViewController

- (void)loadView {
	CGRect frame = [[UIScreen mainScreen] bounds];
	self.view = [[[UIView alloc] initWithFrame:frame] autorelease];
	self.view.backgroundColor = [UIColor blackColor];

	UIButton *closeButton = [UIButton buttonWithType:UIButtonTypeCustom];
	closeButton.frame = CGRectMake(16, 36, 60, 30);
	[closeButton setTitle:@"Close" forState:UIControlStateNormal];
	[closeButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
	[closeButton addTarget:self action:@selector(closeTapped) forControlEvents:UIControlEventTouchUpInside];
	[self.view addSubview:closeButton];

	CGFloat artworkSide = MIN(frame.size.width - 64, 260);
	CGFloat artworkX = (frame.size.width - artworkSide) / 2.0f;
	CGFloat artworkY = 90;

	_artworkView = [[UIImageView alloc] initWithFrame:CGRectMake(artworkX, artworkY, artworkSide, artworkSide)];
	_artworkView.contentMode = UIViewContentModeScaleAspectFill;
	_artworkView.clipsToBounds = YES;
	_artworkView.backgroundColor = [UIColor colorWithWhite:0.15f alpha:1.0f];
	[self.view addSubview:_artworkView];

	_placeholderLabel = [[UILabel alloc] initWithFrame:_artworkView.frame];
	_placeholderLabel.textAlignment = LTTextAlignmentCenter;
	_placeholderLabel.font = [UIFont boldSystemFontOfSize:artworkSide * 0.35f];
	_placeholderLabel.textColor = [UIColor colorWithWhite:0.4f alpha:1.0f];
	_placeholderLabel.backgroundColor = [UIColor clearColor];
	[self.view addSubview:_placeholderLabel];

	CGFloat titleY = artworkY + artworkSide + 24;
	_titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(24, titleY, frame.size.width - 48, 26)];
	_titleLabel.font = [UIFont boldSystemFontOfSize:19];
	_titleLabel.textColor = [UIColor whiteColor];
	_titleLabel.backgroundColor = [UIColor clearColor];
	_titleLabel.textAlignment = LTTextAlignmentCenter;
	[self.view addSubview:_titleLabel];

	_artistLabel = [[UILabel alloc] initWithFrame:CGRectMake(24, titleY + 26, frame.size.width - 48, 20)];
	_artistLabel.font = [UIFont systemFontOfSize:15];
	_artistLabel.textColor = [UIColor lightGrayColor];
	_artistLabel.backgroundColor = [UIColor clearColor];
	_artistLabel.textAlignment = LTTextAlignmentCenter;
	[self.view addSubview:_artistLabel];

	CGFloat scrubberY = titleY + 26 + 20 + 20;
	_scrubber = [[UISlider alloc] initWithFrame:CGRectMake(24, scrubberY, frame.size.width - 48, 24)];
	_scrubber.minimumValue = 0;
	[_scrubber addTarget:self action:@selector(scrubberBeganDragging) forControlEvents:UIControlEventTouchDown];
	[_scrubber addTarget:self action:@selector(scrubberValueChanged) forControlEvents:UIControlEventValueChanged];
	[_scrubber addTarget:self action:@selector(scrubberEndedDragging) forControlEvents:(UIControlEventTouchUpInside | UIControlEventTouchUpOutside)];
	[self.view addSubview:_scrubber];

	CGFloat timeY = scrubberY + 24;
	_elapsedLabel = [[UILabel alloc] initWithFrame:CGRectMake(24, timeY, 60, 18)];
	_elapsedLabel.font = [UIFont systemFontOfSize:12];
	_elapsedLabel.textColor = [UIColor lightGrayColor];
	_elapsedLabel.backgroundColor = [UIColor clearColor];
	[self.view addSubview:_elapsedLabel];

	_remainingLabel = [[UILabel alloc] initWithFrame:CGRectMake(frame.size.width - 84, timeY, 60, 18)];
	_remainingLabel.font = [UIFont systemFontOfSize:12];
	_remainingLabel.textColor = [UIColor lightGrayColor];
	_remainingLabel.backgroundColor = [UIColor clearColor];
	_remainingLabel.textAlignment = LTTextAlignmentRight;
	[self.view addSubview:_remainingLabel];

	CGFloat transportY = timeY + 40;
	CGFloat centerX = frame.size.width / 2.0f;

	_playPauseButton = [[UIButton buttonWithType:UIButtonTypeCustom] retain];
	_playPauseButton.frame = CGRectMake(centerX - 28, transportY, 56, 56);
	[_playPauseButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
	_playPauseButton.titleLabel.font = [UIFont systemFontOfSize:36];
	[_playPauseButton addTarget:self action:@selector(playPauseTapped) forControlEvents:UIControlEventTouchUpInside];
	[self.view addSubview:_playPauseButton];

	_previousButton = [[UIButton buttonWithType:UIButtonTypeCustom] retain];
	_previousButton.frame = CGRectMake(centerX - 100, transportY + 10, 44, 44);
	[_previousButton setTitle:@"⏮" forState:UIControlStateNormal];
	[_previousButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
	_previousButton.titleLabel.font = [UIFont systemFontOfSize:26];
	[_previousButton addTarget:self action:@selector(previousTapped) forControlEvents:UIControlEventTouchUpInside];
	[self.view addSubview:_previousButton];

	_nextButton = [[UIButton buttonWithType:UIButtonTypeCustom] retain];
	_nextButton.frame = CGRectMake(centerX + 56, transportY + 10, 44, 44);
	[_nextButton setTitle:@"⏭" forState:UIControlStateNormal];
	[_nextButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
	_nextButton.titleLabel.font = [UIFont systemFontOfSize:26];
	[_nextButton addTarget:self action:@selector(nextTapped) forControlEvents:UIControlEventTouchUpInside];
	[self.view addSubview:_nextButton];

	_shuffleButton = [[UIButton buttonWithType:UIButtonTypeCustom] retain];
	_shuffleButton.frame = CGRectMake(24, transportY + 14, 36, 36);
	[_shuffleButton setTitle:@"⤨" forState:UIControlStateNormal];
	[_shuffleButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
	_shuffleButton.titleLabel.font = [UIFont systemFontOfSize:20];
	[_shuffleButton addTarget:self action:@selector(shuffleTapped) forControlEvents:UIControlEventTouchUpInside];
	[self.view addSubview:_shuffleButton];

	_repeatButton = [[UIButton buttonWithType:UIButtonTypeCustom] retain];
	_repeatButton.frame = CGRectMake(frame.size.width - 60, transportY + 14, 36, 36);
	[_repeatButton setTitle:@"⟲" forState:UIControlStateNormal];
	[_repeatButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
	_repeatButton.titleLabel.font = [UIFont systemFontOfSize:20];
	[_repeatButton addTarget:self action:@selector(repeatTapped) forControlEvents:UIControlEventTouchUpInside];
	[self.view addSubview:_repeatButton];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playbackStateChanged:)
		name:LTPlaybackStateDidChangeNotification object:nil];

	[self refreshForCurrentSong];
	[self refreshTransportState];

	_updateTimer = [[NSTimer scheduledTimerWithTimeInterval:0.4 target:self selector:@selector(tickScrubber) userInfo:nil repeats:YES] retain];
}

- (void)viewWillDisappear:(BOOL)animated {
	[super viewWillDisappear:animated];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:LTPlaybackStateDidChangeNotification object:nil];
	[_updateTimer invalidate];
	[_updateTimer release];
	_updateTimer = nil;
}

- (void)playbackStateChanged:(NSNotification *)notification {
	[self refreshForCurrentSong];
	[self refreshTransportState];
}

- (void)refreshForCurrentSong {
	LTSong *song = [[LTPlaybackController sharedController] currentSong];

	if (song == nil) {
		_titleLabel.text = @"Nothing Playing";
		_artistLabel.text = @"";
		_artworkView.image = nil;
		_placeholderLabel.hidden = NO;
		_placeholderLabel.text = @"—";
		_scrubber.maximumValue = 1;
		_scrubber.value = 0;
		_elapsedLabel.text = @"0:00";
		_remainingLabel.text = @"0:00";
		return;
	}

	_titleLabel.text = song.title;
	_artistLabel.text = song.artist;
	_scrubber.maximumValue = (song.duration > 0) ? song.duration : 1;

	UIImage *artwork = song.artworkPath ? [UIImage imageWithContentsOfFile:song.artworkPath] : nil;
	if (artwork != nil) {
		_artworkView.image = artwork;
		_placeholderLabel.hidden = YES;
	} else {
		_artworkView.image = nil;
		_placeholderLabel.text = ([song.title length] > 0) ? [[song.title substringToIndex:1] uppercaseString] : @"?";
		_placeholderLabel.hidden = NO;
	}

	[self tickScrubber];
}

- (void)refreshTransportState {
	LTPlaybackController *playback = [LTPlaybackController sharedController];

	[_playPauseButton setTitle:(playback.isPlaying ? @"⏸" : @"▶") forState:UIControlStateNormal];

	_shuffleButton.alpha = playback.shuffleEnabled ? 1.0f : 0.4f;

	NSString *repeatTitle = @"⟲";
	CGFloat repeatAlpha = 0.4f;
	if (playback.repeatMode == LTRepeatModeAll) {
		repeatAlpha = 1.0f;
	} else if (playback.repeatMode == LTRepeatModeOne) {
		repeatTitle = @"⟲1";
		repeatAlpha = 1.0f;
	}
	[_repeatButton setTitle:repeatTitle forState:UIControlStateNormal];
	_repeatButton.alpha = repeatAlpha;
}

- (void)tickScrubber {
	if (_isScrubbing) return;

	LTPlaybackController *playback = [LTPlaybackController sharedController];
	LTSong *song = [playback currentSong];
	if (song == nil) return;

	NSTimeInterval elapsed = playback.currentPlaybackTime;
	_scrubber.value = elapsed;
	_elapsedLabel.text = LTFormattedTime(elapsed);
	_remainingLabel.text = [NSString stringWithFormat:@"-%@", LTFormattedTime(song.duration - elapsed)];
}

#pragma mark - Actions

- (void)closeTapped {
	// Same deprecated-at-iOS-6.0 situation as presentModalViewController:
	// in LTRootContainerController.m — see that comment for the full
	// explanation.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
	[self dismissModalViewControllerAnimated:YES];
#pragma clang diagnostic pop
}

- (void)shuffleTapped {
	LTPlaybackController *playback = [LTPlaybackController sharedController];
	playback.shuffleEnabled = !playback.shuffleEnabled;
	[self refreshTransportState];
}

- (void)previousTapped {
	[[LTPlaybackController sharedController] skipToPrevious];
}

- (void)playPauseTapped {
	[[LTPlaybackController sharedController] togglePlayPause];
}

- (void)nextTapped {
	[[LTPlaybackController sharedController] skipToNext];
}

- (void)repeatTapped {
	[[LTPlaybackController sharedController] cycleRepeatMode];
	[self refreshTransportState];
}

- (void)scrubberBeganDragging {
	_isScrubbing = YES;
}

- (void)scrubberValueChanged {
	_elapsedLabel.text = LTFormattedTime(_scrubber.value);
	LTSong *song = [[LTPlaybackController sharedController] currentSong];
	if (song != nil) {
		_remainingLabel.text = [NSString stringWithFormat:@"-%@", LTFormattedTime(song.duration - _scrubber.value)];
	}
}

- (void)scrubberEndedDragging {
	[[LTPlaybackController sharedController] seekToTime:_scrubber.value];
	_isScrubbing = NO;
}

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[_updateTimer invalidate];
	[_updateTimer release];
	[_artworkView release];
	[_placeholderLabel release];
	[_titleLabel release];
	[_artistLabel release];
	[_scrubber release];
	[_elapsedLabel release];
	[_remainingLabel release];
	[_shuffleButton release];
	[_previousButton release];
	[_playPauseButton release];
	[_nextButton release];
	[_repeatButton release];
	[super dealloc];
}

@end
