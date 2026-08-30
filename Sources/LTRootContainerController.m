#import "LTRootContainerController.h"
#import "LTHomeViewController.h"
#import "LTSearchViewController.h"
#import "LTLibraryViewController.h"
#import "LTPlaylistsViewController.h"
#import "LTSettingsViewController.h"
#import "LTPlayerViewController.h"
#import "LTPlaybackController.h"
#import "LTSong.h"

#define kMiniPlayerHeight 44.0f

@interface LTRootContainerController ()
- (void)miniPlayerTapped;
- (void)miniPlayPauseTapped;
- (void)refreshMiniPlayer;
- (void)playbackStateChanged:(NSNotification *)notification;
@end

@implementation LTRootContainerController

- (void)loadView {
	self.view = [[[UIView alloc] initWithFrame:[[UIScreen mainScreen] applicationFrame]] autorelease];
	self.view.backgroundColor = [UIColor blackColor];
	self.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
}

- (void)viewDidLoad {
	[super viewDidLoad];

	LTHomeViewController *home = [[[LTHomeViewController alloc] init] autorelease];
	home.tabBarItem = [[[UITabBarItem alloc] initWithTitle:@"Home" image:nil tag:0] autorelease];

	LTSearchViewController *search = [[[LTSearchViewController alloc] init] autorelease];
	search.tabBarItem = [[[UITabBarItem alloc] initWithTitle:@"Search" image:nil tag:1] autorelease];

	LTLibraryViewController *library = [[[LTLibraryViewController alloc] init] autorelease];
	library.tabBarItem = [[[UITabBarItem alloc] initWithTitle:@"Library" image:nil tag:2] autorelease];

	LTPlaylistsViewController *playlists = [[[LTPlaylistsViewController alloc] init] autorelease];
	playlists.tabBarItem = [[[UITabBarItem alloc] initWithTitle:@"Playlists" image:nil tag:3] autorelease];

	LTSettingsViewController *settings = [[[LTSettingsViewController alloc] init] autorelease];
	settings.tabBarItem = [[[UITabBarItem alloc] initWithTitle:@"Settings" image:nil tag:4] autorelease];

	_tabBarController = [[UITabBarController alloc] init];
	_tabBarController.viewControllers = [NSArray arrayWithObjects:
		[[[UINavigationController alloc] initWithRootViewController:home] autorelease],
		[[[UINavigationController alloc] initWithRootViewController:search] autorelease],
		[[[UINavigationController alloc] initWithRootViewController:library] autorelease],
		[[[UINavigationController alloc] initWithRootViewController:playlists] autorelease],
		[[[UINavigationController alloc] initWithRootViewController:settings] autorelease],
		nil];

	_tabBarController.view.frame = self.view.bounds;
	_tabBarController.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	[self.view addSubview:_tabBarController.view];

	CGFloat tabBarHeight = _tabBarController.tabBar.frame.size.height;
	CGRect miniFrame = CGRectMake(0, self.view.bounds.size.height - tabBarHeight - kMiniPlayerHeight, self.view.bounds.size.width, kMiniPlayerHeight);

	// FIX: was a plain UIView with a UITapGestureRecognizer added to it.
	// UIGestureRecognizer (all subclasses, including UITapGestureRecognizer)
	// was introduced in iOS 3.2, alongside the original iPad — it silently
	// does nothing on iPhone 2G/3G or iPod touch 1st/2nd gen running iOS
	// 3.0 or 3.1.x, which are within this tier's stated floor. UIControl's
	// target-action (used here via addTarget:action:forControlEvents:) has
	// worked since iOS 2.0, so the container itself is now a UIControl.
	// The play/pause UIButton nested inside it still gets its own taps
	// correctly — UIKit's hit-testing routes a touch to the deepest
	// subview that wants it, so tapping the button doesn't also fire the
	// container's action.
	_miniPlayerView = [[UIControl alloc] initWithFrame:miniFrame];
	_miniPlayerView.backgroundColor = [UIColor colorWithWhite:0.12f alpha:1.0f];
	_miniPlayerView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;

	UILabel *nowPlayingLabel = [[UILabel alloc] initWithFrame:CGRectMake(12, 0, miniFrame.size.width - 60, kMiniPlayerHeight)];
	nowPlayingLabel.text = @"Not Playing";
	nowPlayingLabel.textColor = [UIColor whiteColor];
	nowPlayingLabel.backgroundColor = [UIColor clearColor];
	nowPlayingLabel.font = [UIFont boldSystemFontOfSize:13];
	nowPlayingLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	[_miniPlayerView addSubview:nowPlayingLabel];
	_nowPlayingLabel = nowPlayingLabel; // alloc/init'd (owned, +1) — kept directly, released in -dealloc

	UIButton *playPauseButton = [UIButton buttonWithType:UIButtonTypeCustom];
	playPauseButton.frame = CGRectMake(miniFrame.size.width - 48, 4, 36, 36);
	[playPauseButton setTitle:@"▶" forState:UIControlStateNormal];
	[playPauseButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
	[playPauseButton addTarget:self action:@selector(miniPlayPauseTapped) forControlEvents:UIControlEventTouchUpInside];
	[_miniPlayerView addSubview:playPauseButton];
	_miniPlayPauseButton = [playPauseButton retain]; // buttonWithType: is autoreleased, unlike the alloc/init'd label above — needs its own explicit retain for the ivar to own a reference independent of the view hierarchy's

	[(UIControl *)_miniPlayerView addTarget:self action:@selector(miniPlayerTapped) forControlEvents:UIControlEventTouchUpInside];

	[self.view addSubview:_miniPlayerView];

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playbackStateChanged:)
		name:LTPlaybackStateDidChangeNotification object:nil];
	[self refreshMiniPlayer];
}

- (void)refreshMiniPlayer {
	LTPlaybackController *playback = [LTPlaybackController sharedController];
	LTSong *song = [playback currentSong];

	if (song == nil) {
		_nowPlayingLabel.text = @"Not Playing";
	} else {
		_nowPlayingLabel.text = [NSString stringWithFormat:@"%@ — %@", song.title, song.artist];
	}
	[_miniPlayPauseButton setTitle:(playback.isPlaying ? @"⏸" : @"▶") forState:UIControlStateNormal];
}

- (void)playbackStateChanged:(NSNotification *)notification {
	[self refreshMiniPlayer];
}

- (void)miniPlayPauseTapped {
	[[LTPlaybackController sharedController] togglePlayPause];
}

- (void)miniPlayerTapped {
	LTPlayerViewController *player = [[LTPlayerViewController alloc] init];
	player.modalTransitionStyle = UIModalTransitionStyleCoverVertical;
	// presentModalViewController:animated: is deprecated starting iOS
	// 6.0 (in favor of presentViewController:animated:completion:, which
	// is itself iOS 5.0+ only). Since Sources/ is shared between Tier A
	// (iOS 3.0 floor — needs the old API) and Tier B (iOS 6.0 floor,
	// compiling against the SDK version where this exact call becomes
	// deprecated), and this toolchain has already shown it treats
	// deprecation warnings as hard errors (see the NSFileManager fix
	// earlier in this project), this needs an explicit, scoped silence
	// rather than risk breaking the Tier B build.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
	[self presentModalViewController:player animated:YES];
#pragma clang diagnostic pop
	[player release];
}

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[_tabBarController release];
	[_miniPlayerView release];
	[_nowPlayingLabel release];
	[_miniPlayPauseButton release];
	[super dealloc];
}

@end
