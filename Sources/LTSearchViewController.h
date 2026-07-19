#import <UIKit/UIKit.h>

// Instant local search over song title/artist/album/genre.
//
// PERFORMANCE: queries run on a background thread (its own LTDatabase
// connection, same pattern as LTLibraryScanner) with a short debounce
// timer, so fast typing never fires a query per keystroke and never
// blocks the main thread even for a slow query. A "generation" counter
// discards results from a stale (superseded) search if the user kept
// typing before an older query finished.
@interface LTSearchViewController : UIViewController <UISearchBarDelegate, UITableViewDataSource, UITableViewDelegate> {
	UISearchBar *_searchBar;
	UITableView *_tableView;
	UILabel *_emptyStateLabel;

	NSArray *_results;          // LTSong*
	NSTimer *_debounceTimer;
	NSUInteger _searchGeneration;
}

@end
