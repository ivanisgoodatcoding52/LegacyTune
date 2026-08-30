#import <UIKit/UIKit.h>

@class LTPlaylist;

@interface LTPlaylistDetailViewController : UIViewController <UITableViewDataSource, UITableViewDelegate> {
	LTPlaylist *_playlist;
	UITableView *_tableView;
	NSArray *_songs;
}

- (id)initWithPlaylist:(LTPlaylist *)playlist;

@end
