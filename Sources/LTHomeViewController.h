#import <UIKit/UIKit.h>

// Home tab: greeting header + exactly 2 sections (Favorites, Recently
// Added), each a horizontal card strip. Whole-section drag-to-reorder via
// standard UITableView edit-mode row moving (same mechanism already used
// for playlist song reordering — no hand-rolled touch tracking needed).
// Favorites content itself is managed on a separate pushed screen
// (LTFavoritesManagerViewController), not inline here.
@interface LTHomeViewController : UIViewController <UITableViewDataSource, UITableViewDelegate> {
	UITableView *_tableView;
	NSMutableArray *_sections; // LTHomeSection*
}

@end
