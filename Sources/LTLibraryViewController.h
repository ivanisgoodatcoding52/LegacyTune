#import <UIKit/UIKit.h>

// Real Library browser: Artists / Albums / Songs / Genres, backed by
// LTDatabase. Drilling into an Artist/Album/Genre pushes an
// LTSongListViewController filtered to that value.
@interface LTLibraryViewController : UIViewController <UITableViewDataSource, UITableViewDelegate> {
	UISegmentedControl *_modeControl;
	UITableView *_tableView;
	NSArray *_groupedTitles;   // artist / album / genre names, depending on mode
	NSArray *_songs;           // used only when mode == Songs
}

@end
