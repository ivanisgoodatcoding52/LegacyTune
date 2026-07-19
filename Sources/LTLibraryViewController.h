#import <UIKit/UIKit.h>

// Library browser: Artists / Albums / Songs / Genres, backed by LTDatabase.
//
// PERFORMANCE NOTES (why this looks the way it does):
// - Per-mode results are cached in memory and only re-fetched when the
//   scanner reports new data (LTLibraryScannerDidFinishNotification), NOT
//   on every -viewWillAppear. Switching tabs used to re-run a full query
//   and rebuild every model object from scratch each time, even when
//   nothing had changed.
// - "Songs" mode — potentially thousands of rows for a real library — is
//   paginated (LIMIT/OFFSET, loaded incrementally as the user scrolls)
//   rather than loading and allocating an LTSong for every track in the
//   library up front. Artists/Albums/Genres are DISTINCT-grouped queries
//   that stay small even for large libraries, so those load in full.
@interface LTLibraryViewController : UIViewController <UITableViewDataSource, UITableViewDelegate> {
	UISegmentedControl *_modeControl;
	UITableView *_tableView;

	NSMutableDictionary *_groupedTitlesCache; // mode number -> NSArray of strings, for Artists/Albums/Genres
	NSMutableArray *_songsPage;               // currently loaded page of LTSong, for Songs mode only
	BOOL _hasMoreSongs;
	BOOL _isLoadingMoreSongs;
}

@end
