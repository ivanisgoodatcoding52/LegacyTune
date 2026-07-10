#import <UIKit/UIKit.h>

// LTRootContainerController owns the 5-tab UITabBarController (Home, Search,
// Library, Playlists, Settings) plus a persistent mini-player bar docked
// just above the tab bar, Spotify-style.
//
// NOTE ON SCOPE: the original product spec listed "Player" as its own 6th
// tab. A native UITabBar only shows 5 items before iOS folds the rest into
// an auto-generated "More" tab, which would bury the now-playing screen —
// bad UX for something meant to be persistently visible. This scaffold
// intentionally deviates from that part of the spec: 5 real tabs, plus a
// mini player that expands into a full-screen LTPlayerViewController when
// tapped.
@interface LTRootContainerController : UIViewController {
	UITabBarController *_tabBarController;
	UIView *_miniPlayerView;
}

@end
