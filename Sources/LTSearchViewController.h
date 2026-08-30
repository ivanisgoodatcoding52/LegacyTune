#import <UIKit/UIKit.h>

@interface LTSearchViewController : UIViewController <UISearchBarDelegate, UITableViewDataSource, UITableViewDelegate> {
	UISearchBar *_searchBar;
	UITableView *_tableView;
	UILabel *_emptyStateLabel;
	NSArray *_results;
	NSTimer *_debounceTimer;
	NSUInteger _searchGeneration;
}

@end
