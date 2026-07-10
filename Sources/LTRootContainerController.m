#import "LTRootContainerController.h"
#import "LTHomeViewController.h"
#import "LTSearchViewController.h"
#import "LTLibraryViewController.h"
#import "LTPlaylistsViewController.h"
#import "LTSettingsViewController.h"
#import "LTPlayerViewController.h"

#define kMiniPlayerHeight 44.0f

@interface LTRootContainerController ()
- (void)miniPlayerTapped;
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

	// NOTE: formal view controller containment (-addChildViewController:)
	// is iOS 5.0+ only. Pre-iOS5, embedding another controller's view as a
	// plain subview like this was the standard pattern — it still works
	// fine on iOS 5+ too, it's just not "best practice" there.
	_tabBarController.view.frame = self.view.bounds;
	_tabBarController.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	[self.view addSubview:_tabBarController.view];

	CGFloat tabBarHeight = _tabBarController.tabBar.frame.size.height;
	CGRect miniFrame = CGRectMake(0,
		self.view.bounds.size.height - tabBarHeight - kMiniPlayerHeight,
		self.view.bounds.size.width,
		kMiniPlayerHeight);

	_miniPlayerView = [[UIView alloc] initWithFrame:miniFrame];
	_miniPlayerView.backgroundColor = [UIColor colorWithWhite:0.12f alpha:1.0f];
	_miniPlayerView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;

	UILabel *nowPlayingLabel = [[UILabel alloc] initWithFrame:CGRectMake(12, 0, miniFrame.size.width - 60, kMiniPlayerHeight)];
	nowPlayingLabel.text = @"Not Playing";
	nowPlayingLabel.textColor = [UIColor whiteColor];
	nowPlayingLabel.backgroundColor = [UIColor clearColor];
	nowPlayingLabel.font = [UIFont boldSystemFontOfSize:13];
	[_miniPlayerView addSubview:nowPlayingLabel];
	[nowPlayingLabel release];

	UIButton *playPauseButton = [UIButton buttonWithType:UIButtonTypeCustom];
	playPauseButton.frame = CGRectMake(miniFrame.size.width - 48, 4, 36, 36);
	[playPauseButton setTitle:@"▶" forState:UIControlStateNormal];
	[playPauseButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
	[_miniPlayerView addSubview:playPauseButton];

	UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(miniPlayerTapped)];
	[_miniPlayerView addGestureRecognizer:tap];
	[tap release];

	[self.view addSubview:_miniPlayerView];
}

- (void)miniPlayerTapped {
	LTPlayerViewController *player = [[LTPlayerViewController alloc] init];
	player.modalTransitionStyle = UIModalTransitionStyleCoverVertical;
	[self presentModalViewController:player animated:YES]; // pre-iOS5 API; -presentViewController:animated:completion: is iOS5+
	[player release];
}

- (void)dealloc {
	[_tabBarController release];
	[_miniPlayerView release];
	[super dealloc];
}

@end
