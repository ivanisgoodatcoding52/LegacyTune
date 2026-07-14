#import <UIKit/UIKit.h>

@interface LTPlaylistsViewController : UIViewController <UITableViewDataSource, UITableViewDelegate> {
	UITableView *_tableView;
	NSArray *_playlists;
}

@end
