#import <UIKit/UIKit.h>

@interface LTLibraryViewController : UIViewController <UITableViewDataSource, UITableViewDelegate> {
	UISegmentedControl *_modeControl;
	UITableView *_tableView;
	NSMutableDictionary *_groupedTitlesCache;
	NSMutableArray *_songsPage;
	BOOL _hasMoreSongs;
	BOOL _isLoadingMoreSongs;

	// Album grid view — a second way to browse Albums (artwork tiles,
	// name + artist below, Spotify-style), toggled via a nav bar button
	// that only appears while Albums mode is selected. Not a separate
	// tab/mode of its own — it's an alternate presentation of the same
	// Albums data as the plain list.
	BOOL _albumsGridEnabled;
	NSArray *_albumSummaries; // LTAlbumSummary*, cached like the other grouped-title arrays
	UIBarButtonItem *_gridToggleButton;
}

@end
